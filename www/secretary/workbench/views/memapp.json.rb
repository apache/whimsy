# parse and return the contents of the latest memapp-received file

# find latest memapp-received.txt file in the foundation/Meetings directory
meetings = ASF::SVN['Meetings']
received = Dir["#{meetings}/2*/memapp-received.txt"].max

# extract contents
pattern = /^\w+\s+(\w+)\s+(\w+)\s+(\w+)\s+(\w+)\s+(.*?)\s*\n/
if Date.today - Date.parse(received[/\d{8}/]) <= 32
  table = File.read(received).scan(pattern)
else
  table = []
end

# map contents to a hash
fields = %w(apply mail karma id name)
{received: table.map {|results| fields.zip(results).to_h}.sort_by {|k| k['name']}}
