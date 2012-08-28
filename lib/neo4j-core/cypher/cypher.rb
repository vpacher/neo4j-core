module Neo4j
  module Core

    # This module contains a number of mixins and classes used by the neo4j.rb cypher DSL.
    # The Cypher DSL is evaluated in the context of {Neo4j::Cypher} which contains a number of methods (e.g. {Neo4j::Cypher#node})
    # which returns classes from this module.
    module Cypher



      class Create
        include ToPropString

        def initialize(clause_list, node_or_rel_var, props)
          @node_or_rel_var = node_or_rel_var
          @props = props
          super(clause_list, :create)
        end

        def to_s
          without_parantheses = if @props
                                  "#{@node_or_rel_var.to_s} #{to_prop_string(@props)}"
                                else
                                  @node_or_rel_var.to_s
                                end

          as_create_path? ? without_parantheses : "(#{without_parantheses})"
        end
      end

      class CreatePath
        include Variable
        attr_reader :var_name

        def initialize(eval_context, *args, &block)
          super(eval_context.clause_list, :create)

          args.each { |a| clause_list.delete(a) }
          i = 0
          @arg_list = args.map do |a|
            i += 1
            if a.is_a?(String) || a.is_a?(Symbol)
              a.to_s
            else
              "#w#{i}"
            end
          end.join(',')
          puts "CreatePath"
          debug
          sub_context = Neo4j::Cypher.new(&block)
          sub_context.clause_list.each(&:as_create_path!)
          sub_context.clause_list.each_with_index do |expr, i|
            puts "  #{i}. #{expr.clause} id: #{expr.object_id} class: #{expr.class} valid: #{expr.valid?}, path? #{expr.as_create_path?} to_s: #{expr.to_s}"
          end
          sub_context.skip_return!
          @body = sub_context.to_s

          #
          @var_name = "p#{eval_context.variables.size}"
          #next_pos = clause_list.count
          #eval_context.instance_exec(&block)
          #(next_pos ... clause_list.count).each{|i| clause_list[i].as_create_path!}
          #self.as_create_path!
        end


        def to_s
          "#{var_name} = #{@arg_list} '#{@body}'"
        end
      end

      class With
        def initialize(eval_context, *args, &block)
          expr = eval_context.clause_list
          super(expr, :with)
          args.each { |a| clause_list.delete(a) }
          i = 0
          @arg_list = args.map do |a|
            i += 1
            if a.is_a?(String) || a.is_a?(Symbol)
              a.to_s
            else
              "#{a.to_s} as w#{i}"
            end
          end.join(',')
          @body = Neo4j::Cypher.new(*args, &block).skip_return!.to_s
        end

        def to_s
          @arg_list + @body
        end
      end


      class Where
        include Clause

        def initialize(clause_list, where_statement = nil)
          initialize_clause(clause_list, :where)
          @where_statement = where_statement
        end

        def to_cypher
          @where_statement.to_s
        end
      end

      class Predicate
        attr_accessor :params

        def initialize(clause_list, params)
          @params = params
          @identifier = :x
          params[:input].referenced! if params[:input].respond_to?(:referenced!)
          super(clause_list, params[:clause])
        end

        def identifier(i)
          @identifier = i
          self
        end

        def to_s
          input = params[:input]
          if input.kind_of?(Property)
            yield_param = Property.new([], @identifier, nil)
            args = ""
          else
            yield_param = NodeVar.new([], []).as(@identifier.to_sym)
            args = "(#{input.var_name})"
          end
          context = Neo4j::Cypher.new(yield_param, &params[:predicate_block])
          context.clause_list.each { |e| e.clause = nil }
          if params[:clause] == :return
            where_or_colon = ':'
          else
            where_or_colon = 'WHERE'
          end
          predicate_value = context.to_s[1..-1] # skip separator ,
          "#{params[:op]}(#@identifier in #{params[:iterable]}#{args} #{where_or_colon} #{predicate_value})"
        end
      end

      class Entities
        include PredicateMethods
        attr_reader :input, :clause_list, :iterable

        def initialize(clause_list, iterable, input)
          @iterable = iterable
          @input = input
          @clause_type_list = clause_list
        end

      end

    end

  end

end
