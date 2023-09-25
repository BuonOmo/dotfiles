# map while forking, not suitable for production.
module EnumFork
  def fork_map(forks = nil)
    raise "no block given" unless block_given?

    if forks && size
      # q = SizedQueue.new(forks - 1)
      # Thread.fork { each { |*a, **kw| q.push(a, kw) } }
      # (forks - 1).times { }
      each_slice((size.to_f / forks).ceil).map do |slice|
        Thread.fork { slice.map { |*a, **kw| yield(*a, **kw) } }
      end.map(&:join).flat_map(&:value)
    else
      map do |*a, **kw|
        Thread.fork { yield(*a, **kw) }
      end.map(&:join).map(&:value)
    end
  end
end
Array.include EnumFork
Enumerable.include EnumFork

module Debug
  module_function

  def say(*args, **kwargs)
    puts ?v * 120
    puts Internal.caller_loc
    pp(*args, **kwargs)
    puts ?^ * 120
    puts
  end

  def here
    caller_locations(1, 1).first
  end

  # @param filter (see #match_method?)
  # @example
  #   trace(:require, kinds: :call) do |tp|
  #     path = tp.binding.eval('path')
  #     next unless path["rdoc"]
  #     puts "#{path} at #{caller_locations(3, 1).first}"
  #   end

  def trace(filter, kinds: %i(call c_call))
    kinds = Array(kinds)
    puts Internal.caller_loc + " Started tracing"
    TracePoint.trace(*kinds) do |tp|
      unless (kinds & %i(call c_call)).empty?
        next unless Internal.match_method?(tp.method_id, filter)
      end
      # puts "#{tp.path}:#{tp.lineno}"
      next yield tp if block_given?

      begin
        $tp = tp
        tp.binding.irb
      ensure
        $tp = nil
      end
    end
  end


  def confirm?(question, default: "n")
    require "io/console"
    puts question.strip + " [yN]"
    STDIN.getch == "y"
  end


  module Internal
  end
  class << Internal
    def match_method?(method_id, matcher)
      case matcher
      when nil then true
      when Regexp then method_id.match?(matcher)
      when Symbol then method_id == matcher
      else
        method_id.include?(matcher.to_s)
      end
    end

    # Useful to remove the added trace
    def caller_loc
      l = caller_locations(2, 1).first
      "#{l.absolute_path}:#{l.lineno}"
    end
  end
end

class String
  def inspect_all
    visible_range = (" ".ord)..("~".ord)
    ?" + bytes.map do |byte|
      case byte
      when visible_range then byte.chr
      else
        "\\x" + byte.to_s(16).upcase
      end
    end.join("") + ?"
  end
end

module MethodExt
  def sl
    source_location * ":"
  end

  def goto
    editor = ENV.fetch("EDITOR", "zed")
    case editor
    when "zed" then system("zed", sl)
    when "code" then system("code", "-g", sl)
    else
      system(editor, sl)
    end
  end
end
Method.prepend MethodExt
UnboundMethod.prepend MethodExt

class Module
  def csl(...)
    const_source_location(...) * ":"
  end

  def const_goto(...)
    editor = ENV.fetch("EDITOR", "zed")
    case editor
    when "zed" then system("zed", csl(...))
    when "code" then system("code", "-g", csl(...))
    else
      system(editor, csl(...))
    end
  end
end

module ObjectExt
  # Allow looking in a range of ancestors.
  def methods(regular=true)
    return super unless regular.is_a?(Numeric)

    super(true) - self.class.ancestors[regular..].flat_map(&:instance_methods)
  end
end

Object.prepend(ObjectExt)

def dbg
  Kernel.include Debug
  include Debug
end
