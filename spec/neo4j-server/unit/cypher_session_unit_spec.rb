require 'spec_helper'

module Neo4j::Server
  describe CypherSession do
    
    let(:connection) do
      double('connection')
    end

    let(:cypher_response) do
      double('cypher response', error?: false, first_data: [28])
    end

    let(:session) do
      allow_any_instance_of(CypherSession).to receive(:initialize_resource).and_return(nil)
      CypherSession.new('http://foo.bar', connection)
    end

    class TestResponse
      attr_reader :body
      def initialize(body)
        @body = body
      end

      def status
        200
      end

      def request_uri
        ""
      end
      def request
        return Struct.new(:path).new('bla')
      end
    end

    describe 'create_session' do
      let(:root_resource_with_slash) do
        {
            "management"=>"http://localhost:7474/db/manage/",
            "data"=>"http://localhost:7474/db/data/"
        }
      end

      let(:root_resource_with_no_slash) do
        {
            "management"=>"http://localhost:7474/db/manage",
            "data"=>"http://localhost:7474/db/data"
        }
      end

      let(:data_resource) do
        {}
      end

      describe 'without auth params' do

        before do
          expect(CypherSession).to receive(:create_connection).and_return(connection)
          expect(connection).to receive(:get).with('http://localhost:7474').and_return(TestResponse.new(root_resource_with_slash))
          expect(connection).to receive(:get).with("http://localhost:7474/db/data/").and_return(TestResponse.new(data_resource))
        end

        it 'allow root resource with urls ending with slash' do
          session = Neo4j::Session.create_session(:server_db)
          expect(session.resource_url).to eq('http://localhost:7474/db/data/')
        end

        it 'allow root resource with urls NOT ending with slash' do
          session = Neo4j::Session.create_session(:server_db)
          expect(session.resource_url).to eq('http://localhost:7474/db/data/')
        end

        describe 'on_session_available' do
          after do
            Neo4j::Session._listeners.clear
          end

          it 'calls the callback directly if session already exists' do
            session = Neo4j::Session.create_session(:server_db)
            expect { |b| Neo4j::Session.on_session_available(&b) }.to yield_with_args(Neo4j::Session)
          end

          it 'calls the callback when session is available' do
            called_with = nil
            Neo4j::Session.on_session_available {|session| called_with = session}
            session = Neo4j::Session.create_session(:server_db)
            expect(called_with).to eq(session)
          end

        end

        describe 'add_listener' do
          after do
            Neo4j::Session._listeners.clear
          end

          it 'notify listener when session is created' do
            data, event = nil
            Neo4j::Session.add_listener do |e, d|
              event = e
              data = d
            end

            session = Neo4j::Session.create_session(:server_db)
            expect(event).to eq(:session_available)
            expect(data).to eq(session)
          end
        end
      end

      describe 'with auth params' do
        let(:auth) { {basic_auth: { username: 'username', password: 'password'}} }

        it 'creates session with basic auth params' do
          base_url = 'http://localhost:7474'
          params = [base_url, auth]
          session = Neo4j::Session.create_session(:server_db, params)
          handlers = session.connection.builder.handlers.map(&:name)
          expect(handlers).to include('Faraday::Request::BasicAuthentication')

        end

      end


      it 'does work with two sessions' do
        base_url = 'http://localhost:7474'
        auth = {basic_auth: { username: 'username', password: 'password'}}
        params = [base_url, auth]

        expect(Neo4j::Server::CypherSession).to receive(:create_connection).with(auth).and_return(connection)
        expect(connection).to receive(:get).with(base_url)
          .and_return(TestResponse.new(root_resource_with_slash))
        expect(connection).to receive(:get).with("http://localhost:7474/db/data/")
          .and_return(TestResponse.new(data_resource))

        Neo4j::Session.create_session(:server_db, params)

        expect(Neo4j::Server::CypherSession).to receive(:create_connection).with({}).and_return(connection)
        expect(connection).to receive(:get).with('http://localhost:7474')
          .and_return(TestResponse.new(root_resource_with_no_slash))
        expect(connection).to receive(:get).with("http://localhost:7474/db/data/")
          .and_return(TestResponse.new(data_resource))

        # handlers = @faraday.builder.handlers.map(&:name)
        # expect(handlers).to include('Faraday::Request::BasicAuthentication')

        Neo4j::Session.create_session(:server_db)
      end

    end

    describe 'instance methods' do

      describe 'load_node' do
        it "generates 'START v0 = node(1915); RETURN v0'" do
          expect(cypher_response).to receive(:entity_data)
          expect(session).to receive(:_query).with("START n=node(1915) RETURN n").and_return(cypher_response)
          session.load_node(1915)
        end

        it "returns nil if EntityNotFoundException" do
          r = double('cypher response', error?: true, error_status: 'EntityNotFoundException')
          expect(session).to receive(:_query).with("START n=node(1915) RETURN n").and_return(r)
          expect(session.load_node(1915)).to be_nil
        end

        it "raise an exception if there is an error but not an EntityNotFoundException exception" do
          r = double('cypher response', error?: true, error_status: 'SomeError', response: double("response").as_null_object)
          expect(r).to receive(:raise_error)
          expect(session).to receive(:_query).with("START n=node(1915) RETURN n").and_return(r)
          session.load_node(1915)
        end
      end

      describe 'begin_tx' do
        let(:dummy_request) { double("dummy request", path: 'http://dummy.request')}

        after { Thread.current[:neo4j_curr_tx] = nil }

        let(:body) do
          <<-HERE
{"commit":"http://localhost:7474/db/data/transaction/1/commit","results":[],"transaction":{"expires":"Tue, 06 Aug 2013 21:35:20 +0000"},"errors":[]}
          HERE
        end

        it "create a new transaction and stores it in thread local" do
          response = double('response2', headers: {'Location' => 'http://tx/42'}, status: 201, body: {'commit' => 'http://tx/42/commit'})
          expect(session).to receive(:resource_url).with('transaction', nil).and_return('http://new.tx')
          expect(connection).to receive(:post).with('http://new.tx', anything).and_return(response)
          
          tx = session.begin_tx
          expect(tx.commit_url).to eq('http://tx/42/commit')
          expect(tx.exec_url).to eq('http://tx/42')
          expect(Thread.current[:neo4j_curr_tx]).to eq(tx)
        end
      end

      describe 'create_node' do

        before do
          allow(session).to receive(:resource_url).and_return("http://resource_url")
        end

        it "create_node() generates 'CREATE (v1) RETURN v1'" do
          allow(session).to receive(:resource_url)
          expect(session).to receive(:_query).with("CREATE (n ) RETURN ID(n)", nil).and_return(cypher_response)
          session.create_node
        end

        it 'create_node(name: "jimmy") generates ' do
          expect(session).to receive(:_query).with("CREATE (n {name : 'jimmy'}) RETURN ID(n)",nil).and_return(cypher_response)
          session.create_node(name: 'jimmy')
        end

        it 'create_node({}, [:person])' do
          expect(session).to receive(:_query).with("CREATE (n:`person` {}) RETURN ID(n)",nil).and_return(cypher_response)
          session.create_node({}, [:person])
        end

        it "initialize a CypherNode instance" do
          expect(session).to receive(:_query).with("CREATE (n ) RETURN ID(n)",nil).and_return(cypher_response)
          n = double("cypher node")
          expect(CypherNode).to receive(:new).and_return(n)
          session.create_node
        end
      end

      describe 'find_nodes' do
        
        before do
          # session.stub(:resource_url).and_return
          # session.should_receive(:search_result_to_enumerable).with(cypher_response).and_return
        end

        it "should produce Cypher query with String values" do
          skip "TODO"  # TODO
          cypher_query = "        MATCH (n:`label`)\n        WHERE n.key = 'value'\n        RETURN ID(n)\n"
          expect(session).to receive(:_query_or_fail).with(cypher_query).and_return(cypher_response)
          session.find_nodes(:label,:key,"value")
        end

        it "should produce Cypher query with Fixnum values" do
          skip "TODO" # TODO
          cypher_query = "        MATCH (n:`label`)\n        WHERE n.key = 4\n        RETURN ID(n)\n"
          expect(session).to receive(:_query_or_fail).with(cypher_query).and_return(cypher_response)
          session.find_nodes(:label,:key,4)
        end

        it "should produce Cypher query with Float values" do
          skip "TODO" # TODO
          cypher_query = "        MATCH (n:`label`)\n        WHERE n.key = 4.5\n        RETURN ID(n)\n"
          expect(session).to receive(:_query_or_fail).with(cypher_query).and_return(cypher_response)
          session.find_nodes(:label,:key,4.5)
        end
      end

    end
  end
  
end
