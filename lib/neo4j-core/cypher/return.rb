module Neo4j
  module Core
    module Cypher

      # The return statement in the cypher query
      class Return
        attr_reader :var_name, :eval_context
        include Clause

        def initialize(clause_list, name_or_ref, opts = {})
          initialize_clause(clause_list, :return)
          if name_or_ref.respond_to?(:clause)
            @name_or_ref = name_or_ref.clause
            @name_or_ref.referenced!
            @var_name = @name_or_ref.var_name
          else
            @name_or_ref = name_or_ref
            @var_name = @name_or_ref.to_s
          end
          puts "Return @name_or_ref=#{name_or_ref}/#{@name_or_ref.class}, @name_or_ref.kind_of?(Referenceable)=#{@name_or_ref.kind_of?(Referenceable)}"

          @eval_context = EvalContext.new(self)
          opts.each_pair { |k, v| self.send(k, v) }
        end


        def to_cypher
          puts "to_cypher #{return_method} as_return_method:#{return_method && as_return_method}, var_name:#{var_name}"
          return_method ? as_return_method : var_name.to_s
        end

        # @private
        def return_method
          @name_or_ref.respond_to?(:return_method) && @name_or_ref.return_method
        end

        # @private
        def as_return_method
          if return_method[:bracket]
            "#{return_method[:name]}(#@var_name)"
          else
            "#{return_method[:name]} #@var_name"
          end
        end

        class EvalContext

          attr_reader :clause

          def initialize(clause)
            @clause = clause
          end

          # Specifies an <tt>ORDER BY</tt> cypher query
          # @param [Property] props the properties which should be sorted
          # @return self
          def asc(*props)
            @order_by ||= OrderBy.new(clause_list)
            clause_list.delete(props.first)
            @order_by.asc(props)
            self
          end

          # Specifies an <tt>ORDER BY</tt> cypher query
          # @param [Property] props the properties which should be sorted
          # @return self
          def desc(*props)
            @order_by ||= OrderBy.new(clause_list)
            clause_list.delete(props.first)
            @order_by.desc(props)
            self
          end

          # Creates a <tt>SKIP</tt> cypher clause
          # @param [Fixnum] val the number of entries to skip
          # @return self
          def skip(val)
            Skip.new(clause_list, val)
            self
          end

          # Creates a <tt>LIMIT</tt> cypher clause
          # @param [Fixnum] val the number of entries to limit
          # @return self
          def limit(val)
            Limit.new(clause_list, val)
            self
          end

        end

      end

      # Can be used to skip result from a return clause
      class Skip
        def initialize(clause_list, value)
          super(clause_list, :skip)
          @value = value
        end

        def to_s
          @value
        end
      end

      # Can be used to limit result from a return clause
      class Limit
        def initialize(clause_list, value)
          super(clause_list, :limit)
          @value = value
        end

        def to_s
          @value
        end
      end

      class OrderBy
        def initialize(clause_list)
          super(clause_list, :order_by)
          @orders = []
        end

        def asc(props)
          @orders << [:asc, props]
        end

        def desc(props)
          @orders << [:desc, props]
        end

        def to_s
          @orders.map do |pair|
            if pair[0] == :asc
              pair[1].map(&:var_name).join(', ')
            else
              pair[1].map(&:var_name).join(', ') + " DESC"
            end
          end.join(', ')
        end
      end


    end
  end
end