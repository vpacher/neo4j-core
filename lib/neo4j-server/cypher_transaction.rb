module Neo4j::Server
  class CypherTransaction
    include Neo4j::Transaction::Instance
    include Neo4j::Core::CypherTranslator
    include Resource

    attr_reader :commit_url, :exec_url

    class CypherError < StandardError
      attr_reader :code, :status
      def initialize(code, status, message)
        super(message)
        @code = code
        @status = status
      end
    end

    def initialize(db, response, url, endpoint)
      @endpoint = endpoint
      @commit_url = response.body['commit']
      @exec_url = response.headers['Location']
      raise "NO ENDPOINT URL #{@endpoint} : HEAD: #{response.headers.inspect}" if !@exec_url || @exec_url.empty?
      init_resource_data(response.body, url)
      expect_response_code(response,201)
      register_instance
    end

    def _query(cypher_query, params=nil)
      statement = {statement: cypher_query}
      body = {statements: [statement]}

      if params
        # TODO can't get this working for some reason using parameters
        #props = params.keys.inject({}) do|ack, k|
        #  ack[k] = {name: params[k]}
        #  ack
        #end
        #statement[:parameters] = props

        # So we have to do this workaround
        params.each_pair do |k,v|
          statement[:statement].gsub!("{ #{k} }", "#{escape_value(v)}")
        end
      end
      response = @endpoint.post(@exec_url, body)
      _create_cypher_response(response)
    end

    def _create_cypher_response(response)
      first_result = response.body['results'][0]
      cr = CypherResponse.new(response, true)

      if (response.body['errors'].empty?)
        cr.set_data(first_result['data'], first_result['columns'])
      else
        first_error = response.body['errors'].first
        cr.set_error(first_error['message'], first_error['code'], first_error['code'])
      end
      cr
    end



    def _delete_tx
      response = @endpoint.delete(@exec_url, headers: resource_headers)
      expect_response_code(response,200)
      response
    end

    def _commit_tx
      puts "COMMIT TX  #{@commit_url}"
      response = @endpoint.post(@commit_url)

      expect_response_code(response,200)
      response
    end
  end
end
