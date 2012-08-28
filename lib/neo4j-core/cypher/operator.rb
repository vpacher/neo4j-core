module Neo4j
  module Core
    module Cypher

      class Operand
        def initialize(obj)
          raise "OJOJOJ" if obj.is_a?(Operand)
          @obj = obj
        end
        #
        #
        #def regexp?(right)
        #  @op == "=~" || right.is_a?(Regexp)
        #end
        #
        #def to_regexp(val)
        #  %Q[/#{val.respond_to?(:source) ? val.source : val.to_s}/]
        #end

        def regexp?
          @obj.kind_of?(Regexp)
        end

        def to_s
          #puts "  TO_S #{@obj.class} : #{@obj.to_s}"
          if @obj.is_a?(String)
            %Q["#{@obj}"]
          elsif @obj.is_a?(Operator)
            #puts "  TJOJOJO - #{@obj.to_s}"
            "(#{@obj.to_s})"
          elsif @obj.respond_to?(:source)
            "/#{@obj.source}/"
          elsif @obj.respond_to?(:var_name)
            @obj.var_name
          elsif @obj.respond_to?(:clause)
            puts "  CLAUSE #{@obj.clause.class}/#{@obj.clause.to_s}"
            "#{@obj.clause.to_s}"
          else
            @obj.to_s
          end

        end
      end

      class Operator
        attr_reader :left_operand, :right_operand, :op, :neg, :post_fix, :eval_context
        include Clause

        def initialize(clause_list, left_operand, right_operand, op, post_fix = "")
          puts "Operator #{left_operand.to_s}/#{left_operand.class}, #{op}, #{right_operand.to_s}/#{right_operand.class}"
          initialize_clause(clause_list, :where)
          right_operand = Regexp.new(right_operand) if op == '=~' && right_operand.is_a?(String)
          @left_operand = Operand.new(left_operand)
          @right_operand = Operand.new(right_operand) if right_operand

          puts "  @right_operand=#{@left_operand.to_s}, @right_operand=#{@right_operand.to_s}"
          @op = @right_operand.regexp? ? '=~' : op
          @post_fix = post_fix

          # since we handle it our self in to_cypher method
          clause_list.delete(left_operand) if left_operand.kind_of?(Clause)
          clause_list.delete(right_operand) if right_operand.kind_of?(Clause)
          #
          #@left = quote(prop_or_operator)
          #if regexp?(primitive_or_context)
          #  @op = "=~"
          #  @right = to_regexp(primitive_or_context)
          #else
          #  @right = primitive_or_context && quote(primitive_or_context)
          #end
          @neg = nil
          @eval_context = EvalContext.new(self)
          puts "  LEFT #{@left_operand}/#{left_operand.class}, RIGHT #{@right_operand}/#{right_operand.class} RESULT #{to_s}"
        end

        def separator
          " and "
        end

        def quote(val)
          if val.respond_to?(:var_name) && !val.kind_of?(Match)
            puts "  YES #{val.var_name} for #{val.class}"
            val.var_name
          else
            val.is_a?(String) ? %Q["#{val}"] : val
          end
        end


        def valid?
          # it is only valid in a where clause if it's either binary or it has right and left values
          @binary ? @left : @left && @right
        end

        def not
          @neg = "not"
        end

        def to_s
          to_cypher
        end

        def to_cypher
          puts "  TO_CYPHER for @left_operand #{@left_operand.to_s} op: #{op} #{@right_operand.to_s}"
          if @right_operand
            neg ? "#{neg}(#{@left_operand.to_s} #{op} #{@right_operand.to_s})" : "#{@left_operand.to_s} #{op} #{@right_operand.to_s}"
          else
            # binary operator
            neg ? "#{neg}#{op}(#{@left_operand.to_s}#{post_fix})" : "#{op}(#{@left_operand.to_s}#{post_fix})"
          end
        end


        class EvalContext
          include MathFunctions
          
          attr_reader :clause
          
          def initialize(clause)
            @clause = clause
          end
          
          def count
            Operator.new(clause.clause_list, clause, nil, 'count').eval_context
          end

          def &(other)
            Operator.new(clause.clause_list, clause, other.clause, "and").eval_context
          end

          def |(other)
            Operator.new(clause.clause_list, clause, other.clause, "or").eval_context
          end

          def -@
            clause.not
            self
          end

          def not
            clause.not
            self
          end

          # Only in 1.9
          if RUBY_VERSION > "1.9.0"
            eval %{
             def !
               @neg = "not"
               self
             end
             }
          end

          def binary!
            @binary = true
            self
          end

        end

      end

    end
  end
end