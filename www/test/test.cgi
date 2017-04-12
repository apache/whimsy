#!/usr/bin/env ruby
# Test file for various experiments
$LOAD_PATH.unshift File.realpath(File.expand_path('../../../lib', __FILE__))
require 'csv'
require 'json'
require 'whimsy/asf'
require 'wunderbar'
require 'wunderbar/bootstrap'
require 'net/http'
require 'whimsy/asf/themes'

PAGETITLE = 'Listing of Apache Registered Trademarks'
CSVFILE = "/Users/curcuru/src/foundation/Brand/trademark-registrations.csv"
docket = CSV.read(CSVFILE, headers:true)
docketcols = %w[ Mark Jurisdiction Class ]
# Map Mark names to PMC identifiers (only openoffice.org so far)
docket.each do |r|
  r << ['pmc', r['Mark'].downcase.sub('.org','').sub(' & design','')]
end
dockethash = {}

# Create hash based on pmc with aggregated data
docket.each do |r|
  key = r['pmc'].to_sym
  if dockethash.key?(key)
    # Aggregate specific values
    docketcols.each do |col|
      dockethash[key][col] |= [r[col]]
    end

  else
    # Create first copy of the pmc
    dockethash[key] = {}
    docketcols.each do |col|
      dockethash[key][col] = [r[col]]
    end
    # Hack: only use first Goods
    dockethash[key]['Goods'] = r['Goods']
  end
end

puts JSON.pretty_generate(dockethash)
