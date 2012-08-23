require 'spec_helper'

class FooIndex
  extend Neo4j::Core::Index::ClassMethods
  include Neo4j::Core::Index

  self.node_indexer do
    index_names :exact => 'fooindex_exact', :fulltext => 'fooindex_fulltext'
    trigger_on :myindex => true
  end

  index :name
  index :desc, :type => :fulltext
end


describe "Neo4j::Cypher" do
  let(:an_entity) do
    Struct.new(:neo_id).new(42)
  end

  describe "DSL   { node(3) }" do
    it { Proc.new { node(3) }.should be_cypher("START n0=node(3) RETURN n0") }
  end

  describe "DSL   { node(Neo4j::Node.new) }" do
    it { a = an_entity; Proc.new { node(a) }.should be_cypher("START n0=node(42) RETURN n0") }
  end

  describe "DSL   { node(3,4) }" do
    it { Proc.new { node(3, 4) }.should be_cypher("START n0=node(3,4) RETURN n0") }
  end

  describe "DSL   { rel(3) }" do
    it { Proc.new { rel(3) }.should be_cypher("START r0=relationship(3) RETURN r0") }
  end

  describe "DSL   { rel(3, Neo4j::Relationship) }" do
    it { a = an_entity; Proc.new { rel(3, a) }.should be_cypher("START r0=relationship(3,42) RETURN r0") }
  end

  describe "DSL   { start n = node(3); match n <=> :x; ret :x }" do
    it { Proc.new { start n = node(3); match n <=> :x; ret :x }.should be_cypher("START n0=node(3) MATCH (n0)--(x) RETURN x") }
  end


  describe "DSL   { x = node; n = node(3); match n <=> x; ret x }" do
    it { Proc.new { x = node; n = node(3); match n <=> x; ret x }.should be_cypher("START n0=node(3) MATCH (n0)--(v0) RETURN v0") }
  end

  describe "DSL   { x = node; n = node(3); match n <=> x; ret x[:name] }" do
    it { Proc.new { x = node; n = node(3); match n <=> x; ret x[:name] }.should be_cypher("START n0=node(3) MATCH (n0)--(v0) RETURN v0.name") }
  end

  describe "DSL   { x = node(1); x[:name].as('SomethingTotallyDifferent') }" do
    it { Proc.new { x = node(1); x[:name].as('SomethingTotallyDifferent') }.should be_cypher(%{START n0=node(1) RETURN n0.name AS SomethingTotallyDifferent}) }
  end

  describe "DSL   { n = node(3).as(:n); n <=> node.as(:x); :x }" do
    it { Proc.new { n = node(3).as(:n); n <=> node.as(:x); :x }.should be_cypher("START n=node(3) MATCH (n)--(x) RETURN x") }
  end


  describe "DSL   { node(3) <=> node(:x); :x }" do
    it { Proc.new { node(3) <=> node(:x); :x }.should be_cypher("START n0=node(3) MATCH (n0)--(x) RETURN x") }
  end

  describe "DSL   { node(3) <=> 'foo'; :foo }" do
    it { Proc.new { node(3) <=> 'foo'; :foo }.should be_cypher("START n0=node(3) MATCH (n0)--(foo) RETURN foo") }
  end

  describe "DSL   { node(3) - ':knows|friends' - :foo; :foo }" do
    it { Proc.new { node(3) - ':knows|friends' - :foo; :foo }.should be_cypher("START n0=node(3) MATCH (n0)-[:knows|friends]-(foo) RETURN foo")}
  end

  describe "DSL   { r = rel(0); ret r }" do
    it { Proc.new { r = rel(0); ret r }.should be_cypher("START r0=relationship(0) RETURN r0") }
  end

  describe "DSL   { n = node(1, 2, 3); ret n }" do
    it { Proc.new { n = node(1, 2, 3); ret n }.should be_cypher("START n0=node(1,2,3) RETURN n0") }
  end

  describe %q[DSL   query(FooIndex, "name:A")] do
    it { Proc.new { query(FooIndex, "name:A") }.should be_cypher(%q[START n0=node:fooindex_exact(name:A) RETURN n0]) }
  end

  describe %q[DSL   query(FooIndex, "name:A", :fulltext)] do
    it { Proc.new { query(FooIndex, "name:A", :fulltext) }.should be_cypher(%q[START n0=node:fooindex_fulltext(name:A) RETURN n0]) }
  end

  describe %q[DSL   lookup(FooIndex, "name", "A")] do
    it { Proc.new { lookup(FooIndex, "name", "A") }.should be_cypher(%q[START n0=node:fooindex_exact(name="A") RETURN n0]) }
  end

  describe %q[DSL   lookup(FooIndex, "desc", "A")] do
    it { Proc.new { lookup(FooIndex, "desc", "A") }.should be_cypher(%q[START n0=node:fooindex_fulltext(desc="A") RETURN n0]) }
  end

  describe "DSL   { a = node(1); b=node(2); ret(a, b) }" do
    it { Proc.new { a = node(1); b=node(2); ret(a, b) }.should be_cypher(%q[START n0=node(1),n1=node(2) RETURN n0,n1]) }
  end

  describe "DSL   { [node(1), node(2)] }" do
    it { Proc.new { [node(1), node(2)] }.should be_cypher(%q[START n0=node(1),n1=node(2) RETURN n0,n1]) }
  end

  describe "DSL   { node(3) >> :x; :x }" do
    it { Proc.new { node(3) >> :x; :x }.should be_cypher("START n0=node(3) MATCH (n0)-->(x) RETURN x") }
  end

  describe "DSL   { node(3) >> node(:c) >> :d; :c }" do
    it { Proc.new { node(3) >> node(:c) >> :d; :c }.should be_cypher(%{START n0=node(3) MATCH (n0)-->(c)-->(d) RETURN c}) }
  end

  describe "DSL   { node(3) << :x; :x }" do
    it { Proc.new { node(3) << :x; :x }.should be_cypher("START n0=node(3) MATCH (n0)<--(x) RETURN x") }
  end

  describe "DSL   { node(3) << node(:c) << :d; :c }" do
    it { Proc.new { node(3) << node(:c) << :d; :c }.should be_cypher(%{START n0=node(3) MATCH (n0)<--(c)<--(d) RETURN c}) }
  end

  describe "DSL   { node(3) > :r > :x; :r }" do
    it { Proc.new { node(3) > :r > :x; :r }.should be_cypher("START n0=node(3) MATCH (n0)-[r]->(x) RETURN r") }
  end

  describe "DSL   { node(3) << node(:c) < ':friends' < :d; :d }" do
    it { Proc.new { node(3) << node(:c) < ':friends' < :d; :d }.should be_cypher(%{START n0=node(3) MATCH (n0)<--(c)<-[:friends]-(d) RETURN d}) }
  end

  describe "DSL   { (node(3) << node(:c)) - ':friends' - :d; :d }" do
    it { Proc.new { (node(3) << node(:c)) - ':friends' - :d; :d }.should be_cypher(%{START n0=node(3) MATCH (n0)<--(c)-[:friends]-(d) RETURN d}) }
  end

  describe "DSL   { node(3) << node(:c) > ':friends' > :d; :d }" do
    it { Proc.new { node(3) << node(:c) > ':friends' > :d; :d }.should be_cypher(%{START n0=node(3) MATCH (n0)<--(c)-[:friends]->(d) RETURN d}) }
  end

  describe "DSL   { node(3) > 'r:friends' > :x; :r }" do
    it { Proc.new { node(3) > 'r:friends' > :x; :r }.should be_cypher("START n0=node(3) MATCH (n0)-[r:friends]->(x) RETURN r") }
  end

  describe "DSL   { r = rel('r:friends').as(:r); node(3) > r > :x; r }" do
    it { Proc.new { r = rel('r:friends').as(:r); node(3) > r > :x; r }.should be_cypher("START n0=node(3) MATCH (n0)-[r:friends]->(x) RETURN r") }
  end

  describe "DSL   { r = rel('r:friends'); node(3) > r > :x; r }" do
    it { Proc.new { r = rel('r:friends'); node(3) > r > :x; r }.should be_cypher("START n0=node(3) MATCH (n0)-[r:friends]->(x) RETURN r") }
  end

  describe "DSL   { r = rel('r?:friends'); node(3) > r > :x; r }" do
    it { Proc.new { r = rel('r?:friends'); node(3) > r > :x; r }.should be_cypher("START n0=node(3) MATCH (n0)-[r?:friends]->(x) RETURN r") }
  end

  describe "DSL   { node(3) > rel('?') > :x; :x }" do
    it { Proc.new { node(3) > rel('?') > :x; :x }.should be_cypher("START n0=node(3) MATCH (n0)-[?]->(x) RETURN x") }
  end

  describe "DSL   { node(3) > rel('r?') > :x; :x }" do
    it { Proc.new { node(3) > rel('r?') > :x; :x }.should be_cypher("START n0=node(3) MATCH (n0)-[r?]->(x) RETURN x") }
  end

  describe "DSL   { node(3) > rel('r?') > 'bla'; :x }" do
    it { Proc.new { node(3) > rel('r?') > 'bla'; :x }.should be_cypher("START n0=node(3) MATCH (n0)-[r?]->(bla) RETURN x") }
  end

  describe "DSL   { node(3) > ':r' > 'bla'; :x }" do
    it { Proc.new { node(3) > ':r' > 'bla'; :x }.should be_cypher("START n0=node(3) MATCH (n0)-[:r]->(bla) RETURN x") }
  end

  describe "DSL   { node(3) > :r > node; node }" do
    it { Proc.new { node(3) > :r > node; :r }.should be_cypher("START n0=node(3) MATCH (n0)-[r]->(v0) RETURN r") }
  end

  describe %{n=node(3,1).as(:n); where(%q[n.age < 30 and n.name = "Tobias") or not(n.name = "Tobias"')]} do
    it { Proc.new { n=node(3, 1).as(:n); where(%q[(n.age < 30 and n.name = "Tobias") or not(n.name = "Tobias")]); ret n }.should be_cypher(%q[START n=node(3,1) WHERE (n.age < 30 and n.name = "Tobias") or not(n.name = "Tobias") RETURN n]) }
  end

  describe %{n=node(3,1); where n[:age] < 30; ret n} do
    it { Proc.new { n=node(3, 1); where n[:age] < 30; ret n }.should be_cypher(%q[START n0=node(3,1) WHERE n0.age < 30 RETURN n0]) }
  end

  describe %{n=node(3, 1); where (n[:name] == 'foo').not; ret n} do
    it { Proc.new { n=node(3, 1); where (n[:name] == 'foo').not; ret n }.should be_cypher(%q[START n0=node(3,1) WHERE not(n0.name = "foo") RETURN n0]) }
  end

  describe %{r=rel(3,1); where r[:since] < 2; r} do
    it { Proc.new { r=rel(3, 1); where r[:since] < 2; r }.should be_cypher(%q[START r0=relationship(3,1) WHERE r0.since < 2 RETURN r0]) }
  end

  describe %{r=rel('r?'); n=node(2); n > r > :x; r[:since] < 2; r} do
    it { Proc.new { r=rel('r?'); n=node(2); n > r > :x; r[:since] < 2; r }.should be_cypher(%q[START n0=node(2) MATCH (n0)-[r?]->(x) WHERE r.since < 2 RETURN r]) }
  end

  describe %{r=rel('r:friends|like'); n=node(2); n > r > :x; r[:since] < 2; r} do
    it { Proc.new { r=rel('r:friends|like'); n=node(2); n > r > :x; r[:since] < 2; r }.should be_cypher(%q[START n0=node(2) MATCH (n0)-[r:friends|like]->(x) WHERE r.since < 2 RETURN r]) }
  end

  describe %{n=node(3, 1); where((n[:age] < 30) & ((n[:name] == 'foo') | (n[:size] > n[:age]))); ret n} do
    it { Proc.new { n=node(3, 1); where((n[:age] < 30) & ((n[:name] == 'foo') | (n[:size] > n[:age]))); ret n }.should be_cypher(%q[START n0=node(3,1) WHERE (n0.age < 30) and ((n0.name = "foo") or (n0.size > n0.age)) RETURN n0]) }
  end

  describe %{ n=node(3).as(:n); where((n[:desc] =~ /.\d+/) ); ret n} do
    it { Proc.new { n=node(3).as(:n); where(n[:desc] =~ /.\d+/); ret n }.should be_cypher(%q[START n=node(3) WHERE n.desc =~ /.\d+/ RETURN n]) }
  end

  describe %{ n=node(3).as(:n); where((n[:desc] =~ ".d+") ); ret n} do
    it { Proc.new { n=node(3).as(:n); where(n[:desc] =~ ".d+"); ret n }.should be_cypher(%q[START n=node(3) WHERE n.desc =~ /.d+/ RETURN n]) }
  end

  describe %{ n=node(3).as(:n); where((n[:desc] == /.\d+/) ); ret n} do
    it { Proc.new { n=node(3).as(:n); where(n[:desc] == /.\d+/); ret n }.should be_cypher(%q[START n=node(3) WHERE n.desc =~ /.\d+/ RETURN n]) }
  end

  describe %{n=node(3,4); n[:desc] == "hej"; n} do
    it { Proc.new { n=node(3, 4); n[:desc] == "hej"; n }.should be_cypher(%q[START n0=node(3,4) WHERE n0.desc = "hej" RETURN n0]) }
  end

  describe %{node(3,4) <=> :x; node(:x)[:desc] =~ /hej/; :x} do
    it { Proc.new { node(3, 4) <=> :x; node(:x)[:desc] =~ /hej/; :x }.should be_cypher(%q[START n0=node(3,4) MATCH (n0)--(x) WHERE x.desc =~ /hej/ RETURN x]) }
  end

  describe %{ a, x=node(1), node(2); p = shortest_path { a > '?*' > x }; p } do
    it { Proc.new { a, x=node(1), node(2); p = shortest_path { a > '?*' > x }; p }.should be_cypher(%{START n0=node(1),n1=node(2) MATCH m3 = shortestPath((n0)-[?*]->(n1)) RETURN m3}) }
  end

  describe %{shortest_path{node(1) > '?*' > node(2)}} do
    it { Proc.new { shortest_path { node(1) > '?*' > node(2) } }.should be_cypher(%{START n0=node(1),n2=node(2) MATCH m3 = shortestPath((n0)-[?*]->(n2)) RETURN m2}) }
  end

  describe %{shortest_path { node(1) > '?*' > :x > ':friend' > node(2)}} do
    it { Proc.new { shortest_path { node(1) > '?*' > :x > ':friend' > node(2) } }.should be_cypher(%{START n0=node(1),n2=node(2) MATCH m3 = shortestPath((n0)-[?*]->(x)-[:friend]->(n2)) RETURN m2}) }
  end

  describe "a=node(3); a > ':knows' > node(:b) > ':knows' > :c; :c" do
    it { Proc.new { a=node(3); a > ':knows' > node(:b) > ':knows' > :c; :c }.should be_cypher(%{START n0=node(3) MATCH (n0)-[:knows]->(b)-[:knows]->(c) RETURN c}) }
  end

  describe "a=node(3); a < ':knows' < :c; :c" do
    it { Proc.new { a=node(3); a < ':knows' < :c; :c }.should be_cypher(%{START n0=node(3) MATCH (n0)<-[:knows]-(c) RETURN c}) }
  end

  describe "a=node(3); a < ':knows' < node(:c) < :friends < :d; :friends" do
    it { Proc.new { a=node(3); a < ':knows' < node(:c) < :friends < :d; :friends }.should be_cypher(%{START n0=node(3) MATCH (n0)<-[:knows]-(c)<-[friends]-(d) RETURN friends}) }
  end

  describe "a=node(3); a < ':knows' < node(:c) > :friends > :d; :friends" do
    it { Proc.new { a=node(3); a < ':knows' < node(:c) > :friends > :d; :friends }.should be_cypher(%{START n0=node(3) MATCH (n0)<-[:knows]-(c)-[friends]->(d) RETURN friends}) }
  end

  describe "node(3) - ':knows' - :c; :c" do
    it { Proc.new { node(3) - ':knows' - :c; :c }.should be_cypher(%{START n0=node(3) MATCH (n0)-[:knows]-(c) RETURN c}) }
  end

  describe %{a = node(3); a - ':knows' - :c - ":friends" - :d; :c} do
    it { Proc.new { a = node(3); a - ':knows' - :c - ":friends" - :d; :c }.should be_cypher(%{START n0=node(3) MATCH (n0)-[:knows]-(c)-[:friends]-(d) RETURN c}) }
  end

  describe %{a=node(3); a > ':knows' > :b > ':knows' > :c; a -':blocks' - :d -':knows' -:c; [a, :b, :c, :d] } do
    it { Proc.new { a=node(3); a > ':knows' > :b > ':knows' > :c; a -':blocks' - :d -':knows' -:c; [a, :b, :c, :d] }.should be_cypher(%{START n0=node(3) MATCH (n0)-[:knows]->(b)-[:knows]->(c),(n0)-[:blocks]-(d)-[:knows]-(c) RETURN n0,b,c,d}) }
  end

  describe %{n=node(3); n > (r=rel('r')) > node; r.rel_type =~ /K.*/; r} do
    it { Proc.new { n=node(3); n > (r=rel('r')) > node; r.rel_type =~ /K.*/; r }.should be_cypher(%{START n0=node(3) MATCH (n0)-[r]->(v1) WHERE type(r) =~ /K.*/ RETURN r}) }
  end

  describe %{n=node(3, 1); n.property?(:belt); n} do
    it { Proc.new { n=node(3, 1); n.property?(:belt); n }.should be_cypher(%{START n0=node(3,1) WHERE has(n0.belt) RETURN n0}) }
  end

  describe %{n=node(3,1); n[:belt?] == "white";n} do
    it { Proc.new { n=node(3, 1); n[:belt?] == "white"; n }.should be_cypher(%{START n0=node(3,1) WHERE n0.belt? = "white" RETURN n0}) }
  end

  describe %{a=node(1).as(:a);b=node(3,2); r=rel('r?'); a < r < b; r.exist? ; b} do
    it { Proc.new { a=node(1).as(:a); b=node(3, 2); r=rel('r?'); a < r < b; r.exist?; b }.should be_cypher(%{START a=node(1),n1=node(3,2) MATCH (a)<-[r?]-(n1) WHERE (r is null) RETURN n1}) }
  end

  describe %{names = ["Peter", "Tobias"]; a=node(3,1,2).as(:a); a[:name].in?(names); ret a} do
    it { Proc.new { names = ["Peter", "Tobias"]; a=node(3, 1, 2).as(:a); a[:name].in?(names); ret a }.should be_cypher(%{START a=node(3,1,2) WHERE (a.name IN ["Peter","Tobias"]) RETURN a}) }
  end

  describe %{node(3) >> :b} do
    it { Proc.new { node(3) >> :b }.should be_cypher(%{START n0=node(3) MATCH m2 = (n0)-->(b) RETURN m2}) }
  end

  describe %{p = node(3) >> :b; [:b, p.length]} do
    it { Proc.new { p = node(3) >> :b; [:b, p.length] }.should be_cypher(%{START n0=node(3) MATCH m2 = (n0)-->(b) RETURN b,length(m2)}) }
  end

  describe %{p = node(3) >> :b; [:b, p.length]} do
    it { Proc.new { p = node(3) >> :b; [:b, p.length] }.should be_cypher(%{START n0=node(3) MATCH m2 = (n0)-->(b) RETURN b,length(m2)}) }
  end

  describe %{p1 = (node(3).as(:a) > ":knows*0..1" > :b).as(:p1); p2=node(:b) > ':blocks*0..1' > :c; [:a,:b,:c, p1.length, p2.length]} do
    it { Proc.new { p1 = (node(3).as(:a) > ":knows*0..1" > :b).as(:p1); p2=node(:b) > ':blocks*0..1' > :c; [:a, :b, :c, p1.length, p2.length] }.should be_cypher(%{START a=node(3) MATCH p1 = (a)-[:knows*0..1]->(b),m3 = (b)-[:blocks*0..1]->(c) RETURN a,b,c,length(p1),length(m3)}) }
  end

  describe %{n=node(1,2).as(:n); n[:age?]} do
    it { Proc.new { n=node(1, 2).as(:n); n[:age?] }.should be_cypher(%{START n=node(1,2) RETURN n.age?}) }
  end

  describe %{n=node(1); n>>:b; n.distinct} do
    it { Proc.new { n=node(1); n>>:b; n.distinct }.should be_cypher(%{START n0=node(1) MATCH (n0)-->(b) RETURN distinct n0}) }
  end

  describe %{node(1)>>(b=node(:b)); b.distinct} do
    it { Proc.new { node(1)>>(b=node(:b)); b.distinct }.should be_cypher(%{START n0=node(1) MATCH (n0)-->(b) RETURN distinct b}) }
  end

  describe %{(n = node(2))>>:x; [n,count]} do
    it { Proc.new { (n = node(2))>>:x; [n, count] }.should be_cypher(%{START n0=node(2) MATCH (n0)-->(x) RETURN n0,count(*)}) }
  end

  describe %{DSL    (n = node(2))>>:x; count} do
    it { Proc.new { (n = node(2))>>:x; count }.should be_cypher(%{START n0=node(2) MATCH (n0)-->(x) RETURN count(*)}) }
  end

  describe %{DSL    r=rel('r'); node(2)>r>node; ret r.rel_type, count} do
    it { Proc.new { r=rel('r'); node(2)>r>node; ret r.rel_type, count }.should be_cypher(%{START n0=node(2) MATCH (n0)-[r]->(v1) RETURN type(r),count(*)}) }
  end

  describe %{DSL    node(2)>>:x; count(:x)} do
    it { Proc.new { node(2)>>:x; count(:x) }.should be_cypher(%{START n0=node(2) MATCH (n0)-->(x) RETURN count(x)}) }
  end

  describe %{DSL    n=node(2, 3, 4, 1); n[:property?].count} do
    it { Proc.new { n=node(2, 3, 4, 1); n[:property?].count }.should be_cypher(%{START n0=node(2,3,4,1) RETURN count(n0.property?)}) }
  end

  describe %{DSL    n=node(2, 3, 4); n[:property].sum} do
    it { Proc.new { n=node(2, 3, 4); n[:property].sum }.should be_cypher(%{START n0=node(2,3,4) RETURN sum(n0.property)}) }
  end

  describe %{DSL    n=node(2, 3, 4); n[:property].avg} do
    it { Proc.new { n=node(2, 3, 4); n[:property].avg }.should be_cypher(%{START n0=node(2,3,4) RETURN avg(n0.property)}) }
  end

  describe %{DSL    n=node(2, 3, 4); n[:property].max} do
    it { Proc.new { n=node(2, 3, 4); n[:property].max }.should be_cypher(%{START n0=node(2,3,4) RETURN max(n0.property)}) }
  end

  describe %{DSL    n=node(2, 3, 4); n[:property].min} do
    it { Proc.new { n=node(2, 3, 4); n[:property].min }.should be_cypher(%{START n0=node(2,3,4) RETURN min(n0.property)}) }
  end

  describe %{DSL    n=node(2, 3, 4); n[:property].collect} do
    it { Proc.new { n=node(2, 3, 4); n[:property].collect }.should be_cypher(%{START n0=node(2,3,4) RETURN collect(n0.property)}) }
  end

  describe %{DSL    n=node(2); n>>:b; n[:eyes].distinct.count} do
    it { Proc.new { n=node(2); n>>:b; n[:eyes].distinct.count }.should be_cypher(%{START n0=node(2) MATCH (n0)-->(b) RETURN count(distinct n0.eyes)}) }
  end

  describe %{DSL    node(3, 4, 5).neo_id} do
    it { Proc.new { node(3, 4, 5).neo_id }.should be_cypher(%{START n0=node(3,4,5) RETURN ID(n0)}) }
  end

  describe %{DSL    a = node(3, 4, 5); a - (r=rel("r")) - :b; r.neo_id < 20; r} do
    it { Proc.new { a = node(3, 4, 5); a - (r=rel("r")) - :b; r.neo_id < 20; r }.should be_cypher(%{START n0=node(3,4,5) MATCH (n0)-[r]-(b) WHERE ID(r) < 20 RETURN r}) }
  end

  describe "        a = node(3); b=node(1); match p = a > '*1..3' > b; where p.nodes.all? { |x| x[:age] > 30 }; ret p" do
    it { Proc.new { a = node(3); b=node(1); match p = a > '*1..3' > b; where p.nodes.all? { |x| x[:age] > 30 }; ret p }.should be_cypher(%{START n0=node(3),n1=node(1) MATCH m3 = (n0)-[*1..3]->(n1) WHERE all(x in nodes(m3) WHERE x.age > 30) RETURN m3}) }
  end

  describe "DSL     a = node(2); a[:array].any? { |x| x == 'one' }; a" do
    it { Proc.new { a = node(2); a[:array].any? { |x| x == 'one' }; a }.should be_cypher(%{START n0=node(2) WHERE any(x in n0.array WHERE x = "one") RETURN n0}) }
  end

  describe "        p=node(3)>'*1..3'>:b; p.nodes.none? { |x| x[:age] == 25 };p" do
    it { Proc.new { p=node(3)>'*1..3'>:b; p.nodes.none? { |x| x[:age] == 25 }; p }.should be_cypher(%{START n0=node(3) MATCH m2 = (n0)-[*1..3]->(b) WHERE none(x in nodes(m2) WHERE x.age = 25) RETURN m2}) }
  end

  describe %{       p = node(3)>>:b; p.nodes.single? { |x| x[:eyes] == 'blue' }; p } do
    it { Proc.new { p = node(3)>>:b; p.nodes.single? { |x| x[:eyes] == 'blue' }; p }.should be_cypher(%{START n0=node(3) MATCH m2 = (n0)-->(b) WHERE single(x in nodes(m2) WHERE x.eyes = "blue") RETURN m2}) }
  end

  describe %{       p = node(3)>>:b; p.rels.single? { |x| x[:eyes] == 'blue' }; p } do
    it { Proc.new { p = node(3)>>:b; p.rels.single? { |x| x[:eyes] == 'blue' }; p }.should be_cypher(%{START n0=node(3) MATCH m2 = (n0)-->(b) WHERE single(x in relationships(m2) WHERE x.eyes = "blue") RETURN m2}) }
  end

  describe %{       a=node(3); b=node(4); c=node(1); p=a>>b>>c; p.nodes.extract { |x| x[:age] }} do
    it { Proc.new { a=node(3); b=node(4); c=node(1); p=a>>b>>c; p.nodes.extract { |x| x[:age] } }.should be_cypher(%{START n0=node(3),n1=node(4),n2=node(1) MATCH m4 = (n0)-->(n1)-->(n2) RETURN extract(x in nodes(m4) : x.age)}) }
  end

  describe %{       a=node(2); ret a[:array], a[:array].filter{|x| x.length == 3}} do
    it { Proc.new { a=node(2); ret a[:array], a[:array].filter { |x| x.length == 3 } }.should be_cypher(%{START n0=node(2) RETURN n0.array,filter(x in n0.array : length(x) = 3)}) }
  end

  describe %{       a=node(2); ret a[:array], a[:array].filter{|x| x == "hej"}} do
    it { Proc.new { a=node(2); ret a[:array], a[:array].filter { |x| x == "hej" } }.should be_cypher(%{START n0=node(2) RETURN n0.array,filter(x in n0.array : x = "hej")}) }
  end

  describe %{       a=node(3); coalesce(a[:hair_colour?], a[:eyes?]) } do
    it { Proc.new { a=node(3); coalesce(a[:hair_colour?], a[:eyes?]) }.should be_cypher(%{START n0=node(3) RETURN coalesce(n0.hair_colour?, n0.eyes?)}) }
  end

  describe %{       a=node(2); ret a[:array], a[:array].head } do
    it { Proc.new { a=node(2); ret a[:array], a[:array].head }.should be_cypher(%{START n0=node(2) RETURN n0.array,head(n0.array)}) }
  end

  describe %{       a=node(2); ret a[:array], a[:array].last } do
    it { Proc.new { a=node(2); ret a[:array], a[:array].last }.should be_cypher(%{START n0=node(2) RETURN n0.array,last(n0.array)}) }
  end

  describe %{       a=node(2); ret a[:array], a[:array].tail } do
    it { Proc.new { a=node(2); ret a[:array], a[:array].tail }.should be_cypher(%{START n0=node(2) RETURN n0.array,tail(n0.array)}) }
  end

  describe %{       a=node(3); b = node(2); ret a[:age], b[:age], (a[:age] - b[:age]).abs } do
    it { Proc.new { a=node(3); b = node(2); ret a[:age], b[:age], (a[:age] - b[:age]).abs }.should be_cypher(%{START n0=node(3),n1=node(2) RETURN n0.age,n1.age,abs(n0.age - n1.age)}) }
  end

  describe %{       a=node(3); b = node(2); ret (a[:age] - b[:age]).abs.as("newname") } do
    it { Proc.new { a=node(3); b = node(2); ret (a[:age] - b[:age]).abs.as("newname") }.should be_cypher(%{START n0=node(3),n1=node(2) RETURN abs(n0.age - n1.age) AS newname}) }
  end

  describe %{       a=node(3); (a[:x] - a[:y]).abs==3; a } do
    it { Proc.new { a=node(3); (a[:x] - a[:y]).abs==3; a }.should be_cypher(%{START n0=node(3) WHERE abs(n0.x - n0.y) = 3 RETURN n0}) }
  end

  describe %{       a=node(3); a[:x].abs==3; a; a } do
    it { Proc.new { a=node(3); a[:x].abs==3; a }.should be_cypher(%{START n0=node(3) WHERE abs(n0.x) = 3 RETURN n0}) }
  end

  describe %{       a=node(3); abs(-3)} do
    it { Proc.new { a=node(3); abs(-3) }.should be_cypher(%{START n0=node(3) RETURN abs(-3)}) }
  end

  describe %{       a=node(3); round(3.14)} do
    it { Proc.new { a=node(3); round(3.14) }.should be_cypher(%{START n0=node(3) RETURN round(3.14)}) }
  end

  describe %{       a=node(3); sqrt(256)} do
    it { Proc.new { a=node(3); sqrt(256) }.should be_cypher(%{START n0=node(3) RETURN sqrt(256)}) }
  end

  describe %{       a=node(3); sign(256)} do
    it { Proc.new { a=node(3); sign(256) }.should be_cypher(%{START n0=node(3) RETURN sign(256)}) }
  end

  describe %{       n=node(3,1,2); ret(n).asc(n[:name]} do
    it { Proc.new { n=node(3, 1, 2); ret(n).asc(n[:name]) }.should be_cypher(%{START n0=node(3,1,2) RETURN n0 ORDER BY n0.name}) }
  end

  describe %{       n=node(3,1,2); ret(n, n[:name]).asc(n[:name], n[:age])} do
    it { Proc.new { n=node(3, 1, 2); ret(n, n[:name]).asc(n[:name], n[:age]) }.should be_cypher(%{START n0=node(3,1,2) RETURN n0,n0.name ORDER BY n0.name, n0.age}) }
  end

  describe %{       n=node(3,1,2); ret(n).desc(n[:name]} do
    it { Proc.new { n=node(3, 1, 2); ret(n).desc(n[:name]) }.should be_cypher(%{START n0=node(3,1,2) RETURN n0 ORDER BY n0.name DESC}) }
  end

  describe %{       n=node(3,1,2); p=node(5,6); ret(n).asc(p[:age]).desc(n[:name]) } do
    it { Proc.new { n=node(3, 1, 2); p=node(5, 6); ret(n).asc(p[:age]).desc(n[:name]) }.should be_cypher(%{START n0=node(3,1,2),n1=node(5,6) RETURN n0 ORDER BY n1.age, n0.name DESC}) }
  end

  describe %{       a=node(3,4,5,1,2); ret(a).asc(a[:name]).skip(3)} do
    it { Proc.new { a=node(3, 4, 5, 1, 2); ret(a).asc(a[:name]).skip(3) }.should be_cypher(%{START n0=node(3,4,5,1,2) RETURN n0 ORDER BY n0.name SKIP 3}) }
  end

  describe %{       a=node(3,4,5,1,2); ret(a).asc(a[:name]).skip(1).limit(2} do
    it { Proc.new { a=node(3, 4, 5, 1, 2); ret(a).asc(a[:name]).skip(1).limit(2) }.should be_cypher(%{START n0=node(3,4,5,1,2) RETURN n0 ORDER BY n0.name SKIP 1 LIMIT 2}) }
  end

  describe %{       a=node(3,4,5,1,2); ret a, :asc => a[:name], :skip => 1, :limit => 2} do
    it { Proc.new { a=node(3, 4, 5, 1, 2); ret a, :asc => a[:name], :skip => 1, :limit => 2 }.should be_cypher(%{START n0=node(3,4,5,1,2) RETURN n0 ORDER BY n0.name SKIP 1 LIMIT 2}) }
  end

  describe %{       a=node(3); c = node(2); p = a >> :b >> c; nodes(p) } do
    it { Proc.new { a=node(3); c = node(2); p = a >> :b >> c; nodes(p) }.should be_cypher(%{START n0=node(3),n1=node(2) MATCH m3 = (n0)-->(b)-->(n1) RETURN nodes(m3)}) }
  end


  describe %{       a=node(3); c = node(2); p = a >> :b >> c; rels(p) } do
    it { Proc.new { a=node(3); c = node(2); p = a >> :b >> c; rels(p) }.should be_cypher(%{START n0=node(3),n1=node(2) MATCH m3 = (n0)-->(b)-->(n1) RETURN relationships(m3)}) }
  end

  describe "5.2. Basic Friend finding based on social neighborhood " do
    it do
      Proc.new do
        joe=node(3)
        friends_of_friends = node(:friends_of_friends)
        joe > ':knows' > node(:friend) > ':knows' > friends_of_friends
        r = rel('r?:knows').as(:r)
        joe > r > friends_of_friends
        r.exist?
        ret(friends_of_friends[:name], count).desc(count).asc(friends_of_friends[:name])
      end.should be_cypher(%{START n0=node(3) MATCH (n0)-[:knows]->(friend)-[:knows]->(friends_of_friends),(n0)-[r?:knows]->(friends_of_friends) WHERE (r is null) RETURN friends_of_friends.name,count(*) ORDER BY count(*) DESC, friends_of_friends.name})
    end

    it "also works with outgoing method instead of < operator" do
      Proc.new do
        joe=node(3)
        friends_of_friends = joe.outgoing(:knows).outgoing(:knows)
        r = rel?('knows').as(:r)
        joe > r > friends_of_friends
        r.exist?
        ret(friends_of_friends[:name], count).desc(count).asc(friends_of_friends[:name])
      end.should be_cypher(%{START n0=node(3) MATCH (n0)-[:`knows`]->(v0),(v0)-[:`knows`]->(v1),(n0)-[r?:knows]->(v1) WHERE (r is null) RETURN v1.name,count(*) ORDER BY count(*) DESC, v1.name})
    end

  end


  describe "using model classes and declared relationship" do
    it "escape relationships name and allows is_a? instead of [:_classname] = klass" do
        class User
          def self._load_wrapper; end

          def self.rc
            :"User#rc"
          end
        end

        class Place
          def self._load_wrapper; end

          def self.rs
            :"Place#rs"
          end
        end

        class RC
          def self._load_wrapper; end

          include Neo4j::Core::Wrapper
        end

      Proc.new do
        u = node(2)
        p = node(3)
        rc = node(:rc)
        u > rel(User.rc) > rc < rel(Place.rs) < p
        rc < rel(:active) < node
        rc.is_a?(RC)
        rc
      end.should be_cypher(%{START n0=node(2),n1=node(3) MATCH (n0)-[:`User#rc`]->(rc)<-[:`Place#rs`]-(n1),(rc)<-[:`active`]-(v4) WHERE rc._classname = "RC" RETURN rc})
    end
  end

  describe "a=node(5);b=node(7);x=node; a > ':friends' > x; (x > ':friends' > node > ':work' > b).not; x" do
    it do
      Proc.new do
        a=node(5);b=node(7);x=node; a > ':friends' > x; (x > ':friends' > node > ':work' > b).not; x
      end.should be_cypher("START n0=node(5),n1=node(7) MATCH (n0)-[:friends]->(v0) WHERE not((v0)-[:friends]->(v1)-[:work]->(n1)) RETURN v0")
    end
  end

  describe "node(1) << node(:person).where{|p| p >> node(7).as(:interest)}; :person" do
    it do
      Proc.new do
        node(1) << node(:person).where{|p| p >> node(7).as(:interest)}; :person
      end.should be_cypher("START n0=node(1),interest=node(7) MATCH (n0)<--(person) WHERE ((person)-->(interest)) RETURN person")
    end
  end

  describe "node(1) << node(:person).where_not{|p| p >> node(7).as(:interest)}; :person" do
    it do
      Proc.new do
        node(1) << node(:person).where_not{|p| p >> node(7).as(:interest)}; :person
      end.should be_cypher("START n0=node(1),interest=node(7) MATCH (n0)<--(person) WHERE not((person)-->(interest)) RETURN person")
    end
  end


  describe "5.4. Find people based on similar favorites" do
    it do
      Proc.new do
        node(42).where_not { |m| m - ':friend' - :person } > ':favorite' > :stuff < ':favorite' < :person
        ret(node(:person)[:name], count(:stuff).desc(count(:stuff)))
      end.should be_cypher(%Q[START n0=node(42) MATCH (n0)-[:favorite]->(stuff)<-[:favorite]-(person) WHERE not((n0)-[:friend]-(person)) RETURN person.name,count(stuff) ORDER BY count(stuff) DESC])
    end
  end



  describe "(node(5) > :r > :middle) >> node(7)" do
    it do
      Proc.new do
        (node(5) > :r > :middle) >> node(7)
      end.should be_cypher("START n0=node(5),n2=node(7) MATCH m3 = (n0)-[r]->(middle)-->(n2) RETURN m3")
    end
  end


  describe "node(1) > (r=rel(:friends)) > :other; r[:since] == 1994; :other" do
    it do
      Proc.new do
        node(1) > (r=rel(:friends)) > :other; r[:since] == 1994; :other
      end.should be_cypher("START n0=node(1) MATCH (n0)-[v1:`friends`]->(other) WHERE v1.since = 1994 RETURN other")
    end
  end

  describe "node(1) > (rel(:knows)[:since] == 1994) > :other; :other" do
    it do
      Proc.new do
        node(1) > (rel(:knows)[:since] == 1994) > :other; :other
      end.should be_cypher("START n0=node(1) MATCH (n0)-[v1:`knows`]->(other) WHERE v1.since = 1994 RETURN other")
    end
  end

  describe "node(1) > (rel(:knows)[:since] > 1994) > (node(:other)[:name] == 'foo'); :other"do
    it do
      Proc.new do
        node(1) > (rel(:knows)[:since] > 1994) > (node(:other)[:name] == 'foo'); :other
      end.should be_cypher(%Q[START n0=node(1) MATCH (n0)-[v1:`knows`]->(other) WHERE v1.since > 1994 and other.name = "foo" RETURN other])
    end
  end

  describe "node.new" do
    it do
      Proc.new do
        node.new
      end.should be_cypher(%Q[ CREATE (v0)])
    end
  end

  describe "node.new(:name => 'Andres', :age => 42)" do
    it do
      Proc.new do
        node.new(:name => 'Andres', :age => 42)
      end.should be_cypher(%Q[ CREATE (v0 {name : 'Andres', age : 42})])
    end
  end

  describe "node.new(:name => 'Andres').as(:a); :a" do
    it do
      Proc.new do
        node.new(:name => 'Andres').as(:a)
        :a
      end.should be_cypher(%Q[ CREATE (a {name : 'Andres'}) RETURN a])
    end
  end

  describe "node.new(:_name => 'Andres').as(:a); :a" do
    it do
      Proc.new do
        node.new(:_name => 'Andres').as(:a) # Notice, no "" around the string !
        :a
      end.should be_cypher(%Q[ CREATE (a {name : Andres}) RETURN a])
    end
  end


  describe "a = node(1).as(:a); b = node(2).as(:b); create_path{a > rel(:friends, :_name => \"a.name + '<->' + b.name\").as(:r) > b} :r" do
    it do
      Proc.new do
        a = node(1).as(:a)
        b = node(2).as(:b)
        create_path{a > rel(:friends, :_name => "a.name + '<->' + b.name").as(:r) > b}
        :r
      end.should be_cypher(%Q[START a=node(1),b=node(2) CREATE p0 = (a)-[r:`friends` {name : a.name + '<->' + b.name}]->(b) RETURN r])
    end
  end


  describe "create_path{node.new(:name => 'Andres') > rel(:WORKS_AT) > node < rel(:WORKS_AT) < node.new(:name => 'Micahel')}" do
    it do
      Proc.new do
        create_path{node.new(:name => 'Andres') > rel(:WORKS_AT) > node < rel(:WORKS_AT) < node.new(:name => 'Micahel')}
      end.should be_cypher(%Q[ CREATE p0 = (v0 {name : 'Andres'})-[:`WORKS_AT`]->(v2)<-[:`WORKS_AT`]-(v4 {name : 'Micahel'}) RETURN p0])
    end

    ""
  end
#
#
#
#  describe "david = node(1); david <=> node(:other_person) >> node}; with(:other_person, count){|_, foaf| foaf > 1} :other_person " do
#           "START david=node(1) MATCH david--otherPerson-->() WITH otherPerson, count(*) as foaf WHERE foaf > 1 RETURN otherPerson"
#  end
#
#  describe "" do
#    it do
#      Proc.new do
#        n = node(1); n > rel(:knows) > :other; create_path(:other){|other| other > rel(:works) > node }
#      end
#      "START n=node(1) MATCH n-[:KNOWS]-other WITH other CREATE n-[:WORKS]->other"
#    end
#  end
#
#  describe "a = node(2); other = node; a > rel(:knows) > other; with(other, other.counter){|other, c| c == 1}; with(other){|other| other > rel(:works) > :work}; :work " do
#
#    "START a=node(2) MATCH a-[:KNOWS]-other WITH other, other.counter as c WHERE c = 1 WITH other MATCH other-[:WORKS]->work RETURN work"
#  end
#
#
#  "START n=node(127) MATCH(n)-[:friends]->(x) WITH n, collect(distinct x) as friends MATCH(n)-[:outer_only_friends]->(y) WITH n, collect(distinct y) as outer, friends RETURN collect(friends + outer) as stuff"
#
#
#  "START a=node(2) MATCH a-[:KNOWS]-other CREATE other-[:WORKS]->n"
#
#  "START a=node(2) MATCH a-[:KNOWS]-other--() with other, count(*) as c SET other.counter = c"
#
#  describe "root = node(0); curr_user = node(1); company = Node.new(:name => 'Google'); create_path{ root > rel(:has_company) > company; curr_user > rel(:has_company, :created_at => '2012') > company}" do
#    "START root = node(0), currentUser = node(1)
#CREATE
#    company = { name: 'Google', url: 'www.google.com' },
#    root-[rc:HAS_COMPANY]->company,
#    currentUser-[uc:HAS_COMPANY { createdAt: '2012-04-24T16:14:34.648Z' } ]->company
#RETURN
#    company.name, uc.createdAt;"
#  end
#
#  describe "left=node(1), right=node(3,4); create_unique{left > rel(:knows).as(:r) > right}; :r" do
#            "START left=node(1), right=node(3,4) CREATE UNIQUE left-[r:KNOWS]->right RETURN r"
#  end
#
#
#  describe "n = node(2); n.surname = 'Taylor'; ret n" do
#    "START n = node(2) SET n.surname = 'Taylor' RETURN n"
#  end
#
#  describe "node(4).del" do
#    "START n = node(4) DELETE n"
#  end
#
#  describe "n = node(3); n > r=rel > node; delete(n,r)" do
#    "START n = node(3) MATCH n-[r]-() DELETE n, r"
#  end
#
#  describe "andres = node(3); delete(andres.age); andres" do
#    "START andres = node(3) DELETE andres.age RETURN andres"
#  end
#
#  describe "begin = node(2); end = node(1); p = begin > rel > end; p.nodes.foreach { |x| x.marked = true }" do
#    "START begin = node(2), end = node(1) MATCH p = begin -[*]-> end foreach(n in nodes(p) : SET n.marked = true)"
#  end
#
  # Cypher > 1.7.0 (snapshot)
  # start begin = node(2), end = node(1) match p = begin -[*]-> end with p foreach(r in relationships(p) : delete r) with p foreach(n in nodes(p) : delete n)
  # start a=node(0), b=node(5) with a,b create rel a-[:friends]->b

  if RUBY_VERSION > "1.9.0"

    describe "a=node(5);b=node(7);x=node; a > ':friends' > x; !(x > ':friends' > node > ':work' > b); x" do
      it do
        Proc.new do
          a=node(5);b=node(7);x=node; a > ':friends' > x; !(x > ':friends' > node > ':work' > b); x
        end.should be_cypher("START n0=node(5),n1=node(7) MATCH (n0)-[:friends]->(v0) WHERE not((v0)-[:friends]->(v1)-[:work]->(n1)) RETURN v0")
      end
    end

    # the ! operator is only available in Ruby 1.9.x
    describe %{n=node(3).as(:n); where(!(n[:desc] =~ ".\d+")); ret n} do
      it { Proc.new { n=node(3).as(:n); where(!(n[:desc] =~ ".\d+")); ret n }.should be_cypher(%q[START n=node(3) WHERE not(n.desc =~ /.d+/) RETURN n]) }
    end

    describe %{n=node(3).as(:n); where((n[:desc] != "hej")); ret n} do
      it { Proc.new { n=node(3).as(:n); where((n[:desc] != "hej")); ret n }.should be_cypher(%q[START n=node(3) WHERE n.desc != "hej" RETURN n]) }
    end

    describe %{a=node(1).as(:a);b=node(3,2); r=rel('r?'); a < r < b; !r.exist? ; b} do
      it { Proc.new { a=node(1).as(:a); b=node(3, 2); r=rel('r?'); a < r < b; !r.exist?; b }.should be_cypher(%{START a=node(1),n1=node(3,2) MATCH (a)<-[r?]-(n1) WHERE not(r is null) RETURN n1}) }
    end

  end

end
