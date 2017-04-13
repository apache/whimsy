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
brand_dir = ASF::SVN['private/foundation/Brand']

_json do
  docket = CSV.read("#{brand_dir}/docket.csv", headers:true)
  docketcols = %w[ TrademarkName TrademarkStatus CountryName Class RegNumber ]
  dockethash = {}
  # Create hash based on pmc with aggregated data
  docket.each do |r|
    r << ['pmc', r['TrademarkName'].downcase.sub('.org','').sub(' & design','')]
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
      dockethash[key]['ClassGoods'] = r['ClassGoods']
    end
  end
  dockethash
end
