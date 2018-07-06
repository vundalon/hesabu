module Hesabu
  class Solver
    include TSort

    Equation = Struct.new(:name, :evaluable, :dependencies, :raw_expression)
    EMPTY_DEPENDENCIES = [].freeze
    FakeEvaluable = Struct.new(:eval)

    def initialize
      @parser = ::Hesabu::Parser.new
      @interpreter = ::Hesabu::Interpreter.new
      @equations = {}
      @bindings = {}
    end

    def add(name, raw_expression)
      if raw_expression.nil? || name.nil?
        raise Hesabu::ArgumentError, "name or expression can't be nil : '#{name}', '#{raw_expression}'"
      end

      if ::Hesabu::Types.as_numeric(raw_expression)
        add_numeric(name, raw_expression)
      else
        add_equation(name, raw_expression)
      end
    end

    def solve!
      solving_order.each do |name|
        evaluate_equation(@equations[name])
      end
      solution = @bindings.dup
      @bindings.clear
      to_numerics(solution)
    rescue StandardError => e
      log_and_raise(e)
    end

    def solving_order
      tsort
    rescue TSort::Cyclic => e
      raise Hesabu::CyclicError, "There's a cycle between the variables : " + e.message[25..-1]
    end

    def tsort_each_node(&block)
      @equations.each_key(&block)
    end

    def tsort_each_child(node, &block)
      equation = @equations[node]
      raise UnboundVariableError, unbound_message(node) unless equation
      equation.dependencies.each(&block)
    end

    private

    def to_numerics(solution)
      solution.each_with_object({}) do |kv, hash|
        hash[kv.first] = Hesabu::Types.as_numeric(kv.last) || kv.last
      end
    end

    def log_and_raise(e)
      log_error(e)
      raise e
    end

    def log_error(e)
      log "Error during processing: #{$ERROR_INFO}"
      log "Error : #{e.class} #{e.message}"
      log "Backtrace:\n\t#{e.backtrace.join("\n\t")}"
    end

    def evaluate_equation(equation)
      raise "not evaluable #{equation.evaluable} #{equation}" unless equation.evaluable.respond_to?(:eval, false)
      begin
        @bindings[equation.name] = equation.evaluable.eval
      rescue StandardError => e
        raise CalculationError, "Failed to evaluate #{equation.name} due to #{e.message} in formula #{equation.raw_expression}"
      end
    end

    def log(message)
      puts message
    end

    def add_numeric(name, raw_expression)
      @equations[name] = Equation.new(
        name,
        FakeEvaluable.new(::Hesabu::Types.as_bigdecimal(raw_expression)),
        EMPTY_DEPENDENCIES,
        raw_expression
      )
    end

    def add_equation(name, raw_expression)
      expression = raw_expression.gsub(/\r\n?/, "")
      ast_tree = begin
        @parser.parse(expression)
      rescue Parslet::ParseFailed => e
        log(raw_expression)
        log_error(e)
        raise ParseError, "failed to parse #{name} := #{expression} : #{e.message}"
      end
      var_identifiers = Set.new
      interpretation = @interpreter.apply(
        ast_tree,
        doc:             @bindings,
        var_identifiers: var_identifiers
      )
      if ENV["HESABU_DEBUG"]
        log expression
        log JSON.pretty_generate(ast_tree)
      end
      @equations[name] = Equation.new(name, interpretation, var_identifiers, raw_expression)
    end

    def unbound_message(node)
      ref = first_reference(node)
      "Unbound variable : #{node} used by #{ref.name} (#{ref.raw_expression})"
    end

    def first_reference(variable_name)
      @equations.values.select { |v| v.dependencies.include?(variable_name) }.take(1).first
    end
  end
end
