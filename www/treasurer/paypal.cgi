#!/usr/bin/ruby1.9.1
require 'wunderbar'
require 'csv'
require '/var/tools/asf'

user = ASF::Person.new($USER)
unless user.asf_member? or ASF.pmc_chairs.include? user or $USER=='ea'
  print "Status: 401 Unauthorized\r\n"
  print "WWW-Authenticate: Basic realm=\"ASF Members and Officers\"\r\n\r\n"
  exit
end

csv = []
Dir['/var/tools/paypal/2*.csv'].sort.reverse.each do |month|
  csv += CSV.open(month,'r').to_a[1..-1]
end
download = CSV.open('/var/tools/paypal/Download.csv','r')
headers = download.take(1).flatten
csv += download.to_a

skip = [2,6,10,11,12,13,14,16]

_html do
  _head_ do
    _title 'Paypal Donations'
    _style %{
      thead th {border-bottom: solid black}
      tbody tr:hover {background-color: #FF8}
      tfoot th {border-top: solid black}
      table {border-spacing: 0.3em 0.2em }
      .issue {background-color: yellow}
      .large {background-color: #7FFF00}
    }
  end

  _body? do
    # common banner
    _a href: 'https://whimsy.apache.org/' do
      _img alt: "Logo", src: "https://id.apache.org/img/asf_logo_wide.png"
    end

    _h1_ 'Paypal donations'

    if ENV['PATH_INFO'] == '/'
      pattern = :index
    elsif ENV['PATH_INFO'] =~ /(\d{4})-0?(\d\d?)/
      pattern = Regexp.new("#{$2}/..?/#{$1}")
    else
      pattern = /^$/
    end

    _table do
      _thead_ do
        _tr do
          if pattern == :index
            _th 'Month'
            _th 'Balance'
            _th 'Transactions'
          else
            headers.each_with_index do |header, index|
              next if skip.include? index
              _th header
            end
          end
        end
      end

      month = nil
      entries = []
      count = 0
      old_balance = nil
      _tbody do
        csv.each do |transaction|
          if pattern == :index
            m,d,y = transaction[0].split('/')
            if m != month
              entries.last[-1] = count if not entries.empty?
              entries << ["#{y}-#{m.rjust(2,'0')}", transaction[15], 0]
              count = 0
              month = m
            end
            count += 1
          elsif pattern =~ transaction[0] 
            new_balance = (transaction[15].gsub(',','').to_f*100).round
            old_balance ||= new_balance
            amount = (transaction[9].gsub(',','').to_f*100).round

            color = nil
            color = 'large' if amount >= 200_00
            color = 'issue' if new_balance != old_balance

            _tr_ class: color do
              transaction.each_with_index do |col, index|
                next if skip.include? index
                if index > 6 or index == 0
                  _td col, align: 'right'
                else
                  _td col
                end
              end
            end

            next if transaction[4] == 'Web Accept Payment Received' and
              transaction[5] == 'Cleared'
            next if transaction[4] == 'Web Accept Payment Received' and
              transaction[5] == 'Canceled'
            next if transaction[4] == 'Cancelled Fee' and
              transaction[5] == 'Completed'
            next if transaction[4] == 'Update to eCheck Received' and
              transaction[5] == 'Canceled'
  
            old_balance = new_balance - amount
          end
        end

        if pattern == :index
          entries.last[-1] = count
          entries.each do |month, balance, transactions|
            _tr_ do
              _td! {_a month, href: month}
              _td balance, align: 'right'
              _td transactions, align: 'right'
            end
          end
        end
      end

      if pattern == :index
        _tfoot_ do
	  _tr do
	    _th 'Total', colspan: 2, align: 'right'
	    _th entries.map(&:last).reduce(&:+), align: 'right'
	  end
        end
      end
    end
  end
end
