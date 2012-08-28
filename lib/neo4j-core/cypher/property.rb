module Neo4j
  module Core
    module Cypher

      # A property is returned from a Variable by using the [] operator.
      #
      # It has a number of useful method like
      # <tt>count</tt>, <tt>sum</tt>, <tt>avg</tt>, <tt>min</tt>, <tt>max</tt>, <tt>collect</tt>, <tt>head</tt>, <tt>last</tt>, <tt>tail</tt>,
      #
      # @example
      #  n=node(2, 3, 4); n[:name].collect
      #  # same as START n0=node(2,3,4) RETURN collect(n0.property)
      class Property
        # @private
        attr_reader :var_expr, :eval_context

        include Referenceable
        include Clause

        def initialize(clause, prop_name)
          @var_expr = clause
          puts "VAR EXPR #{clause.class}, prop_name=#{prop_name} var_name = #{@var_expr.var_name}"
          #@var = var_expr.respond_to?(:clause) ? var_expr.clause.var_name : var_expr
          @clause_list = clause.clause_list # TODO
          @prop_name = prop_name
          raise "No prop name" unless prop_name
          @var_name = @prop_name ? "#{@var_expr.var_name}.#{@prop_name}" : @var.to_s
          @eval_context = EvalContext.new(self)
        end

        # @private
        def to_function!(var = @var.to_s)
          @var_name = "#{@prop_name}(#{var})"
          self
        end

        def returnable?
          true
        end

        # @private
        def function(func_name_pre, func_name_post = "")
          Operator.new(self, nil, func_name_pre, func_name_post)
        end

        # @private
        def binary_operator(op, post_fix = "")
          Operator.new(self, nil, op, post_fix).binary!
        end

        def to_s
          @var_name
        end

        class EvalContext
          include Comparable
          include MathOperator
          include MathFunctions
          include PredicateMethods

          attr_accessor :clause
          def initialize(clause)
            @clause = clause
          end

          # Make it possible to rename a property with a different name (AS)
          def as(new_name)
            puts "@var_name=#@var_name, self #{self.class}"
            clause.var_name = "#{clause.var_name} AS #{new_name}"
          end

          # required by the Predicate Methods Module
          # @see PredicateMethods
          # @private
          def iterable
            var_name
          end

          def input
            self
          end

          # @private
          def in?(values)
            binary_operator("", " IN [#{values.map { |x| %Q["#{x}"] }.join(',')}]")
          end

          # Only return distinct values/nodes/rels/paths
          def distinct
            @var_name = "distinct #{@var_name}"
            self
          end

          def length
            @prop_name = "length"
            to_function!
            self
          end

          %w[count sum avg min max collect head last tail].each do |meth_name|
            define_method(meth_name) do
              function(meth_name.to_s)
            end
          end

        end

      end

    end
  end
end