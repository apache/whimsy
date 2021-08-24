#!/usr/bin/env ruby
# encoding: utf-8
require 'wunderbar'
require "date"
require "yaml"

require 'whimsy/asf'

user = ASF::Person.new($USER)
unless user.asf_member? or ASF.pmc_chairs.include? user
  print "Status: 401 Unauthorized\r\n"
  print "WWW-Authenticate: Basic realm=\"ASF Members and Officers\"\r\n\r\n"
  exit
end

HISTORY = '/var/tools/invoice'
if %r{/(?<invoice>\d+)(\.\w+)?$} =~ ENV['PATH_INFO']
  invoice_path = File.join(HISTORY, invoice)
  if File.exist? invoice_path
    form = YAML.load_file(invoice_path)
    ENV['QUERY_STRING'] =
      form.map {|k,v| "#{k}=#{CGI.escape(v.first)}"}.join("&") if form
  end
end

_html do
  _head_ do
    _title "ASF Invoice #{invoice}"
    _style %{
      .c1 {padding-top:2pt;margin-right:9pt;text-align:right;padding-bottom:2pt}
      .c5 {vertical-align:top;width:51.8pt}
      .c7 {vertical-align:top;width:134.1pt;border-style:solid;background-color:#f2f2f2;border-color:#888;border-width:1pt;padding:0pt 3.6pt 0pt 3.6pt}
      table {border-collapse:collapse}
      tr {height: 15pt}
      .c10 {vertical-align:top;width:76.5pt;border-style:solid;border-color:#888;border-width:1pt;padding:0pt 3.6pt 0pt 3.6pt}
      .c11 {vertical-align:top;width:72pt;border-style:solid;border-color:#888;border-width:1pt;padding:0pt 3.6pt 0pt 3.6pt}
      .c13 {color:#404040}
      .c15 {vertical-align:top;width:396pt;border-style:solid;border-color:#888;border-width:1pt;padding:0pt 3.6pt 0pt 3.6pt}
      .c16 {vertical-align:top;width:67.5pt;padding:0pt 3.6pt 0pt 3.6pt}
      .c17 {padding-top:2pt;padding-bottom:4pt}
      .c18 {vertical-align:top;width:267.8pt;padding:0pt 3.6pt 0pt 3.6pt}
      .c20 {vertical-align:top;width:267.8pt}
      .c21 {text-align:right}
      .c23 {width:287.2pt;padding:0pt 3.6pt 0pt 3.6pt}
      .c26 {width:220.5pt}
      .c29 {padding-top:2pt;text-align:center;padding-bottom:2pt}
      .c30 {margin: 1em 5em}
      th {font-size: 10pt; font-weight: normal; }
      p {min-height:9pt;font-size:9pt;margin:0;font-family:Verdana}
      form, img {margin-left: auto; margin-right: auto; display: block; padding-bottom: 10pt}
      body {max-width:540pt; padding:0 36pt}
      input, textarea {width: 300pt}
      input[name=total] {background-color: #8e8; color: #000; border: outset 1px; padding: 2px; border-radius: 0.3em}
      input[type=button] {width: 73pt}
      .index {border-spacing: 20px 5px; border-collapse: separate}
      .index th {border-bottom: solid black}
      .index input[type=submit] {width: 10em; display: block; margin-left: auto; margin-right: auto}
      .buttons a {text-decoration: none}
      .buttons button {width: 100pt}
    }

    _script src: '/jquery.min.js'
    _script src: '/jquery-ui.min.js'
  end

  _body? do
    _img alt: "Logo", src: "https://id.apache.org/img/asf_logo_wide.png"

    _svg width: '100%', height: 30 do
      _path d: 'M0,0h230v14h-230z', fill: '#636'
      _path d: 'M245,0h230v14h-230z', fill: '#996'
      _path d: 'M490,0h230v14h-230z', fill: '#669'
    end

    invoice ||= @invoice_number
    invoice ||= Dir.chdir(HISTORY) {Dir['*'].max || 1000}.succ
    @invoice_number = nil if ENV['REQUEST_URI'].end_with? '?'

    base = ENV['REQUEST_URI'].dup
    base.chomp! ENV['QUERY_STRING']
    base.chomp! '?'
    base.chomp! ENV['PATH_INFO']

    if ENV['PATH_INFO'].to_s.end_with? '/'

      _table_.index do
        _thead_ do
          _tr do
            _td colspan: 4 do
              _form action: "#{base}/#{invoice}" do
                _input type: 'submit', value: 'New Invoice'
              end
            end
          end
          _tr do
            _th 'Invoice'
            _th 'Date'
            _th 'Customer'
            _th 'Amount'
          end
        end
        _tbody do
          Dir.chdir(HISTORY) do
            Dir['*'].sort.reverse.each do |invoice|
              form = YAML.load_file(File.join(HISTORY, invoice))
              if form
                _tr_ do
                  _td {_a invoice, href: invoice}
                  _td Date.parse(form['date'].first)
                  _td form['customer'].first
                  _td.c21 form['total'].first.sub('$ ', '')
                end
              end
            end
          end
        end
      end

    elsif not @invoice_number and not _.pdf?

      start = Date.today
      finish = Date.new(start.year+1, start.month, start.day)-1

      _form_ method: 'post', action: "#{base}/#{invoice}" do
        _table style: 'margin-left: auto; margin-right: auto' do
          _tr.presets! style: 'display: none' do
            _td 'Presets'
            _td do
              _input type: 'button', value: 'Bronze',   'data-amount' => 5_000
              _input type: 'button', value: 'Silver',   'data-amount' => 20_000
              _input type: 'button', value: 'Gold',     'data-amount' => 40_000
              _input type: 'button', value: 'Platinum', 'data-amount' => 100_000
            end
          end

          _tr do
            _td 'E-Mail'
            _td do
              _input type: 'email', name: 'email',
                value: @email || 'fundraising@apache.org'
            end
          end

          _tr do
            _td 'Invoice Number'
            _td { _input name: 'invoice_number', value: invoice}
          end

          _tr do
            _td 'Customer Name'
            _td do
              _input name: 'customer', value: @customer,
                required: true, autofocus: true
            end
          end

          _tr do
            _td 'Purchase Order #'
            _td { _input name: 'po_number', value: @po_number }
          end

          _tr do
            _td 'Bill to'
            _td { _textarea @bill_to, name: 'bill_to', rows: 6, required: true }
          end

          _tr do
            _td 'Item Description'
            _td do
              _textarea @item, name: 'item', rows: 6, required: true,
                placeholder: "quantity - description @ $ price"
            end
          end

          _tr do
            _td 'Amount'
            _td do
              _input name: 'total', value: @total or '$ 0'
            end
          end
        end

        _input name: 'date', type: 'hidden', value: start.strftime("%B %d, %Y")

        _input type: 'submit', value: 'Save', style: 'margin-top: 1em;
          width: 10em; display: block; margin-left: auto; margin-right: auto'
      end

      _div.instructions! do
        _h4 'Instructions:'
        _p.c30 do
          _'The'
          _em 'Amount'
          _ 'field contains the sum of the dollar amounts entered in the'
          _em 'Item Description'
          _ 'field.'
        end
        _p.c30 do
          _ 'To have the dollar amount placed in the third column of the'
          _ 'invoice form, place it at the end of the line preceded by an'
          _em '@'
          _ 'sign.'
        end
        _p.c30 do
          _ 'To enter a quantity, start the line with an integer followed by a'
          _em '-'
          _ '(dash) character.'
        end
      end

      _script %{
        $('#presets').show();
        $('#presets input[type=button]').click(function() {
          var amount = '$ ' + $(this).attr('data-amount');
          amount = amount.toString().replace(/(\\d)(?=(\\d\\d\\d)+$)/g, "$1,");
          var item = "2013 " + $(this).val() + " Sponsorship @ " +
            amount + "\\n\\n";
          item += "Start Date: #{start.strftime("%B %d, %Y")}\\n\";
          item += "End Date: #{finish.strftime("%B %d, %Y")}\\n";
          $('textarea[name=item]').val(item).keyup();
          if ($('input[name=customer]').val() == '') {
            $('input[name=customer]').focus();
          }
        });

        $('textarea[name=item]').keyup(function() {
          var total = 0;

          // Process each line in turn
          var lines = $(this).val().match(/[^\\r\\n]+/g);
          for (var i=0; lines && i<lines.length; i++) {
             var line = lines[i];

             // Look for a $price at the end
             var price = line.match(/\\$\\s?([,\\d]+(\\.\\d\\d)?)$/);
             if (price && price.length > 0) {
                // Bingo, it's a price one
                var amt = parseFloat(price[1].replace(/,/,''));

                // Did they give a quantity at the start?
                var qty = line.match(/^(\\d+)\\s*[\\@\\-]/);
                if (qty && qty.length > 0) {
                   // This is a "quantity - text @ $price"
                   var quantity = parseInt( qty[1] );
                   total += (quantity * amt);
                } else {
                   // This is a "text $price"
                   total += amt;
                }
             }
          }

          // Turn it into a $ figure with commas
          // TODO Support other currencies
          total = total.toFixed(2);
          total = total.replace(/(\\d)(?=(\\d\\d\\d)+[$\\.])/g, "$1,");

          if ($('input[name=total]').val() != '$ ' + total) {
            $('input[name=total]').stop().css('backgroundColor', '#FF0').
              val('$ ' + total).animate({'backgroundColor': '#8e8'}, 1000);
            $("input[type=submit]").attr('disabled', (total=='0'));
          }
        }).keyup();

        $("input[name=invoice_number],input[name=total]").
          focus(function(){ $(this).blur(); });
      }

    else

      _table_ do
        unless _.pdf?
          _thead_ do
            _tr do
              _th.buttons colspan: 2 do
                _a href: "#{base}/#{invoice}?" do
                  _button 'Edit'
                end
                _a href: "#{base}/#{invoice}.pdf" do
                  _button 'Generate PDF'
                end
              end
            end
          end
        end

        _tbody do
          _tr do
            _td style: "width: 270pt; color: #006" do
              _p "Dept. 9660"
              _p "Los Angeles, CA 90084-9660, USA"
              _p "E-mail: #{@email ||'fundraising@apache.org'}"
              _p "US IRS Tax/EIN: 47-0825376"
            end
            _td style: "width: 270pt; text-align: right" do
              _p "Invoice", style: "font-size: 28pt; color: #636"
              _p @date
            end
          end
        end
      end

      _p

      _table_ do
        _tbody do
          _tr do
            _td.c26 do
              _table do
                _tbody do
                  _tr do
                    _td.c16 do
                      _p "Invoice No.", class: "c17 c13"
                    end
                    _td.c23 do
                      _p @invoice_number
                    end
                  end

                  _tr do
                    _td.c16 do
                      _p "Customer:", class: "c17 c13"
                    end
                    _td.c23 do
                      _p @customer
                    end
                  end

                  if @po_number and not @po_number.empty?
                    _tr do
                      _td.c16 do
                        _p "Reference:", class: "c17 c13"
                      end
                      _td.c23 do
                        _p "PO##{@po_number}"
                      end
                    end
                  end
                end
              end
            end
            _td.c5
            _td.c20 do
              _table do
                _tbody do
                  _tr do
                    _td.c18 do
                      _p 'Bill To:', class: "c17 c13"
                    end
                  end

                  _tr do
                    _td.c18 do
                      @bill_to.lines.each do |line|
                        _p line.chomp
                      end
                    end
                  end
                end
              end
            end
          end
        end
      end

      _p style: 'height: 30pt'

      _table_ do
        _thead do
          _tr do
            _th 'Quantity', class: "c11"
            _th 'Item', class: "c15"
            _th 'Total', class: "c11"
          end
        end
        _tbody do
          @item.lines.each do |line|
            line.gsub!(/^(\d+)\s-\s*/,'')
            quantity = $1

            if line.match(/[-@]?\s?\$\s?([,\d\.]+)$/)
              amt = $1.gsub(',', '')
              quantity ||= '1'
              price = quantity.to_i * amt.to_f

              # Format the float as a 2dp number
              price = "%0.2f" % price

              # Now make it look pretty with commas
              price = price.gsub(/(\d)(?=(\d\d\d)+(?!\d))/, '\1,')
            else
              quantity = price = ''
            end

            _tr do
              _td.c11 do
                _p.c29 quantity
              end
              _td.c15 do
                _p.c17 line.chomp
              end
              _td.c10 do
                _p.c1 price
              end
            end
          end
          (10-@item.lines.count).times do
            _tr do
              _td.c11
              _td.c15
              _td.c10
            end
          end
        end
      end

      _p

      _table_ style: "margin-left: auto" do
        _tbody do
          _tr do
            _td.c7 do
              _p "Subtotal:", class: "c17 c21 c13"
            end
            _td.c10 do
              _p.c1 @total
            end
          end
          _tr do
            _td.c7 do
              _p 'Tax:', class: "c17 c21 c13"
            end
            _td.c10 do
              _p.c1 "-"
            end
          end
          _tr do
            _td.c7 do
              _p 'Shipping:', class: "c17 c21 c13"
            end
            _td.c10 do
              _p.c1 '-'
            end
          end
          _tr do
            _td.c7 do
              _p "Miscellaneous:", class: "c17 c21 c13"
            end
            _td.c10 do
              _p.c1 "-"
            end
          end
          _tr do
            _td.c7 do
              _p "Balance Due:", class: "c17 c21 c13"
            end
            _td.c10 do
              _p.c1 @total
            end
          end
        end
      end

      _div style: "margin-top: 30pt; color: #006" do
        _p "Please make checks payable to “The Apache Software Foundation”."
        _p
        _p "Wire and ACH payments information:"
        _p "Beneficiary: “Apache Software Foundation”"
        _p "Routing #: 121 000 248 (for domestic wire or ACH)"
        _p "SWIFT: WFBIUS6S (for international wire)"
        _p "Account #: 3189163755"
        _p "Wells Fargo Bank"
      end

      if @invoice_number =~ /\A\d+\z/
        File.open(File.join(HISTORY, @invoice_number), 'w') do |file|
          file.write params.to_yaml
        end
      else
        _p "Invalid invoice number #{@invoice_number}, could not create invoice"
      end
    end
  end
end
