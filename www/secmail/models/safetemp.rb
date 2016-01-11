#
# Tempfile in Ruby 2.3.0 has the unfortunate behavior of returning
# an unsafe path and even blowing up when unlink is called in a $SAFE
# environment.  This avoids those two problems, while forwarding all all other
# method calls.
#

require 'tempfile'

class SafeTempFile
  def initialize *args
    args << {} unless args.last.instance_of? Hash
    args.last[:encoding] = Encoding::BINARY
    @tempfile = Tempfile.new *args
  end

  def path
    @tempfile.path.untaint
  end

  def unlink
    File.unlink path
  end

  def method_missing symbol, *args
    @tempfile.send symbol, *args
  end
end
