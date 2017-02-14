#
# Extract the Board Summary from the Virtual xlsx spreadsheet and format it as
# plain text
#

require 'base64'
require 'rubyXL'
require 'active_support'
require 'active_support/core_ext/numeric/conversions'

# parse worksheet
# https://github.com/weshatheleopard/rubyXL/issues/235
begin
  stdout, $stdout = $stdout, File.new("/dev/null", "w")
  worksheet = RubyXL::Parser.parse_buffer(Base64.decode64(@spreadsheet))
ensure
  $stdout = stdout
end

# extract data
rows = []
worksheet['Board Summary'].each do |row|
  data = []

  row && row.cells.each do |cell|
    value = cell && cell.value

    # format number values
    if value.is_a? Numeric
      value = ActiveSupport::NumberHelper::number_to_currency(value, unit: '').
        rjust(12)
    end

    data << value
  end

  # strip trailing empty cells
  data.pop while data.length > 0 and data[-1] == nil

  # combine the first four columns into a single column
  if data.length
    heading = data.shift(4)
    data.unshift heading.join('  ').sub(/\s+$/, '').sub(/^ {1,4}/, '').ljust(29)
  end

  rows << data
end

# delete first two rows
rows.shift(2)

# move headings from second to seventh row
headings = rows.delete_at(1)
headings[2] = headings[6] = 'Budget'
1.upto(7) {|i| headings[i] = headings[i].rjust(12) if headings[i]}
rows.insert(6, headings)

# delete empty rows
rows.pop while rows[-1].length == 1 and rows[-1][0].strip == ''

# print out current month totals
output = []
rows.each do |row|
  output << row[0..4].join(' ')
end

# drop current balances
rows.shift(5)

# print out YTD totals
rows.each do |row|
  if row.length >= 7
    output << ([row[0]] + row[5..7]).join(' ')
  else
    output << row[0].strip
  end
end

{table: output.join("\n")}
