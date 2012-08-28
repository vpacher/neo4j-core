module Neo4j
  module Core
    module Cypher
      class Start
        class EvalContext
          include Variable
          include Matchable

          attr_reader :clause
          def initialize(clause)
            @clause = clause
          end
        end

        include Clause

        attr_accessor :eval_context, :entities

        def initialize(clause_list)
          initialize_clause(clause_list, :start)
          @var_name = clause_list.create_variable(self)
          @eval_context = EvalContext.new(self)
        end

        def initialize_entities(entities)
          @entities = entities.map { |n| n.respond_to?(:neo_id) ? n.neo_id : n }
        end

        def returnable?
          true
        end

      end

      # Can be created from a <tt>node</tt> dsl method.
      class StartNode < Start
        def initialize(clause_list, nodes)
          super(clause_list)
          initialize_entities(nodes)
        end

        def to_cypher
          "#{var_name}=node(#{entities.join(',')})"
        end

      end


      # Can be created from a <tt>rel</tt> dsl method.
      class StartRel < Start
        def initialize(clause_list, rels)
          super(clause_list)
          initialize_entities(rels)
        end

        def to_cypher
          "#{var_name}=relationship(#{entities.join(',')})"
        end
      end

      class NodeQuery < Start
        attr_reader :index_name, :query

        def initialize(clause_list, index_class, query, index_type)
          super(clause_list)
          @index_name = index_class.index_name_for_type(index_type)
          @query = query
        end

        def to_cypher
          "#{var_name}=node:#{index_name}(#{query})"
        end
      end

      class NodeLookup < Start
        attr_reader :index_name, :query

        def initialize(clause_list, index_class, key, value)
          super(clause_list)
          index_type = index_class.index_type(key.to_s)
          raise "No index on #{index_class} property #{key}" unless index_type
          @index_name = index_class.index_name_for_type(index_type)
          @query = %Q[#{key}="#{value}"]
        end

        def to_cypher
          %Q[#{var_name}=node:#{index_name}(#{query})]
        end

      end

    end
  end
end