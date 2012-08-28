module Neo4j
  module Core
    module Cypher
      # Created from a node's match operator like >> or <.
      class Match
        # @private
        attr_reader :dir, :clause_list, :left, :right, :var_name, :dir_op, :eval_context
        # @private
        attr_accessor :algorithm, :next, :prev

        include Clause
        include Referenceable

        def initialize(left_clause, right, dir, dir_op)
          initialize_clause(left_clause.clause_list, :match)
          @var_name = clause_list.create_variable(self)
          @dir = dir
          @dir_op = dir_op
          @prev = left_clause if left_clause.is_a?(Match)
          @left = left_clause.respond_to?(:clause) ? left_clause.clause : left_clause
          @right = right.respond_to?(:clause) ? right.clause : right
        end

        # @private
        def find_match_start
          c = self
          while (c.prev) do
            c = c.prev
          end
          c
        end

        def left_or_right_value(v)
          if v.respond_to?(:expr)
            v.expr
          elsif v.respond_to?(:var_name)
            puts "V #{v.class}, #{v.var_name}"
            v.var_name
          else
            v.to_s
          end
        end

        # @private
        def left_var_name
          left_or_right_value(@left)
        end

        # @private
        def right_var_name(r = @right)
          left_or_right_value(r)
        end

        # @private
        def right_expr
          c = @right
          r = while (c)
                break c.var_expr if c.respond_to?(:var_expr)
                c = c.respond_to?(:left_expr) && c.left_expr
              end || @right
          right_var_name(r)
        end

        # @private
        def to_cypher
          curr = find_match_start
          result = (referenced? || curr.referenced?) ? "#{var_name} = " : ""
          result << (algorithm ? "#{algorithm}(" : "")
          begin
            result << curr.expr
          end while (curr = curr.next)
          result << ")" if algorithm
          result
        end

        class EvalContext
          include Variable

          attr_reader :clause

          def initialize(clause)
            @clause = clause
          end

          def remove_me_from_clause_list
            clause.clause_list.delete(self)
          end

          def create_next(clazz, other, direction)
            remove_me_from_clause_list
            self.clause.next = clazz.new(self.clause, other, direction)
            self.clause.next.eval_context
          end

          # Generates a <tt>x in nodes(m3)</tt> cypher expression.
          #
          # @example
          #   p.nodes.all? { |x| x[:age] > 30 }
          def nodes
            Entities.new(@clause_type_list, "nodes", self)
          end

          # Generates a <tt>x in relationships(m3)</tt> cypher expression.
          #
          # @example
          #   p.relationships.all? { |x| x[:age] > 30 }
          def rels
            Entities.new(@clause_type_list, "relationships", self)
          end

          # returns the length of the path
          def length
            self.return_method = {:name => 'length', :bracket => true}
            self
          end

        end

      end

      # The left part of a match clause, e.g. node < rel(':friends')
      # Can return {MatchRelRight} using a match operator method.
      class MatchRelLeft < Match
        def initialize(left_clause, right, dir)
          super(left_clause, right, dir, dir == :incoming ? '<-' : '-')
          @eval_context = EvalContext.new(self)
#          clause_list.delete(right) if right.is_a?(Match)
        end


        # @return [String] a cypher string for this match.
        def expr
          if prev
            # we have chained more then one relationships in a match expression
            "#{dir_op}[#{right_expr}]"
          else
            "(#{left_var_name})#{dir_op}[#{right_expr}]"
          end
          # the right is an relationship and could be an clause_list, e.g "r?"
        end

        class EvalContext < Neo4j::Core::Cypher::Match::EvalContext
          attr_reader :clause

          def initialize(clause)
            @clause = clause
          end

          # @param [Symbol,NodeVar,String] other part of the match cypher statement.
          # @return [MatchRelRight] the right part of an relationship cypher query.
          def >(other)
            create_next(MatchRelRight, other, :outgoing)
          end

          # @see #>
          # @return (see #>)
          def <(other)
            create_next(MatchRelRight, other, :incoming)
          end

          # @see #>
          # @return (see #>)
          def -(other)
            create_next(MatchRelRight, other, :both)
          end

          def outgoing(*rels_and_node)
            right.outgoing(*rels_and_node)
          end

        end
      end

      class MatchRelRight < Match
        # @param left the left part of the query
        # @param [Symbol,NodeVar,String] right part of the match cypher statement.
        def initialize(left_clause, right, dir)
          super(left_clause, right, dir, dir == :outgoing ? '->' : '-')
          @eval_context = EvalContext.new(self)
 #         clause_list.delete(right) if right.is_a?(Match)
        end

        # @return [String] a cypher string for this match.
        def expr
          "#{dir_op}(#{right_expr})"
        end

        class EvalContext < Neo4j::Core::Cypher::Match::EvalContext
          attr_reader :clause

          def initialize(clause)
            @clause = clause
          end

          # @param [Symbol,NodeVar,String] other part of the match cypher statement.
          # @return [MatchRelLeft] the right part of an relationship cypher query.
          def >(other)
            remove_me_from_clause_list
            self.next = MatchRelLeft.new(clause, other, :outgoing)
          end

          # @see #>
          # @return (see #>)
          def <(other)
            remove_me_from_clause_list
            self.next = MatchRelLeft.new(clause, other, :incoming)
          end

          # @see #>
          # @return (see #>)
          def -(other)
            remove_me_from_clause_list
            self.next = MatchRelLeft.new(clause, other, :both)
          end

          def <<(other)
            remove_me_from_clause_list
            self.next = MatchNode.new(clause, other, :incoming)
          end

          def >>(other)
            remove_me_from_clause_list
            self.next = MatchNode.new(clause, other, :outgoing)
          end

          def outgoing(*rels_and_node)
            right.outgoing(*rels_and_node)
          end

          # negate this match
          def not
            remove_me_from_clause_list
            Operator.new(left, nil, "not").binary!
          end

          if RUBY_VERSION > "1.9.0"
            eval %{
             def !
          remove_me_from_clause_list
          ExprOp.new(left, nil, "not").binary!
             end
             }
          end
        end

      end

      # The right part of a match clause (node_b), e.g. node_a > rel(':friends') > node_b
      #
      class MatchNode < Match
        attr_reader :dir_op, :eval_context


        def initialize(left_clause, right, dir)
          dir_op = case dir
                     when :outgoing then
                       "-->"
                     when :incoming then
                       "<--"
                     when :both then
                       "--"
                   end
          super(left_clause, right, dir, dir_op)
          @eval_context = EvalContext.new(self)
          clause_list.delete(right) if right.is_a?(Match)
        end

        # @return [String] a cypher string for this match.
        def expr
          if prev
            # we have chained more then one relationships in a match expression
            "#{dir_op}(#{right_expr})"
          elsif right.respond_to?(:prev)
            "(#{left_var_name})#{dir_op}#{right_expr}"
          else
            # the right is an relationship and could be an clause_list, e.g "r?"
            "(#{left_var_name})#{dir_op}(#{right_expr})"
          end
        end

        class EvalContext < Neo4j::Core::Cypher::Match::EvalContext

          attr_reader :clause

          def initialize(clause)
            @clause = clause
          end

          def <<(other)
            create_next(MatchNode, other, :incoming)
          end

          def >>(other)
            create_next(MatchNode, other, :outgoing)
          end

          def <=>(other)
            create_next(MatchNode, other, :both)
          end

          # @param [Symbol,NodeVar,String] other part of the match cypher statement.
          # @return [MatchRelRight] the right part of an relationship cypher query.
          def >(other)
            create_next(MatchRelLeft, other, :outgoing)
          end

          # @see #>
          # @return (see #>)
          def <(other)
            create_next(MatchRelLeft, other, :incoming)
          end

          # @see #>
          # @return (see #>)
          def -(other)
            create_next(MatchRelLeft, other, :both)
          end
        end
      end

    end
  end
end