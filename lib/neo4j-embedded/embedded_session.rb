# Plugin

Neo4j::Session.register_db(:embedded_db) do |*args|
  Neo4j::Embedded::EmbeddedSession.new(*args)
end


module Neo4j::Embedded
  class EmbeddedSession < Neo4j::Session

    class Error < StandardError
    end

    attr_reader :graph_db, :db_location, :properties_file
    extend Forwardable
    extend Neo4j::Core::TxMethods
    def_delegator :@graph_db, :begin_tx


    def initialize(db_location, config={})
      @db_location     = db_location
      @auto_commit     = !!config[:auto_commit]
      @properties_file = config[:properties_file]
      Neo4j::Session.register(self)
    end

    def db_type
      :embedded_db
    end

    def inspect
      "#{self.class} db_location: '#{@db_location}', running: #{running?}"
    end

    def start
      raise Error.new("Embedded Neo4j db is already running") if running?
      puts "Start embedded Neo4j db at #{db_location}"
      factory    = Java::OrgNeo4jGraphdbFactory::GraphDatabaseFactory.new
      db_service = factory.newEmbeddedDatabaseBuilder(db_location)
      db_service.loadPropertiesFromFile(properties_file) if properties_file
      @graph_db = db_service.newGraphDatabase()
      Neo4j::Session._notify_listeners(:session_available, self)
      @engine = Java::OrgNeo4jCypherJavacompat::ExecutionEngine.new(@graph_db)
    end

    def factory_class
      Java::OrgNeo4jGraphdbFactory::GraphDatabaseFactory
      Java::OrgNeo4jTest::ImpermanentGraphDatabase
    end

    def begin_tx
      if Neo4j::Transaction.current
        # Handle nested transaction "placebo transaction"
        Neo4j::Transaction.current.push_nested!
      else
        Neo4j::Embedded::EmbeddedTransaction.new(@graph_db.begin_tx)
      end
      Neo4j::Transaction.current
    end

    def close
      super
      shutdown
    end

    def shutdown
      graph_db && graph_db.shutdown
      @graph_db = nil
    end

    def running?
      !!graph_db
    end

    def create_label(name)
      EmbeddedLabel.new(self, name)
    end

    def load_node(neo_id)
      _load_node(neo_id)
    end
    tx_methods :load_node

    # Same as load but does not return the node as a wrapped Ruby object.
    #
    def _load_node(neo_id)
      return nil if neo_id.nil?
      @graph_db.get_node_by_id(neo_id.to_i)
    rescue Java::OrgNeo4jGraphdb.NotFoundException
      nil
    end

    def load_relationship(neo_id)
      _load_relationship(neo_id)
    end
    tx_methods :load_relationship

    def _load_relationship(neo_id)
      return nil if neo_id.nil?
      @graph_db.get_relationship_by_id(neo_id.to_i)
    rescue Java::OrgNeo4jGraphdb.NotFoundException
      nil
    end

    def query(*args)
      if [[String], [String, String]].include?(args.map(&:class))
        query, params = args[0,2]
        Neo4j::Embedded::ResultWrapper.new(_query(query, params), query)
      else
        options = args[0] || {}
        Neo4j::Core::Query.new(options.merge(session: self))
      end
    end


    def find_all_nodes(label)
      EmbeddedLabel.new(self, label).find_nodes
    end

    def find_nodes(label, key, value)
      EmbeddedLabel.new(self, label).find_nodes(key,value)
    end

    # Performs a cypher query with given string.
    # Remember that you should close the resource iterator.
    # @param [String] q the cypher query as a String
    # @return (see #query)
    def _query(q, params={})
      @engine ||= Java::OrgNeo4jCypherJavacompat::ExecutionEngine.new(@graph_db)
      @engine.execute(q, Neo4j::Core::HashWithIndifferentAccess.new(params))
    rescue Exception => e
      raise Neo4j::Session::CypherError.new(e.message, e.class, 'cypher error')
    end

    def query_default_return(as)
      " RETURN #{as}"
    end

    def _query_or_fail(q)
      @engine ||= Java::OrgNeo4jCypherJavacompat::ExecutionEngine.new(@graph_db)
      @engine.execute(q)
    end

    def search_result_to_enumerable(result)
      result.map {|column| column['n'].wrapper}
    end

    def create_node(properties = nil, labels=[])
      if labels.empty?
        _java_node = graph_db.create_node
      else
        labels = EmbeddedLabel.as_java(labels)
        _java_node = graph_db.create_node(labels)
      end
      properties.each_pair { |k, v| _java_node[k]=v } if properties
      _java_node
    end
    tx_methods :create_node

  end



end
