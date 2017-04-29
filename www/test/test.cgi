#!/usr/bin/env ruby
# Wvisible:deprecated,tools Transform docket.csv into JSON structure for other uses
$LOAD_PATH.unshift File.realpath(File.expand_path('../../../lib', __FILE__))
require 'csv'
require 'json'
require 'whimsy/asf'
require 'wunderbar'
require 'wunderbar/bootstrap'
require 'net/http'
require 'whimsy/asf/themes'

MNAM = 'TrademarkName'
brand_dir = ASF::SVN['private/foundation/Brand']
csv = CSV.read("#{brand_dir}/docket.csv", headers:true)
docket = {}
csv.each do |r|
  r << ['pmc', r[MNAM].downcase.sub('.org','').sub(' & design','')]
  key = r['pmc'].to_sym
  mrk = {}
  %w[ TrademarkStatus CountryName Class AppNumber RegNumber ClassGoods ].each do |col|
    mrk[col] = r[col]
  end  
  if not docket.key?(key)
    docket[key] = { r[MNAM] => [mrk] }
  else
    if not (docket[key]).key?(r[MNAM])
      docket[key][r[MNAM]] = [mrk]
    else
      docket[key][r[MNAM]] << mrk      
    end
  end
end

_json do
  docket
end
