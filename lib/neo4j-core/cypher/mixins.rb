module Neo4j
  module Core
    module Cypher

      module MathFunctions
        def abs(value=nil)
          _add_math_func(:abs, value)
        end

        def sqrt(value=nil)
          _add_math_func(:sqrt, value)
        end

        def round(value=nil)
          _add_math_func(:round, value)
        end

        def sign(value=nil)
          _add_math_func(:sign, value)
        end

        # @private
        def _add_math_func(name, value=nil)
          value ||= self.respond_to?(:var_name) ? self.var_name : to_s
          clause_list.delete(self)
          Property.new(clause_list, nil, name).to_function!(value)
        end
      end

      module MathOperator
        def -(other)
          Operator.new(clause.clause_list, clause, other, '-').eval_context
        end

        def +(other)
          Operator.new(clause.clause_list, clause, other, '+').eval_context
        end
      end

      module Comparable
        def <(other)
          Operator.new(clause.clause_list, clause, other, '<').eval_context
        end

        def <=(other)
          Operator.new(clause.clause_list, clause, other, '<=').eval_context
        end

        def =~(other)
          Operator.new(clause.clause_list, clause, other, '=~').eval_context
        end

        def >(other)
          Operator.new(clause.clause_list, clause, other, '>').eval_context
        end

        def >=(other)
          Operator.new(clause.clause_list, clause, other, '>=').eval_context
        end

        ## Only in 1.9
        if RUBY_VERSION > "1.9.0"
          eval %{
            def !=(other)
              other.is_a?(String) ?  Operator.new(clause.clause_list, clause, other, "!=").eval_context : super
            end  }
        end

        def ==(other)
          Operator.new(clause.clause_list, clause, other, "=").eval_context
        end
      end

      module PredicateMethods
        def all?(&block)
          self.respond_to?(:iterable)
          Predicate.new(clause_list, :op => 'all', :clause => :where, :input => input, :iterable => iterable, :predicate_block => block)
        end

        def extract(&block)
          Predicate.new(clause_list, :op => 'extract', :clause => :return, :input => input, :iterable => iterable, :predicate_block => block)
        end

        def filter(&block)
          Predicate.new(clause_list, :op => 'filter', :clause => :return, :input => input, :iterable => iterable, :predicate_block => block)
        end

        def any?(&block)
          Predicate.new(@clause_type_list, :op => 'any', :clause => :where, :input => input, :iterable => iterable, :predicate_block => block)
        end

        def none?(&block)
          Predicate.new(@clause_type_list, :op => 'none', :clause => :where, :input => input, :iterable => iterable, :predicate_block => block)
        end

        def single?(&block)
          Predicate.new(@clause_type_list, :op => 'single', :clause => :where, :input => input, :iterable => iterable, :predicate_block => block)
        end

      end

      module Referenceable
        # @private
        def referenced!
          @referenced = true
        end

        # @private
        def referenced?
          !!@referenced
        end

        def var_name
          @var_name
        end
      end


      module Variable
        attr_accessor :return_method


        def create_variable(clause_list)
          @var_name ||= clause_list.create_variable(self)
        end

        def distinct
          self.return_method = {:name => 'distinct', :bracket => false}
          self
        end

        def [](prop_name)
          Property.new(clause, prop_name).eval_context
        end

        def as(v)
          clause.var_name = v
          self
        end

        # generates a <tt>ID</tt> cypher fragment.
        def neo_id
          Property.new(clause, 'ID').to_function!
        end

        # generates a <tt>has</tt> cypher fragment.
        def property?(p)
          p = Property.new(clause, p)
          p.binary_operator("has")
        end

        # generates a <tt>is null</tt> cypher fragment.
        def exist?
          p = Property.new(clause, p)
          p.binary_operator("", " is null")
        end

        # Can be used instead of [_classname] == klass
        def is_a?(klass)
          return super if klass.class != Class || !klass.respond_to?(:_load_wrapper)
          self[:_classname] == klass.to_s
        end

        def count
          #clause_list.delete(self)
          Operator.new(clause.clause_list, clause, nil, 'count')
        end
      end

      module Matchable

        def where(&block)
          x = block.call(self)
          clause_list.delete(x)
          Operator.new(x, nil, "").binary!
          self
        end

        def where_not(&block)
          x = block.call(self)
          clause_list.delete(x)
          Operator.new(x, nil, "not").binary!
          self
        end


        # This operator means related to, without regard to type or direction.
        # @param [Symbol, #var_name] other either a node (Symbol, #var_name)
        # @return [MatchRelLeft, MatchNode]
        def <=>(other)
          MatchNode.new(clause, other, :both).eval_context
        end

        # This operator means outgoing related to
        # @param [Symbol, #var_name, String] other the relationship
        # @return [MatchRelLeft, MatchNode]
        def >(other)
          MatchRelLeft.new(clause, other, :outgoing).eval_context
        end

        # This operator means any direction related to
        # @param (see #>)
        # @return [MatchRelLeft, MatchNode]
        def -(other)
          MatchRelLeft.new(clause, other, :both).eval_context
        end

        # This operator means incoming related to
        # @param (see #>)
        # @return [MatchRelLeft, MatchNode]
        def <(other)
          MatchRelLeft.new(clause, other, :incoming).eval_context
        end

        # Outgoing relationship to other node
        # @param [Symbol, #var_name] other either a node (Symbol, #var_name)
        # @return [MatchRelLeft, MatchNode]
        def >>(other)
          MatchNode.new(clause, other, :outgoing).eval_context
        end

        def outgoing(*rel_types)
          node, rel_string = node_and_relstring(rel_types)
          MatchRelLeft.new(self, rel_string, clause_list, :outgoing) > node
          node.eval_context
        end

        def outgoing?(*rel_types)
          node, rel_string = node_and_relstring(rel_types)
          MatchRelLeft.new(self, "?#{rel_string}", clause_list, :outgoing) > node
          node.eval_context
        end

        def incoming(*rel_types)
          node, rel_string = node_and_relstring(rel_types)
          MatchRelLeft.new(self, rel_string, clause_list, :incoming) < node
          node.eval_context
        end

        def incoming?(*rel_types)
          node, rel_string = node_and_relstring(rel_types)
          MatchRelLeft.new(self, "?#{rel_string}", clause_list, :incoming) < node
          node.eval_context
        end

        def both(*rel_types)
          node, rel_string = node_and_relstring(rel_types)
          MatchRelLeft.new(self, rel_string, clause_list, :both) < node
          node.eval_context
        end

        def both?(*rel_types)
          node, rel_string = node_and_relstring(rel_types)
          MatchRelLeft.new(self, "?#{rel_string}", clause_list, :both) < node
          node.eval_context
        end

        def node_and_relstring(rel_types)
          node = rel_types.pop if rel_types.last.kind_of?(Matchable)
          node ||= NodeVar.new(@clause_type_list, @variables)
          start_char = rel_types.first.is_a?(Symbol) ? ':' : ''
          rel_string = rel_types.empty? ? "?" : start_char + rel_types.map { |e| e.is_a?(Symbol) ? "`#{e}`" : e.to_s }.join('|')
          return node, rel_string
        end

        # Incoming relationship to other node
        # @param [Symbol, #var_name] other either a node (Symbol, #var_name)
        # @return [MatchRelLeft, MatchNode]
        def <<(other)
          MatchNode.new(clause, other, :incoming).eval_context
        end
      end

      module ToPropString
        def to_prop_string(props)
          key_values = props.keys.map do |key|
            raw = key.to_s[0,1] == '_'
            val = props[key].is_a?(String) && !raw ? "'#{props[key]}'" : props[key]
            "#{raw ? key.to_s[1..-1] : key} : #{val}"
          end
          "{#{key_values.join(', ')}}"
        end
      end
    end
  end
end