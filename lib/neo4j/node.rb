module Neo4j
  # A node in the graph with properties and relationships to other entities.
  # Along with relationships, nodes are the core building blocks of the Neo4j data representation model.
  # Node has three major groups of operations: operations that deal with relationships, operations that deal with properties and operations that traverse the node space.
  # The property operations give access to the key-value property pairs.
  # Property keys are always strings. Valid property value types are the primitives (<tt>String</tt>, <tt>Fixnum</tt>, <tt>Float</tt>, <tt>Boolean</tt>), and arrays of those primitives.
  #
  # The Neo4j::Node#new method does not return a new Ruby instance (!). Instead it will call the Neo4j Java API which will return a
  # *org.neo4j.kernel.impl.core.NodeProxy* object. This java object includes the same mixin as this class. The #class method on the java object
  # returns Neo4j::Node in order to make it feel like an ordinary Ruby object.
  #
  class Node
    extend Neo4j::Core::Node::ClassMethods
    extend Neo4j::Core::Index::ClassMethods
    extend Neo4j::Core::Loader::ClassMethods

    include Neo4j::Core::Property
    include Neo4j::Core::Rels
    # include Neo4j::Core::Traversal TODO
    include Neo4j::Core::Equal
    include Neo4j::Core::Index
    include Neo4j::Core::Node
    include Neo4j::Core::Loader

    self.node_indexer self

    class << self


      def extend_java_class(java_clazz) #:nodoc:
        java_clazz.class_eval do
          include Neo4j::Core::Property
          include Neo4j::Core::Rels
          # include Neo4j::Core::Traversal TODO
          include Neo4j::Core::Equal
          include Neo4j::Core::Index
          include Neo4j::Core::Node
          include Neo4j::Core::Loader
        end
      end
    end
  end

  Neo4j::Node.extend_java_class(Java::OrgNeo4jKernelImplCore::NodeProxy)

end