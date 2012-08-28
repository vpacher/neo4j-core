module Neo4j
  module Core
    module Cypher

      # Represents an unbound node variable used in match statements
      class NodeVar
        include Referenceable
        # @return the name of the variable
        attr_accessor :var_name
        attr_reader :clause_list
        attr_reader :eval_context

        def initialize(clause_list)
          @var_name = clause_list.create_variable(self)
          @clause_list = clause_list
          @returnable = true
          @eval_context = EvalContext.new(self)
        end

        # @return [String] a cypher string for this node variable
        def to_s
          var_name
        end

        def new(props = nil)
          @creator = Create.new(@clause_list, self, props)
          @returnable = true
          self
        end

        def returnable?
          @returnable
        end

        # @private
        def expr
          if @creator
            @creator.to_s
          else
            to_s
          end
        end

        class EvalContext
          include Variable
          include Matchable
          attr_reader :clause

          def initialize(clause)
            @clause = clause
          end
        end
      end

      class RelVar
        include ToPropString
        include Referenceable

        attr_reader :eval_context, :clause_list
        attr_accessor :var_name, :expr

        def initialize(clause_list, expr, props = nil)
          @expr = expr
          @clause_list = clause_list
          guess = expr ? /([[:alpha:]_]*)/.match(expr)[1] : ""
          @var_name = guess.empty? ? clause_list.create_variable(self) : guess
          @expr = "#@expr #{to_prop_string(props)}" if props
          @eval_context = EvalContext.new(self)
        end

        def returnable?
          true
        end

        def rel_type
          Property.new(clause_list, self, 'type').to_function!
        end

        def create_name_if_needed
          if @expr.to_s[0..0] == ':'
            raise "NEW EXPR #{@expr} now #{@var_name}#{@expr}"
            @expr = "#{@var_name}#{@expr}"
          end
        end

        # TODO is this needed ?
        #def optionally!
        #  if @expr.include?(':')
        #    @expr.sub!(/[^:\?]*/, "#{@var_name}?")
        #  else
        #    @expr = "#{@var_name}?:#@expr"
        #  end
        #  self
        #end

        class EvalContext
          attr_reader :clause
          include Variable

          def initialize(clause)
            @clause = clause
          end


          def [](p)
            clause.create_name_if_needed
            super
          end

          def as(name)
            super.tap do
              if clause.expr.include?(':')
                clause.expr.sub!(/[^:\?]*/, "#{clause.var_name}")
              else
                clause.expr = "#{name}:#{clause.expr}"
              end
            end
          end
        end
      end

    end
  end
end
