#!/usr/bin/env ruby
require 'wunderbar'
require 'yaml'
require 'whimsy/asf'

user = ASF::Person.new($USER)
unless user.asf_member? or ASF.pmc_chairs.include? user or $USER=='ea'
  print "Status: 401 Unauthorized\r\n"
  print "WWW-Authenticate: Basic realm=\"ASF Members and Officers\"\r\n\r\n"
  exit
end

categories = [
  'Concom',
  'Infrastructure',
  'Public Relations',
  'Secretary',
  'Treasurer',
  'President',
  'TAC',
  'Chair',
  'Branding',
  'Infrastructure Contractors',
  'Public Relations Contractors',
  'Executive Assistant',
  'Uncategorized/Multiple',
]

paid = 'https://svn.apache.org/repos/private/financials/Bills/paid/'

statements = '/var/tools/statements'
dates = Dir["#{statements}/*.pdf","#{statements}/*.yml"].
  map {|name| File.basename(name).chomp('.pdf').chomp('.yml')}.uniq.sort

class Numeric
  def currency
    ('%.2f' % self).gsub(/(\d)(?=(\d{3})+\.)/, '\1,')
  end
end

_html do
  _head_ do
    _title 'Statement'
    _script src: '/jquery-min.js'
    _script src: '/jquery.tablesorter.js'
    _style %{
      a {text-decoration: none}
      tr:hover a {text-decoration: underline}
      thead th {border-bottom: solid black}
      tfoot th, tfoot td {border-top: solid black}
      table {border-spacing: 1em 0.2em; float: left }
      tbody tr:hover {background-color: #FF8}
      th span {float: right}
      .headerSortUp span:after {content: " \u2198"}
      .headerSortDown span:after {content: " \u2197"}
      svg {width: 30%; margin-left: 10%}
      h2 {clear: both}
    }
  end

  _body? do
    # common banner
    _a href: 'https://whimsy.apache.org/' do
      _img title: "Logo", alt: "Logo",
        src: "https://id.apache.org/img/asf_logo_wide.png"
    end

    _h1_ 'Expenses'

    @date ||= env['PATH_INFO'].to_s[/\/(\d{4}-\d\d)$/,1] || dates.last
    @date = 'all' if env['PATH_INFO'] == '/all'
    @date.untaint if @date =~ /^\d{4}-\d\d$/

    if /expenses.*\/(?<category>.+)/ =~ env['REQUEST_URI']
      @category = category unless category == 'all'
      @date = 'all'
    end

    unless @category
      request_uri = env['REQUEST_URI'].split('?').first
      _form.month! method: 'post', action: request_uri.sub(/\d{4}-\d\d$/,'') do
        _select name: 'date' do
          dates.reverse.each do |date|
            _option date, selected: (date == @date)
          end
          _option 'all', selected: (@date == 'all')
        end
        _input value: 'submit', type: 'submit'
      end
    end
    
    if @date == 'all'
      debits = []
      Dir["#{statements}/*.yml"].sort.each do |statement|
        debits += YAML.load_file statement.untaint
      end
      if @category
        debits.select! {|debit| debit['category'].gsub(/\W+/,'_') == @category}
      end
      statement = ''
    elsif File.exist? "#{statements}/#{@date}.yml"
      statement = ''
      debits = YAML.load_file "#{statements}/#{@date}.yml"
    else
      statement = `pdftotext #{statements}/#{@date}.pdf -`
      # credits = statement[/^Credits(.*)^Debits/m,1]
      statement = statement[/^^Debits(.*)^Daily ledger/m,1].to_s
      debits = []
    end

    if debits.empty? and not statement.empty?
      dates = statement.scan(/^\d\d\/\d\d/)
      amounts = statement.scan(/^[.,\d]+$/)
      details = statement.
	scan(/^(?:WT |Bill Pay|WF Bus|Client Anal|Safe Box|Online Transfer).*/)

      _form_.debits! style: ('display: none' unless debits.empty?) do
	_button 'File'
	_select_.category! do
	  _option ''
	  categories.each do |category|
	    _option category
	  end
	end
	_select_.date! do
	  dates.sort.each do |date|
	    _option date, value: date
	  end
	end
	_select_.amount! do
	  amounts.each do |amount|
	    _option amount, value: amount
	  end
	end
	_select_.detail! do
	  details.each do |detail|
	    _option detail.strip, value: detail.strip
	  end
	end
      end
    end

    subtotals = Hash.new(0)
    debits.each do |transaction|
      subtotals[transaction['category']] += transaction['amount'] 
    end
    total = subtotals.values.reduce(&:+) || 0

    unless @category
      _h2_ 'Summary'
      colors = Hash.new('#000')

      if total > 0
        require 'color'
        color = Color::RGB.from_html('#4488FF').to_hsl
        step = 360.0 / ( PHI = (1 + Math.sqrt(5)) / 2 )

        _svg_ viewBox: '-500 -500 1000 1000' do
          _circle r: 480, stroke: '#000', fill: '#000'
          theta = 0
          subtotals.sort_by(&:last).reverse.each do |category, subtotal|
            p1 = [Math.sin(theta)*475, -Math.cos(theta)*475].map(&:round)
            theta += Math::PI*2 * subtotal/total
            p2 = [Math.sin(theta)*475, -Math.cos(theta)*475].map(&:round)
            arc = (subtotal*2 > total ? '1' : '0')
            _path fill: color.html, title: category,
              d: "M0,0 L#{p1.join(',')} A475,475 0 #{arc} 1 #{p2.join(',')} Z"
            colors[category] = color.html
            color.hue = (color.hue + step) % 360
          end
        end
      end

      _table do
        _thead do
          _tr do
            _th 'Category'
            _th 'Amount'
          end
        end
        _tbody_ do
          bullet = "\u25CF" unless total==0
          (categories+subtotals.keys).sort.uniq.each do |category|
            _tr_ style: ('display: none' if subtotals[category] == 0) do
              _td!.category do
                _a category, 
                  href: "/treasurer/expenses/#{category.gsub(/\W+/,'_')}"
              end
              _td.subtotal subtotals[category].currency, align: 'right'
              _td bullet, style: "color: #{colors[category]}"
            end
          end
        end
        _tfoot do
          _tr do
            _th 'Total'
            _td.total! total.currency, align: 'right'
          end
        end
      end
    end

    if @date =~ /\d{4}-\d\d/ or @category
      _h2_ categories.find {|category| category.gsub(/\W+/,'_')==@category} ||
         @category || 'Detail'
      _table do
        _thead_ do
          _tr do
            _th 'Date'
            _th 'Amount' 
            _th 'Category' unless @category
            _th 'Detail'
          end
        end
        _tbody.categorized! do
          debits.each do |transaction|
            _tr_ do
              _td transaction['date']
              _td transaction['amount'].currency, align: 'right'
              _td transaction['category'] unless @category
              if transaction['link']
                _td! do
                  _a transaction['detail'], href: paid + transaction['link'],
                    title: transaction['notes']
                end
              else
                _td transaction['detail'], title: transaction['notes']
              end
            end
          end
        end
        if @category
	  _tfoot do
	    _tr do
	      _th 'Total'
	      _td.total! total.currency, align: 'right'
	    end
	  end
        end
      end
    end

    _script_ %q{
      var year = null;
      if (document.getElementById('month')) {
        $('#month select').change(function() { 
          location.href = "/treasurer/statements/" + $(this).val();
          if ($(this).val()=='all') location.href = "/treasurer/expenses/all";
        });
        $('#month input').hide();
        year = $('#month select').val().match(/(\d{4})-\d\d/);
        if (year) year[1];
      }

      $('button').click(function() {
        var tr = $('<tr></tr>');

        var date = $('<td></td>').text($('#date').val());
        $('#date option[value="'+date.text()+'"]:first').remove();
        tr.append(date);

        var category = $('<td></td>').text($('#category').val());
        tr.append(category);

        var amount = $('<td align="right"></td>').text($('#amount').val());
        $('#amount option[value="'+amount.text()+'"]:first').remove();
        tr.append(amount);

        var detail = $('#detail').val();
        $('#detail option[value="'+detail+'"]:first').remove();
        detail = detail.replace(/WT \d+-\d+/,'WT');
        detail = detail.replace(/WT Fed#\d+/,'WT Fed');
        detail = detail.replace(/ Recurring.*/,'');
        detail = detail.replace(/Auto Pay \d+ \d+/,'Auto Pay');
        detail = detail.replace(/Srvc Chrg .*/,'Srvc Chrg');
        detail = detail.replace(/on-Line [xX]\w* on .*/i,'');
        detail = detail.replace(/on-Line No Account Number on .*/,'');
        detail = detail.replace(/:Fee \d.*/,':Fee');
        detail = $('<td></td>').text(detail);
        tr.append(detail);
        $('#detail').change();

        $('.category').each(function() {
          if ($(this).text() == category.text()) {
            var tr = $(this).parent();
            var td = $('td:last', tr);
            var subtotal =
              parseFloat(td.text().replace(/,/g,'')) +
              parseFloat(amount.text().replace(/,/g,''));
            subtotal = subtotal.toFixed(2);
            subtotal = subtotal.replace(/(\d)(?=(\d{3})+\.)/g, '$1,');
            td.text(subtotal);
            tr.show();
          }
        });

        var total = 0;
        $('.subtotal').each(function() {
          total += parseFloat($(this).text().replace(/,/g,''));
        });
        total = total.toFixed(2);
        total = total.replace(/(\d)(?=(\d{3})+\.)/g, '$1,');
        $('#total').text(total);
        
        $('#categorized').append(tr);

        if (!$('#date').val() && !$('#detail').val() && !$('#amount').val()) {
          var data = {month: $('#month select').val(), debits: []};
          $('#categorized tr').each(function() {
            var cols = $('td', $(this));
            data.debits.push({
              date:     year + '-' + cols[0].textContent.replace('/', '-'),
              category: cols[1].textContent,
              amount:   parseFloat(cols[2].textContent.replace(/,/g, '')),
              detail:   cols[3].textContent
            });
          });
          data.debits = JSON.stringify(data.debits)
          $.post(location.href, data, function(_) {
            $('#debits').replaceWith($('<p></p>').text(_.message));
          }, 'json');
        }

        return false;
      });

      $('#date option:first').attr('selected', true);
      $('#amount option:first').attr('selected', true);
      $('#detail option:first').attr('selected', true);

      var patterns = {
        'Traci.Net':         'Infrastructure',
        'Pctony':            'Infrastructure Contractors',
        'Shahaf':            'Infrastructure Contractors',
        '16 Degrees':        'Infrastructure Contractors',
        'Sunstar':           'Infrastructure Contractors',
        'Warnkin Recurring': 'Executive Assistant',
        'Khudairi':          'Public Relations Contractors',
        'PR Newswire':       'Public Relations',
        'Globenewswire':     'Public Relations',
        'Srvc Chrg':         'Treasurer',
        'WF Bus Banking':    'Treasurer',
        'Safe Box':          'Treasurer',
        'The Company Corp':  'President',
        'Nicholas Burch':    'Concom',
      }

      $('#category').change(function() {
        $('button').attr('disabled', $('#category').val() == '');
      });

      $('#detail').change(function() {
        var detail = $(this).val();
        $('#category').val('').attr('selected', true);
        if (detail) {
          for (var pattern in patterns) {
            if (detail.match(pattern)) {
              $('#category').val(patterns[pattern]).attr('selected', true);
            }
          }
        }

        $('#category').change();
      }).change();

      $.tablesorter.addParser({ 
        id: 'commafied', 
        type: 'numeric',
        is: function(s) { return s.match(/^[\d.,]+$/) }, 
        format: function(s) { 
          return jQuery.tablesorter.formatFloat(s.replace(/,/g, ""));
        }
      }); 

      $('thead th').append('<span></span>');
      $("table").tablesorter(
        {sortList: [[0,0]], headers: {1: {sorter:'commafied'}}}
      );

      $('.category').each(function() {
        var path = $('path[title="' + $('a', this).text() + '"]');
        if (path.length == 0) return;

        $(this).parents('tr').
          mouseover(function() {
            path.attr({'stroke-width': 35, stroke: path.attr('fill')});
            path.parent().append(path);
          }).
          mouseout(function() {
            path.removeAttr('stroke-width').removeAttr('stroke');
          });
      });

      $('svg').attr('stroke-linejoin', 'round');
      $(window).resize(function() {
        $('svg').height($(window).width()/3);
        $('svg').width($(window).width()/3);
      }).trigger('resize');
    }
  end
end

_json do
  @month.untaint if @month =~ /^\d{4}-\d\d$/
  File.open("#{statements}/#{@month}.yml",'w') do |file|
    file.write YAML.dump(JSON.parse(@debits))
  end
  _message "Categorization complete"
end
