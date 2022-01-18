require "irb/completion"

IRB.conf[:SAVE_HISTORY] = 100_000
IRB.conf[:AUTO_INDENT] = true
# IRB.conf[:USE_TRACER] = true
# IRB.conf[:MEASURE] = true


# Concept here: show time it took to process previous command unless it is less
#  than a threshold of 0.5 seconds.
if IRB.respond_to?(:set_measure_callback)
  # IRB.set_measure_callback("stackprof", { ignore_gc: true, mode: :cpu, out: "tmp/irb-stackprof-#{Time.now.iso8601}.dump" })
  require "time"
  IRB.set_measure_callback do |context, code, line_no, &block|
    time = Time.now
    result = block.()
    now = Time.now
    diff = (now - time)
    puts 'processing time: %fs' % diff if IRB.conf[:MEASURE] && diff > 0.5
    result
  end
end

# Show instance methods of an object, curated of well known std methods.
def m(object, curation = [Object, Enumerable])
  object.methods - curation.flat_map do |klass|
    klass.methods + klass.instance_methods
  end
end

# Show history.
def history(count = 10)
  count = count > 0 ? count : 1
  puts Reline::HISTORY.to_a[(-count)..-1]
end

# ...
def history_grep(grepper)
  Reline::HISTORY.grep(grepper)
end

# @param receiver [Method|any] If only given a `Method`, the symbol and class
#   are inferred.
def sl(receiver, sym = nil)
  receiver, sym = [receiver.receiver, receiver.name] unless sym
  puts receiver.method(sym).source_location.join(":")
end

# copy data to clipboard (macos)
def pbcopy(str)
  `pbcopy <<BATMAN\n#{str.to_str}\nBATMAN`
end

# Link to geojson.io to quickly display a geojson.
def geojson_io(geojson_h)
  "http://geojson.io/#data=data:application/json," + CGI.escape(Oj.dump geojson_h)
end

# faster that pasting if you don't need history.
def paste
  eval(`pbpaste`)
end

# Remember to use those cool methods from IRB:
# - ls
# - show_source

# Simple breakpoint on methods by renaming $met to the wanted method.
# See {Debug} module for more involved tracing.
$met = :plizdontcallurmetodlikdis
TracePoint.trace(:call) do |tp|
  binding.irb if tp.method_id.to_s == $met
end

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
  def say(*args, **kwargs)
    puts ?v * 120
    puts Internal.caller_loc
    p(*args, **kwargs)
    puts ?^ * 120
    puts
  end

  def here
    caller_locations(1, 1).first
  end

  # @param filter (see #match_method?)
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


Kernel.include Debug
include Debug
# trace(:require, kinds: :call) do |tp|
#   path = tp.binding.eval('path')
#   next unless path["rdoc"]
#   puts "#{path} at #{caller_locations(3, 1).first}"
# end
