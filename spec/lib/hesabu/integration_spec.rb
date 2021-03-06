require "json"
require "ruby-prof"

RSpec.describe "Parsor and interpretor", :slow do
  describe "solve big problems" do
    let(:solver) { Hesabu::Solver.new }
    let(:problem) { JSON.parse(File.read("spec/lib/fixtures/bigproblem.json")) }
    let(:expected_solution) { JSON.parse(File.read("spec/lib/fixtures/bigsolution.json")) }
    let(:timings) { {} }
    it "parse and evaluate" do

      RubyProf.start if ENV["PROF"]

      benchmark("parsing") do
        problem.each do |key, expression|
          solver.add(key, expression)
        end
      end
      solution = benchmark("solving") { solver.solve! }

      result = RubyProf.stop if ENV["PROF"]

      if ENV["PROF"]
        printer = RubyProf::GraphPrinter.new(result)
        printer.print(STDOUT, {})
  
        printer = RubyProf::FlatPrinter.new(result)
        printer.print(STDOUT, {})
      end

      benchmark_log
      float_solution = solution.each_with_object({}) { |kv, hash| hash[kv.first] = kv.last.to_f.round(10) }
      float_expected_solution = expected_solution.each_with_object({}) { |kv, hash| hash[kv.first] = kv.last.to_f.round(10) }

      expect(float_solution).to eq(float_expected_solution)
    end

    # rubocop:disable Rails/TimeZone
    def benchmark(message)
      start = Time.now
      value = nil
      begin
        value = yield
      ensure
        elapsed_time = Time.now - start
        timings[message] = elapsed_time
        puts "#{message} #{elapsed_time} seconds"
      end
      value
    end
    # rubocop:enable Rails/TimeZone

    def benchmark_log
      puts timings.map { |k, timing| [k, timing.to_s, "seconds"].join(" ") }.join(", ")
    end
  end
end
