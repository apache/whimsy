#
# Extract the Board Summary from the Virtual xlsx spreadsheet and format it as
# plain text
#

require 'base64'
require 'rubyXL'
require 'active_support'
require 'active_support/core_ext/numeric/conversions'

# for debugging purposes; read spreadsheet from file if run from command line
@spreadsheet = Base64.encode64(File.read(ARGV.first)) if __FILE__ == $0

# parse worksheet
# https://github.com/weshatheleopard/rubyXL/issues/235
begin
  stdout, $stdout = $stdout, File.new("/dev/null", "w")
  workbook = RubyXL::Parser.parse_buffer(Base64.decode64(@spreadsheet))
ensure
  $stdout = stdout
end

# extract data
rows = []

summary = workbook.worksheets.find do |sheet|
  sheet.sheet_name.strip.downcase == 'board summary'
end

raise 'board summary tab not found' unless summary

summary.each do |row|
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

headings = rows.delete_at(2)

# delete front and back matter
rows.shift until rows[0][0].start_with? 'Current Balances'
rows.pop until rows.last[0].start_with? 'Net Income'

# adjust spacing of current balances
blank = rows.index {|row| row.join.strip == ''}
rows[1..blank].each do |row|
  row[0] = row[0].ljust(35)
end

# move headings from second to seventh row
headings[2] = headings[6] = 'Budget'
1.upto(7) do |i|
  headings[i] = headings[i].strftime("%b-%y") if headings[i].is_a? DateTime
  headings[i] = headings[i].rjust(12) if headings[i]
end
rows.insert(blank+1, headings)

# delete empty rows
rows.pop while rows[-1].length == 1 and rows[-1][0].strip == ''

# print out current month totals
output = []
rows.each do |row|
  output << row[0..4].join(' ')
end

# drop current balances
rows.shift(blank)

# print out YTD totals
rows.each do |row|
  if row.length >= 7
    output << ([row[0]] + row[5..7]).join(' ')
  else
    output << row[0].strip
  end
end

# print output to stdout if run from the command line
puts output if __FILE__ == $0

{table: output.join("\n")}
