module Neo4j
  module Core

    module Cypher

      # Responsible for order of the clauses
      # Does expect a #clause method when included
      module Clause

        ORDER = [:start, :create, :match, :where, :return, :order_by, :skip, :limit]

        attr_reader :clause_type, :clause_list
        attr_accessor :var_name

        def initialize_clause(clause_list, clause_type)
          @clause_type = clause_type
          @clause_list = clause_list
          clause_list.insert(self)
          self
         end

        # @private
        def referenced!
          @referenced = true
        end

        # @private
        def referenced?
          !!@referenced
        end

        def <=>(other)
          clause_position <=> other.clause_position
        end

        def clause_position
          valid_clause?
          ORDER.find_index(clause_type)
        end

        def valid_clause?
          raise "Unknown clause_type '#{clause_type}' on #{self}" unless ORDER.include?(clause_type)
        end

        def separator
          ','
        end

        def returnable?
          false
        end

        def prefix
          clause_type.to_s.upcase
        end

      end

      class ClauseList
        attr_accessor :variables
        include Enumerable

        def each
          @clause_list.each { |c| yield c }
        end

        def initialize
          @variables = []
          @clause_list = []
        end

        def insert(expression)
          raise "Must be a clause #{expression.class}" unless expression.kind_of?(Clause)
          @clause_list << expression
          @clause_list.sort!
          self
        end

        def delete(clause_or_context)
          c = clause_or_context.respond_to?(:clause) ? clause_or_context.clause : clause_or_context
          raise "Expected a clause, got #{clause_or_context.class}" unless c.kind_of?(Clause)
          @clause_list.delete(c)
        end

        def debug
          puts "ClauseList vars #{variables.size}"
          @clause_list.each_with_index{|c, i| puts "  #{i} #{c.clause_type}, #{c.class} id: #{c.object_id}, #{c.to_cypher}"}
        end

        def remove_all(clause_type)
          @clause_list.delete_if{|c| c.clause_type == clause_type}
          self
        end

        def create_variable(var)
          raise "Already included #{var}" if @variables.include?(var)
          @variables << var
          "v#{@variables.size}"
        end

        def to_cypher
          prev_clause = nil
          inject([]) do |memo, clause|
            #next unless expr.valid?
            #next if expr.as_create_path? && expr.kind_of?(Neo4j::Core::Cypher::Create)
            memo << [] if clause.clause_type != prev_clause
            prev_clause = clause.clause_type
            memo.last << clause
            memo
          end.map do |list|
            #puts "TO CYPHER #{list.first.clause_type} size #{list.size}"
            "#{list.first.prefix} #{list.map{|c| c.to_cypher}.join(list.first.separator)}"
          end.join(' ')
        end

      end
    end

  end
end
