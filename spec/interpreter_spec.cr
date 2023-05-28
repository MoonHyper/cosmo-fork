require "./spec_helper"

# this still sucks
def shutup(&block : ->)
  out, err, in = Stdio.capture do |io|
    STDOUT.puts ":)"
    STDERR.puts ":("
    io.in.puts ":P"
    block.call
    [io.out.gets, io.err.gets, STDIN.gets]
  end
end

def shutup_run(interpreter : Interpreter, path : String) : Nil
  source = File.read(path)
  shutup do
    interpreter.interpret(source, "test:#{path}")
  end
end

def run_dir(interpreter : Interpreter, path : String) : Nil
  if File.basename(path).downcase.starts_with?("main.")
    shutup_run(interpreter, path)
  end
end

describe Interpreter do
  interpreter = Interpreter.new(output_ast: false, run_benchmarks: false, debug_mode: true)
  describe "interprets intrinsics:" do
    it "global" do
      result = interpreter.interpret("version$", "test")
      result.should eq "Cosmo #{Version}".strip

      result = interpreter.interpret("puts", "test")
      result.should be_a Callable
      result.should be_a IntrinsicFunction
    end
    it "math/number library" do
      interpreter.interpret("use \"math\"", "test")
      result = interpreter.interpret("Math->π", "test")
      result.as(Float64).should be_close 3.141, 0.001
      result = interpreter.interpret("Math->e", "test")
      result.as(Float64).should be_close 2.718, 0.001
      result = interpreter.interpret("1.2345->round(2)", "test")
      result.should eq 1.23
      result = interpreter.interpret("1.75->floor", "test")
      result.should eq 1
      result = interpreter.interpret("1.1->ceil", "test")
      result.should eq 2
      result = interpreter.interpret("Math::max(3, 6, 4, 3, 9, 12, 2)", "test")
      result.should eq 12
      result = interpreter.interpret("Math::min(7, 6, 4, 1, 9, 14, 5)", "test")
      result.should eq 1
      result = interpreter.interpret("Math::log(5)", "test")
      result.as(Float64).should be_close 1.6094, 0.0001
      result = interpreter.interpret("Math::log10(16)", "test")
      result.as(Float64).should be_close 1.2041, 0.0001
      result = interpreter.interpret("Math::log2(40)", "test")
      result.as(Float64).should be_close 5.3219, 0.0001
    end
    it "string library" do
      result = interpreter.interpret("\"    \".blank?", "test")
      result.should be_true
      result = interpreter.interpret("\"baba\".chars", "test")
      result.should eq ['b','a','b','a']
      result = interpreter.interpret("\"baba.booey.god\".split('.')", "test")
      result.should eq ["baba", "booey", "god"]
    end
    it "vector library" do
      result = interpreter.interpret("[1,2,3].map(&int (int n): n * 2)", "test")
      result.should eq [2,4,6]
      result = interpreter.interpret("int[] ABABABA = [15, 2]", "test")
      result.should eq [15, 2]
      result = interpreter.interpret("ABABABA->first", "test")
      result.should eq 15
      result = interpreter.interpret("ABABABA->last", "test")
      result.should eq 2
      result = interpreter.interpret("[]->first? is void", "test")
      result.should eq true
      result = interpreter.interpret("['a', 'b', 'c'].join(',')", "test")
      result.should eq "a,b,c"
      result = interpreter.interpret("[].push(1,2,3,4,5)", "test")
      result.should eq [1,2,3,4,5]
    end
  end
  describe "interprets literals:" do
    it "booleans" do
      result = interpreter.interpret("false", "test")
      result.should be_false
      result = interpreter.interpret("true", "test")
      result.should be_true
    end
    it "none" do
      result = interpreter.interpret("none", "test")
      result.should be_nil
    end
    it "numerics" do
      result = interpreter.interpret("123", "test")
      result.should eq 123
      result = interpreter.interpret("0b111", "test")
      result.should eq 7
      result = interpreter.interpret("0xabc", "test")
      result.should eq 2748
      result = interpreter.interpret("0o321", "test")
      result.should eq 209
      result = interpreter.interpret("13582385623792389735", "test")
      result.should eq 13582385623792389735_i128
    end
    it "strings/chars" do
      result = interpreter.interpret("\"hello\"", "test")
      result.should eq "hello"
      result = interpreter.interpret("'e'", "test")
      result.should eq 'e'
    end
    it "strings interpolation" do
      interpreter.interpret("string name = \"johnny\"", "test")
      interpreter.interpret("int age = 5", "test")
      result = interpreter.interpret("\"hello %{name}, you are %{age} years old.\"", "test")
      result.should eq "hello johnny, you are 5 years old."
    end
    it "vectors" do
      result = interpreter.interpret("[1, 2, 3]", "test")
      result.should eq [1, 2, 3]
      result = interpreter.interpret("[[1,2,3], [4,5,6], ['a', 'b', 'c']]", "test")
      result.should eq [[1,2,3], [4,5,6], ['a', 'b', 'c']]
    end
    it "tables" do
      result = interpreter.interpret("{{yes -> true, [123] -> false}}", "test")
      result.should eq ({"yes" => true, 123 => false})
    end
    it "ranges" do
      result = interpreter.interpret("Range my_range = 5..20", "test")
      result.should eq 5..20
      result = interpreter.interpret("Range my_neg_range = -20..-5", "test")
      result.should eq -20..-5
    end
    it "lambdas" do
      interpreter.interpret("func even = &bool (int n): n % 2 == 0", "test")
      result = interpreter.interpret("even(6)", "test")
      result.should be_true
      result = interpreter.interpret("even(3)", "test")
      result.should be_false
      interpreter.interpret("func double = &int (int n): n * 2", "test")
      result = interpreter.interpret("double(6)", "test")
      result.should eq 12
      result = interpreter.interpret("double(15)", "test")
      result.should eq 30
    end
  end
  it "interprets unary operators" do
    result = interpreter.interpret("!false", "test")
    result.should be_true
    result = interpreter.interpret("!true", "test")
    result.should be_false
    result = interpreter.interpret("!!123", "test")
    result.should be_true
    result = interpreter.interpret("-0xabc", "test")
    result.should eq -2748
    result = interpreter.interpret("+-10.24335", "test")
    result.should eq 10.24335
    result = interpreter.interpret("#[1,2,3]", "test")
    result.should eq 3
    result = interpreter.interpret("\#{{yes->true, no->false}}", "test")
    result.should eq 2
    result = interpreter.interpret("~15", "test")
    result.should eq -16
  end
  it "interprets binary operators" do
    result = interpreter.interpret("3 * 6 / 2 - 9", "test")
    result.should eq 0
    result = interpreter.interpret("9 ^ 2 / 14 + 6 * 2", "test")
    result.should eq 17.785714285714285
    result = interpreter.interpret("(14 - 3.253 / 14.5) * 27 ^ 4", "test")
    result.should eq 7320947.960482759
    result = interpreter.interpret("true == false", "test")
    result.should eq false
    result = interpreter.interpret("true == false == false != true", "test")
    result.should eq false
    result = interpreter.interpret("0xff & 24 | 15", "test")
    result.should eq 31
    result = interpreter.interpret("~15 >> 12 << 14", "test")
    result.should eq -16384
    result = interpreter.interpret("482 // 23", "test")
    result.should eq 20
  end
  it "interprets ternary operators" do
    result = interpreter.interpret("true ? (true ? \"yes\" : \"wtf\") : \"wtf x2\"", "test")
    result.should eq "yes"
    result = interpreter.interpret("false ? \"yes\" :\"no\"", "test")
    result.should eq "no"
  end
  it "interprets variable declarations" do
    result = interpreter.interpret("int x = 0b11 - 0b11011", "test")
    result.should eq -24

    result = interpreter.interpret("bigint boba = 13582385623792389735", "test")
    result.should eq 13582385623792389735_i128

    result = interpreter.interpret("uint ijija = 1500", "test")
    result.should eq 1500
    expect_raises(Exception, "@test [1:6] Type mismatch: Expected 'uint', got 'int'") do
      interpreter.interpret("ijija = -1", "test")
    end

    result = interpreter.interpret("char y = 'h'", "test")
    result.should eq 'h'

    result = interpreter.interpret("string z = \"hello world\"", "test")
    result.should eq "hello world"

    result = interpreter.interpret("bool abc = false", "test")
    result.should eq false

    result = interpreter.interpret("const (string|int) g = 123", "test")
    result.should eq 123

    interpreter.interpret("const int foo = 10", "test")
    expect_raises(Exception, "@test [1:4] Attempt to assign to constant variable: foo") do
      interpreter.interpret("foo = 15", "test")
    end

    result = interpreter.interpret("char[] word = ['h', 'e', 'l', 'l', 'o']", "test")
    result.should be_a Array(ValueType)
    result.as(Array(ValueType)).join.should eq "hello"

    result = interpreter.interpret("int[][] matrix = [[1,2,3], [4,5,6]]", "test")
    result.should be_a Array(ValueType)
    matrix = result.as Array(ValueType)
    matrix[0].should be_a Array(ValueType)
    matrix[1].should be_a Array(ValueType)

    sum = 0
    matrix[0].as(Array(ValueType)).each { |v| sum += v.as Int }
    matrix[1].as(Array(ValueType)).each { |v| sum += v.as Int }
    sum.should eq 21

    result = interpreter.interpret("(string|int)->bool valids = {{yes -> true, [123] -> false}}", "test")
    result.should eq ({"yes" => true, 123 => false})

    result = interpreter.interpret("Range my_range = 1..16", "test")
    result.should eq 1..16
  end
  it "interprets variable assignments" do
    interpreter.interpret("int x = 0b11", "test")
    result = interpreter.interpret("x = 5", "test")
    result.should eq 5
    result = interpreter.interpret("x = 12", "test")
    result.should eq 12
    result = interpreter.interpret("++x", "test")
    result.should eq 13
    result = interpreter.interpret("++x", "test")
    result.should eq 14
    result = interpreter.interpret("--x", "test")
    result.should eq 13
    result = interpreter.interpret("--x", "test")
    result.should eq 12
  end
  it "interprets compound assignment" do
    result = interpreter.interpret("int a = 5", "test")
    result.should eq 5
    result = interpreter.interpret("a += 2", "test")
    result.should eq 7
    result = interpreter.interpret("a -= 17", "test")
    result.should eq -10
    result = interpreter.interpret("a *= 4", "test")
    result.should eq -40
    result = interpreter.interpret("int[] bbb = [2,4]", "test")
    result.should eq [2, 4]
    result = interpreter.interpret("bbb << 6", "test")
    result.should eq [2, 4, 6]
    result = interpreter.interpret("++bbb[0]", "test")
    result.should eq [3, 4, 6]
    result = interpreter.interpret("bbb[1] *= 3", "test")
    result.should eq [3, 12, 6]
    result = interpreter.interpret("bbb[2] ^= 2", "test")
    result.should eq [3, 12, 36]
  end
  it "interprets property assignments" do
    interpreter.interpret("int[] nums = [1,2]", "test")
    interpreter.interpret("nums[2] = 3", "test")
    result = interpreter.interpret("nums[2]", "test")
    result.should eq 3
    interpreter.interpret("nums << 4", "test")
    result = interpreter.interpret("nums", "test")
    result.should eq [1,2,3,4]
    expect_raises(Exception, "[1:5] Type mismatch: Expected 'int', got 'string'") do
      interpreter.interpret("nums[3] = \"hi\"", "test")
    end

    interpreter.interpret("string->bool admins = {{runic -> true}}", "test")
    interpreter.interpret("admins->shedletsky = true", "test")
    result = interpreter.interpret("admins->runic", "test")
    result.should eq true
    result = interpreter.interpret("admins->shedletsky", "test")
    result.should eq true
    expect_raises(Exception, "@test [1:14] Invalid table key: 'bobert'") do
      interpreter.interpret("admins->bobert", "test")
    end
  end
  it "interprets function definitions" do
    result = interpreter.interpret("bool fn is_eq(const int a = 5, const int b) { return a == b }", "test")
    result.should be_a Callable
    result.should be_a Function

    result = interpreter.interpret("(float|int) fn half_sum(const int a, const int b) { (a + b) / 2 }", "test")
    result.should be_a Callable
    result.should be_a Function

    result = interpreter.interpret("(bool|void) fn balls? { none }", "test")
    result.should be_a Callable
    result.should be_a Function
  end
  it "interprets function calls" do
    result = interpreter.interpret("is_eq == none", "test")
    result.should be_false
    result = interpreter.interpret("is_eq(1, 1)", "test")
    result.should be_true
    result = interpreter.interpret("is_eq(none, 5)", "test")
    result.should be_true
    result = interpreter.interpret("is_eq(1, 2)", "test")
    result.should be_false

    result = interpreter.interpret("half_sum(9, 7) + 2", "test")
    result.should eq 10
  end
  it "interprets string concatenation" do
    interpreter.interpret("string msg = \"\"", "test")
    interpreter.interpret("msg += \"hello\"", "test")
    result = interpreter.interpret("msg + \" world\"", "test")
    result.should eq "hello world"
  end
  describe "interprets indexing" do
    it "strings" do
      interpreter.interpret("string word = \"hey\"", "test")
      result = interpreter.interpret("word[0]", "test")
      result.should eq 'h'
      result = interpreter.interpret("word[1]", "test")
      result.should eq 'e'
      result = interpreter.interpret("word[2]", "test")
      result.should eq 'y'
    end
    it "vectors" do
      interpreter.interpret("int[] x = [1, 2]", "test")
      result = interpreter.interpret("x[0]", "test")
      result.should eq 1
      result = interpreter.interpret("x[1]", "test")
      result.should eq 2
      interpreter.interpret("int[][] m = [[1, 2], [3, 4]]", "test")
      result = interpreter.interpret("m[0]", "test")
      result.should eq [1, 2]
      result = interpreter.interpret("m[0][1]", "test")
      result.should eq 2
      result = interpreter.interpret("m[1][0]", "test")
      result.should eq 3
    end
    it "tables" do
      interpreter.interpret("string->bool bad_people = {{[\"billy bob\"] -> false, mj -> true, joemar -> false}}", "test")
      result = interpreter.interpret("bad_people[\"billy bob\"]", "test")
      result.should eq false
      result = interpreter.interpret("bad_people.mj", "test")
      result.should eq true
      result = interpreter.interpret("bad_people::mj", "test")
      result.should eq true
      result = interpreter.interpret("bad_people->joemar", "test")
      result.should eq false
    end
  end
  it "interprets if/unless statements" do
    lines = [
      "int x = 5",
      "int doubled",
      "if x == 5",
      "  doubled = x * 2",
      "else",
      "  doubled = x",
      "",
      "doubled"
    ]

    result = interpreter.interpret(lines.join('\n'), "test")
    result.should eq 10

    lines = [
      "int x = 5",
      "int doubled",
      "unless x == 5",
      "  doubled = x * 2",
      "else",
      "  doubled = x",
      "",
      "doubled"
    ]

    result = interpreter.interpret(lines.join('\n'), "test")
    result.should eq 5
  end
  it "interprets while/until statements" do
    lines = [
      "int x = 0",
      "while x < 10",
      "  x += 1",
      "",
      "x"
    ]

    result = interpreter.interpret(lines.join('\n'), "test")
    result.should eq 10

    lines = [
      "int x = 0",
      "until x == 15",
      "  ++x",
      "x"
    ]

    result = interpreter.interpret(lines.join('\n'), "test")
    result.should eq 15
  end
  it "interprets every statements" do
    lines = [
      "int[] nums = [1,2,3]",
      "int sum = 0",
      "every int n in nums",
      "  sum += n",
      "",
      "sum"
    ]

    result = interpreter.interpret(lines.join('\n'), "test")
    result.should eq 6
  end
  it "interprets case..when statements" do
    lines = [
      "string fn does_their_life_suck?(string name) {",
      "  case name {",
      "    when \"billy\" => \"oh yeah\"",
      "    when \"jimbob\" => \"most definitely\"",
      "    else => \"maybe\"",
      "  }",
      "}",
    ]

    interpreter.interpret(lines.join('\n'), "test")
    result = interpreter.interpret("does_their_life_suck?(\"billy\")", "test")
    result.should eq "oh yeah"
    result = interpreter.interpret("does_their_life_suck?(\"jimbob\")", "test")
    result.should eq "most definitely"
    result = interpreter.interpret("does_their_life_suck?(\"beezelbub\")", "test")
    result.should eq "maybe"
  end
  it "interprets class definitions & accessing" do
    lines = [
      "class A {",
      "  public const int x = 1",
      "  const int y = 10",
      "}",
      "A a = new A",
      "a->x"
    ]

    result = interpreter.interpret(lines.join('\n'), "test")
    result.should eq 1

    expect_raises(Exception, "@test [1:4] Attempt to access private field: y") do
      interpreter.interpret("a->y", "test")
    end
    expect_raises(Exception, "@test [1:2] Attempt to assign to constant property: x") do
      interpreter.interpret("a->x = 2", "test")
    end
  end
  describe "types:" do
    it "'is' matching" do
      result = interpreter.interpret("1 is int", "test")
      result.should eq true
      result = interpreter.interpret("873584728475872334 is bigint", "test")
      result.should eq true
      result = interpreter.interpret("1 is (int|float)?", "test")
      result.should eq true
      result = interpreter.interpret("'h' is char", "test")
      result.should eq true
      result = interpreter.interpret("'h' is void", "test")
      result.should eq false
      result = interpreter.interpret("none is void", "test")
      result.should eq true
      result = interpreter.interpret("[1,2,3] is int[]", "test")
      result.should eq true
      result = interpreter.interpret("{{yes->true}} is string->bool", "test")
      result.should eq true
    end
    it "casting" do
      result = interpreter.interpret("<string>123", "test")
      result.should eq "123"
      result = interpreter.interpret("<bool>0", "test")
      result.should eq false
      result = interpreter.interpret("<bool>1", "test")
      result.should eq true
      result = interpreter.interpret("<char>\"a\"", "test")
      result.should eq 'a'
      result = interpreter.interpret("<int>false", "test")
      result.should eq 0
      result = interpreter.interpret("<int>1.23", "test")
      result.should eq 1
      result = interpreter.interpret("<float>10", "test")
      result.should eq 10.0
    end
    it "aliases" do
      result = interpreter.interpret("type MyInt = int; MyInt my_int = 123", "test")
      result.should eq 123
      result = interpreter.interpret("type Number = bigint | int | float; 1.23 is Number &: 15 is Number", "test")
      result.should eq true
    end
    it "throws when a mismatch occurs" do
      interpreter.interpret("int x = 1", "test")
      expect_raises(Exception, "[1:2] Type mismatch: Expected 'int', got 'float'") do
        interpreter.interpret("x = 2.0", "test")
      end
      expect_raises(Exception, "[1:3] Invalid '+' operand type: Char") do
        interpreter.interpret("x + 'h'", "test")
      end
      expect_raises(Exception, "[1:6] Type mismatch: Expected 'float', got 'int'") do
        interpreter.interpret("float[] aba = [x, 2.0]", "test")
      end
    end
  end
  describe "interprets examples:" do
    example_files = Dir.entries "examples/"
    example_files.each do |example_file|
      next if example_file.starts_with?(".")
      next if example_file.starts_with?("with_main")
      it example_file do
        interpreter = Interpreter.new(output_ast: false, run_benchmarks: false, debug_mode: true)
        path = File.join "examples", example_file
        if File.directory?(path)
          run_dir(interpreter, path)
        else
          shutup_run(interpreter, path)
        end
      end
    end
  end
end
