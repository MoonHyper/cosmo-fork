require "./cosmo/logger"
require "./util"
require "./cosmo/runtime/interpreter"
require "optparse/time"

module Cosmo
  extend self

  @@options = {}
  OptionParser.new do |opts|
    opts.banner = "Thank you for using Cosmo!\nUsage: cosmo [OPTIONS] [FILE]"
    opts.on("-a", "--ast", "Outputs the AST") { @@options[:ast] = true }
    opts.on("-B", "--benchmark", "Outputs the execution time of the lexer, parser, resolver, and interpreter") { @@options[:benchmark] = true }
    opts.on("-e", "--error-trace", "Toggles full error message mode (shows Cosmo source code backtraces)") { Logger.debug = true }
    opts.on("-h", "--help", "Outputs help menu for Cosmo CLI") { puts opts; exit }
    opts.on("-v", "--version", "Outputs the current version of Cosmo") { puts "Cosmo #{Version}"; exit }
  end.parse!

  @@interpreter = Interpreter.new(output_ast: @@options.has_key?(:ast), run_benchmarks: @@options.has_key?(:benchmark))

  def read_source(source: String, file_path: String): ValueType
    begin
      @@interpreter.interpret(source, file_path)
    rescue ex: Exception
      bug = !Logger.debug?
      msg = "#{bug ? 'BUG: ' : ''}#{ex.inspect_with_backtrace}"
      msg += "\nYou've found a bug! Please open an issue, including source code so we can reproduce the bug: https://github.com/cosmo-lang/cosmo/issues" if bug
      abort msg, 1
    end
  end

  def read_file(path: String)
    begin
      contents = File.binread(path)
      read_source(contents, file_path: path)
    rescue ex: Exception
      abort "Failed to read file \"#{path}\": \n#{ex.message}\n\t#{ex.backtrace.join("\n\t")}", 1
    end
  end

  def run_repl
    colors = [31, 33, 32, 36, 35]
    color_index = 0
    puts "Welcome to the #{colors.map { |c| "\e[#{c}mCosmo\e[0m"[color_index += 1] }.join()} REPL!"
    loop do
      STDOUT.write(Util::Color.light_green("» ").to_slice)
      line = STDIN.gets
      break if line.nil? || line.chomp.empty?
      result = read_source(line, file_path: "repl")
    end
  end

  def options; @@options; end
end

ARGV.empty? ? Cosmo.run_repl : Cosmo.read_file(path: ARGV.first)
