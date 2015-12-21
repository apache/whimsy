#
# drop part of drag and drop
#

month, hash = @message.match(%r{/(\d+)/(\w+)}).captures

mbox = Mailbox.new(month)
message = mbox.find(hash)
source = message.find(@source)
target = message.find(@target)

STDERR.puts source.inspect
STDERR.puts target.inspect
FileUtils.mkdir_p "work/#@message"


{success: true}
