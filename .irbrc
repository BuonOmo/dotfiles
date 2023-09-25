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
  if object.is_a? Symbol # assume one wanted to type `method`
    method(object)
  end
  irb_methods = object.methods.grep(/\Airb_/).flat_map { [_1, _1.to_s.delete_prefix("irb_").to_sym] }
  object.methods - curation.flat_map do |klass|
    klass.methods + klass.instance_methods
  end - irb_methods
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

require_relative ".ruby/debug.rb"

# trace(:require, kinds: :call) do |tp|
#   path = tp.binding.eval('path')
#   next unless path["rdoc"]
#   puts "#{path} at #{caller_locations(3, 1).first}"
# end

module IrBang
  if IRB::WorkSpace.instance_method(:evaluate).arity == -3
    def evaluate(context, statements, file = __FILE__, line = __LINE__)
      if statements.start_with?(".")
        system statements[1..-1]
      else
        super
      end
    end
  else
    def evaluate(statements, file = __FILE__, line = __LINE__)
      if statements.start_with?(".")
        system statements[1..-1]
      else
        super
      end
    end
  end
end

IRB::WorkSpace.prepend IrBang
