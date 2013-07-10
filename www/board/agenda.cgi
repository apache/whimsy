#!/usr/bin/ruby1.9.1
require 'ostruct'
require 'wunderbar'
require 'yaml'
require 'fileutils'
require 'time'
require '/var/tools/asf'
require 'shellwords'
require_relative 'apply_comments'

ENV['HOME'] = ENV['DOCUMENT_ROOT']
SVN_FOUNDATION_BOARD = ASF::SVN['private/foundation/board']
MINUTES_WORK = '/var/tools/data'

DIRECTORS = {
  'curcuru'     => 'sc',
  'cutting'     => 'dc',
  'bdelacretaz' => 'bd',
  'fielding'    => 'rf',
  'jim'         => 'jj',
  'mattmann'    => 'cm',
  'brett'       => 'bp',
  'rubys'       => 'sr',
  'gstein'      => 'gs'
}

user = ASF::Person.new($USER)
director = DIRECTORS[$USER]
secretary = %w(clr jcarman).include? $USER

unless secretary or director or user.asf_member? or ASF.pmc_chairs.include? user or $USER=='ea'
  print "Status: 401 Unauthorized\r\n"
  print "WWW-Authenticate: Basic realm=\"ASF Members and Officers\"\r\n\r\n"
  exit
end

UPDATE_FILE = "#{MINUTES_WORK}/#{$USER}.yml".untaint if $USER =~ /\A\w+\Z/
if director and File.exist? UPDATE_FILE
  updates = YAML.load_file(UPDATE_FILE)
  approved = updates['approved']
  comments = updates['comments']
else
  approved, comments = [], {}
end

agenda = {}

class << agenda
  def order
    @order ||= []
  end

  def filename
    if ENV['REQUEST_URI'] =~ /\/agenda.*\/(\d\d\d\d[-_]\d\d[-_]\d\d)\//
      date = $1.gsub('-','_').untaint
    elsif ENV['REQUEST_URI'] =~ /\/agenda.*\/(\d\d\d\d[-_]\d\d)\//
      date = $1.gsub('-','_').untaint + '_*'
    elsif ENV['REQUEST_URI'] =~ /\/agenda.*\/(\d\d)\//
      date = '*_' + $1.gsub('-','_').untaint + '_*'
    elsif ENV['REQUEST_URI'] =~ /\/agenda.*\/(\d\d[-_]\d\d)\//
      date = '*_' + $1.gsub('-','_').untaint
    else
      date = '*'
    end

    Dir["#{SVN_FOUNDATION_BOARD}/board_agenda_#{date}*.txt"].sort.last.untaint
  end

  def yaml
    MINUTES_WORK + '/' + File.basename(filename).
      sub('_agenda_','_minutes_').sub('.txt','.yml')
  end

  def save(report)
    order << report.attach unless order.include? report.attach
    self[report.attach] = report
  end

  def notes
    @notes ||= (File.exist?(yaml) ? YAML.load_file(yaml) : {})
  end

  def at(index)
    self[order[index]]
  end
end

load_agenda = Proc.new do
  agenda.clear
  agenda.order.clear

  file = File.read(agenda.filename)

  # Front Matter
  file.scan(/^ ([12]\.) (.*?)\n+(.*?)(?=\n [23]\.)/m).each do \
    |attach, title, text|
    next unless title =~ /Call/
    report = agenda[attach] || OpenStruct.new
    report.attach = attach
    report.title = title
    report.text = text
    agenda.save report
  end

  # Minutes
  file.split(/^ 3. Minutes from previous meetings/,2).last.
         split(/^ 4. Executive Officer Reports/,2).first.scan(/
    \s{4}([A-Z])\.         # section
    \sThe.meeting.of(.*?)  # title
    \[\s(?:.*?):\s*?(.*?)  # approved | TABLED
    \s*comments:(.*?)\n    # comments
    \s{8,9}\]\n
  /mx).each do |section,title,approved,comments|
    title,text = title.strip.split("\n",2)
    attach = '3' + section
    report = agenda[attach] || OpenStruct.new
    report.attach = attach
    report.title = title
    report.text = text
    report.approved = approved.strip.gsub(/\s+/,' ')
    report.comments = comments
    agenda.save report
  end

  # Executive Officer Reports
  file.split(/^ 4. Executive Officer Reports/,2).last.
         split(/^ 5. Additional Officer Reports/,2).first.scan(/
    \s{4}([A-Z])\.          # section
    \s([^\[]+?)             # title
    \s\[([^\]]+?)\]         # owner
    (.*?)                   # text
    (?=\n\s{4}[A-Z]\.\s|\z) # next section
  /mx).each do |section,title,owner,text|
    attach = '4' + section
    report = agenda[attach] || OpenStruct.new
    report.attach = attach
    report.author = owner.split('/').first.strip
    report.shepherd = owner.split('/').last.strip
    report.title = title
    text.gsub!(/\n\n\s+\[.*\]\s*$/m) {|comments|
      report.comments = comments
      "\n\n"
    }
    report.text = text
    agenda.save report
  end

  # Additional Officer Reports and Committee Reports (part I)
  file.scan(/
    -{41}\n                        # separator
    Attachment\s\s?(\w+):\s(.*?)\n # Attachment, Title
    .(.*?)\n                       # report
    (?=-{41,}\n(?:End|Attach))     # separator
  /mx).each do |attach,title,text|
    title.sub! /^Report from the VP of /, ''
    title.sub! /^Report from the /, ''
    title.sub! /^Status report for the /, ''
    title.sub! /^Apache /, ''
    title.sub! /\s*\[.*\]$/, ''
    title.sub! /\sTeam$/, ''
    title.sub! /\sCommittee$/, ''
    title.sub! /\sProject$/, ''

    report = agenda[attach] || OpenStruct.new
    report.attach = attach
    report.title = title
    report.text  = text
    agenda.save report
  end

  # Additional Officer Reports and Committee Reports (part II)
  file.scan(/
    \[([^\n]+)\]\n\n                  # owners
    \s{7}See\sAttachment\s\s?(\w+)[^\n]*?\s+ # attach (title)
    \[\s[^\n]*\s*approved:\s*?(.*?)            # approved
    \s*comments:(.*?)\n\s{9}\]        # comments
  /mx).each do |owners,attach,approved,comments|
    report = agenda[attach] || OpenStruct.new

    if owners.include? '/'
      report.author, report.shepherd = owners.gsub(%r{\s*/\s*} ,'/').split('/',2)
    else
      report.author = report.shepherd = owners
    end

    report.attach = attach
    report.approved = approved.gsub(/\s+/,' ').strip
    report.comments = comments.gsub Regexp.new("^#{' '*9}"), ''
    agenda.save report
  end

  # Special Orders
  file.split(/^ 7. Special Orders/,2).last.
         split(/^ 8. Discussion Items/,2).first.scan(/
    \s{4}([A-Z])\.          # section
    \s(.*?)\n               # title
    (.*?)                   # text
    (?=\n\s{4}[A-Z]\.\s|\z) # next section
  /mx).each do |section,title,text|
    attach = '7' + section
    report = agenda[attach] || OpenStruct.new
    report.attach = attach
    text.sub!(/\n {7}\[ comments:(.*?)\n {9}\]\n/m) {report.comments = $1; ''}
    report.text = "#{title}\n#{text}"

    if secretary
      directors = agenda.notes['Roll Call'].to_s.split(/\n\s*\n/)[1]
      directors ||= agenda['2.'].text.split(/\n\s*\n/)[1]

      report.text += "\n---\n"

      if (section[-1].ord + Time.new.month) % 2 == 0
        report.text += 'Roll call'
      else
        directors = directors.split("\n").reverse.join("\n")
        report.text += 'Reverse roll call'
      end
      report.text += " vote on the matter of #{title}:\n\n#{directors}"
    end

    title.sub! /^Resolution to /, ''
    title.sub! /\sthe\s/, ' '
    title.sub! /\sApache\s/, ' '
    title.sub! /\sCommittee\s/, ' '
    title.sub! /\sProject\s/, ' '
    title.sub! /\sProject$/, ''
    title.sub! /\sPMC$/, ''

    report.title = title
    agenda.save report
  end

  # Back Matter
  file.scan(/^((?: [89]| 9|1\d)\.) (.*?)\n(.*?)(?=\n[ 1]\d\.|\n===)/m).each do\
    |attach, title, text|
    report = agenda[attach.strip] || OpenStruct.new

    if !text.empty? and title =~ /Action Items/
      i = ('a'.ord-1).chr
      text.gsub!(/\n        Update:\n/) {|line| "#{line.chomp} [#{i.succ!}]\n" }
    end

    report.attach = attach.strip
    report.title = title
    report.text = text
    agenda.save report
  end

  agenda.order.each do |attach|
    report = agenda[attach]
    min = 5
    min = 0 if attach =~ /(8|9|1\d)\./ and report.text.to_s.empty?

    report.title ||= "Missing #{attach}"
    report.link = report.title.gsub(/\W/,'_').gsub(/_+/,'_')

    report.status = 
      if agenda.notes[report.title]
        'reviewed'
      elsif report.attach == '4B' and
        report.text.to_s.strip =~ /\AAdditionally, please see Attachments 1/
        'missing'
      elsif report.text.to_s.strip.empty? and min>0
        if report.title =~ /THERE IS NO/
          'reviewed'
        elsif report.comments.to_s.strip != '' and report.approved.to_s.empty?
          'commented'
        else
          'missing'
        end
      elsif report.approved.to_s.strip.split(/(?:,\s*|\s+)/).size < min
        if report.attach =~ /7\w|\d\./ and report.approved.to_s.empty?
          'ready4meet'
        elsif director and
          !report.approved.to_s.split(/[ ,]+/).include? director and
          !approved.include? report.attach and
          report.attach !~ /4\w/ and
          (report.attach !~ /^\d+$/ or report.author)
          'ready4me'
        else
          'ready'
        end
      elsif report.comments.to_s.strip.size > 0
        'commented'
      else
        'reviewed'
      end
  end
end

class String
  def asciize
    if match /[^\x00-\x7F]/
      # digraphs.  May be culturally sensitive
      gsub! /\u00df/, 'ss'
      gsub! /\u00e4|a\u0308/, 'ae'
      gsub! /\u00e5|a\u030a/, 'aa'
      gsub! /\u00e6/, 'ae'
      gsub! /\u00f1|n\u0303/, 'ny'
      gsub! /\u00f6|o\u0308/, 'oe'
      gsub! /\u00fc|u\u0308/, 'ue'

      # latin 1
      gsub! /[\u00e0-\u00e5]/, 'a'
      gsub! /\u00e7/, 'c'
      gsub! /[\u00e8-\u00eb]/, 'e'
      gsub! /[\u00ec-\u00ef]/, 'i'
      gsub! /[\u00f2-\u00f6]|\u00f8/, 'o'
      gsub! /[\u00f9-\u00fc]/, 'u'
      gsub! /[\u00fd\u00ff]/, 'y'

      # Latin Extended-A
      gsub! /[\u0100-\u0105]/, 'a'
      gsub! /[\u0106-\u010d]/, 'c'
      gsub! /[\u010e-\u0111]/, 'd'
      gsub! /[\u0112-\u011b]/, 'e'
      gsub! /[\u011c-\u0123]/, 'g'
      gsub! /[\u0124-\u0127]/, 'h'
      gsub! /[\u0128-\u0131]/, 'i'
      gsub! /[\u0132-\u0133]/, 'ij'
      gsub! /[\u0134-\u0135]/, 'j'
      gsub! /[\u0136-\u0138]/, 'k'
      gsub! /[\u0139-\u0142]/, 'l'
      gsub! /[\u0143-\u014b]/, 'n'
      gsub! /[\u014C-\u0151]/, 'o'
      gsub! /[\u0152-\u0153]/, 'oe'
      gsub! /[\u0154-\u0159]/, 'r'
      gsub! /[\u015a-\u0162]/, 's'
      gsub! /[\u0162-\u0167]/, 't'
      gsub! /[\u0168-\u0173]/, 'u'
      gsub! /[\u0174-\u0175]/, 'w'
      gsub! /[\u0176-\u0178]/, 'y'
      gsub! /[\u0179-\u017e]/, 'z'

      # denormalized diacritics
      gsub! /[\u0300-\u036f]/, ''
    end

    self
  end
end

# pattern looking for URIs in text
uri_in_text = /(^|[\s.:;?\-\]<\(])
               (https?:\/\/[-\w;\/?:@&=+$.!~*'()%,#]+[\w\/])
               (?=$|[\s.:,?\-\[\]&\)])/x

_html do
  begin
    load_agenda.call 
  rescue
    agenda.clear # load will be run again with traceback captured below
  end

  link = ENV['REQUEST_URI'][/\/agenda.*\/(.*)/,1]
  attach, report = agenda.find {|attach,report| report.link == link}

  _head do

    if attach
      _title 'ASF Board Agenda - ' + report.title
    elsif agenda.filename
      _title 'ASF Board Agenda - ' + File.basename(agenda.filename).
       split('.').first.sub(/^[\D]+/,'').gsub('_','-')
    end

    _link rel: "stylesheet", href: "/jquery-ui.css"
    _style %{
      #notice, ._stdout {color: green}
      ._stderr {color: red}
      ._stdin {font-weight: bold; margin-top: 1em}
      footer {text-align: center}
      footer ul {list-style-type: none; padding: 0}
      a {color: #000}
      .shell {border: 1px solid black;  border-radius: 1em; margin: 0 25%}
      .private {background-color: #ccc}

      /* row colors */
      .missing    {background-color: #F55}
      .ready4meet {background-color: #F70}
      .ready4me   {background-color: #F20}
      .ready      {background-color: #F90}
      .reviewed   {background-color: #9F9}
      .commented  {background-color: #FF0}

      /* sidebar */
      .side {float: right} 
      .side ul {margin: 0}
      .side li {list-style: none}

      /* next/back links */
      .backlink {float: left}
      .nextlink {float: right}
      .backlink:before {content: "<< "}
      .nextlink:after  {content: " >>"}

      /* action items */
      .ai {background-color: yellow}

      /* make the header an eye catcher */
      h1, h2.subtitle {
        line-height: 2em;
        text-align: center;
        text-transform: capitalize;
        clear: both
      }

      /* center the table */
      table {
        margin-left: auto;
        margin-right: auto
      }

      /* table borders */
      table, td, th {
        border-color: #600;
        border-style: solid;
        border-width: 1px;
      }

      table {
        border-spacing: 0;
        border-collapse: collapse;
      }

      td, th {
        margin: 0;
        padding: 4px;
      }

      td:first-child {
        text-align: center
      }

      tr {
        background-color: #FFC;
      }

      tr.new {
        background-color: yellow
      }

      .buttons {
        margin-top: 1em;
        text-align: center
      }

      .buttons div, .buttons form {
        display: inline
      }

      form label {
        display: block; margin-top: 0.5em
      }

      #comment_popup label {
        display: inline;
      }

      #comment_popup input {
        margin-bottom: 0.5em;
      }

      pre {
        padding-left: 2em;
        margin: 0;
      }

      pre#approved {
        padding: 10px;
      }

      input[type=submit] {
        border-radius: 1em;
        background-color: #FFC;
      }

      .uptodate {
        background-color: #7cfc00 !important
      }

      .stale {
        background-color: #dc143c !important
      }

      .comments button, #paste_report { 
        color: #000; 
        background-color: #F90; 
        border-radius: 0.5em
      }

      #paste_popup, #comment_popup {
        display: none
      }

      #paste_popup textarea {
        font-family: monospace;
        font-size: small
      }
    }

    _script src: '/jquery.min.js'
    _script src: '/jquery-ui.min.js'
  end

  _body do
    load_agenda.call if agenda.empty?

    if attach

      ############################################################ 
      #               Individual agenda item page                #
      ############################################################ 

      # previous and next links
      index = agenda.order.index(attach)
      if index > 0
        _a.backlink agenda.at(index-1).title,
           href: agenda.at(index-1).link, accesskey: '-'
      end
      if index < agenda.order.length-1
        _a.nextlink agenda.at(index+1).title,
           href: agenda.at(index+1).link, accesskey: '+'
      end

      # process update requests
      if secretary and _.post?
        if @title
          if @notes.to_s.empty?
            agenda.notes.delete @title
          else
            agenda.notes[@title] = @notes.gsub(/\r/,'').sub(/\A\s*\n/,'')
          end

          # safety first: verify data before write, and backup every change
          if File.exist? agenda.yaml
            # blows up on Ruby 1.8.7: YAML.load(YAML.dump({'boom'=>"\n x\ny"}))
            YAML.load(YAML.dump(agenda.notes))

            # make a timestamped copy of the original
            backup = agenda.yaml.sub(/^(.*\/)?/, '\1backup/') + '-' +
              File.stat(agenda.yaml).mtime.utc.iso8601.gsub(/\W/,'_')
            FileUtils.mkdir_p File.dirname(backup)
            FileUtils.cp agenda.yaml, backup
          end

          File.open(agenda.yaml, 'w') {|file| YAML.dump(agenda.notes, file)}
          _p.notice! 'Report was successfully updated'
        end
      end

      _h1 report.title, class: report.status

      # sidebar
      _div.side do
        _ul do
          _li {_a 'Agenda', href: '.'}
          _li {_a 'Roll Call', href: agenda['2.'].link}
          _li {_a 'Minutes', href: agenda['3A'].link}
          _li {_a 'Executive Officer', href: agenda['4A'].link}
          _li {_a 'Additional Officer', href: agenda['1'].link}
          _li {_a 'Committee Reports', href: agenda['A'].link}
          _li {_a 'Special Orders', href: agenda['7A'].link} rescue nil
          _li {_a 'Discussion Items', href: agenda['8.'].link}
          _li {_a 'Action Items', href: agenda['9.'].link}
          if agenda.notes.empty?
            _li {_a 'Pre-approvals', href: 'preapps'}
          else
            _li {_a 'Notes', href: 'notes'}
          end
        end
      end

      # Form with mostly readonly/hidden fields
      _form method: 'post' do
        _input.title! name: 'title', value: report.title,
         type: 'hidden'

        _p do
          _label 'Attach', for: 'attach'
          _input.attach! name: 'attach', value: attach,
            readonly: 'readonly'
        end

        _p do
          _label 'Author', for: 'author'
          _input.author! name: 'author', value: report.author,
            readonly: 'readonly'
        end

        _p do
          _label 'Shepherd', for: 'shepherd'
          _input.shepherd! name: 'shepherd', 
            value: report.shepherd, readonly: 'readonly'
        end
        
        unless report.approved.to_s.empty?
          _label 'Approved by', for: 'approved'
          _pre.approved! report.approved
        end

        _label 'Text', for: 'text'
        _pre.text! do
          text = CGI.escapeHTML(report.text.to_s).
            gsub(/^    Guests( |:)/, '    <a href="https://svn.apache.org/repos/private/foundation/members.txt">Guests</a>\1').
            gsub(/(board_minutes_\d+_\d+_\d+)/, '<a href="https://svn.apache.org/repos/private/foundation/board/\1.txt">\1</a>').
            gsub(/\n---\n/, "\n<hr />\n").
            gsub(/\n+\z/, "\n").
            gsub(/\A\n/, "")

          # highlight private sections
          text.gsub! /^(\s*)(&lt;private&gt;.*?&lt;\/private&gt;)(\s*)$/mi,
            '\1<span class="private">\2</span>\3'

          # make links in text active
          text.gsub!(uri_in_text) do
            pre, link = $1, $2
            "#{pre}<a href=\"#{link.gsub("&amp;amp;", "&amp;")}\">#{link}</a>"
          end
          text.gsub! /(\s)(s\.apache\.org\/\w+)/, '\1<a href="http://\2">\2</a>'

          # validate name/email addresses in resolutions
          s = '[-*\u2022]'
          if report.attach =~ /7\w/
            text.gsub! /\((\w+)\)$/, '&lt;\1@apache.org&gt;'
            if text =~ /FURTHER RESOLVED, that (.*?(\n.*?)??),? be/
              chairname = $1.gsub(/\s+/, ' ').strip
            else
              chairname = nil
            end
          end

          if report.attach =~ /7\w/ and text =~/^\s+#{s}.*(@| at )/
            text.gsub! /^\s*#{s}(.*?)&lt;(\w+)(@| at )(\.\.\.|apache\.org)&gt;/ do |line|
              personname = $1.strip
              person = ASF::Person.new($2)
              if person.icla
                # link to the roster information for this committer
                line.sub! /(&lt;)(\w+)(@.*?| at .*?)(&)/, 
                  '\1<a href="/roster/committer/\2">\2\3</a>' +
                  '<span style="display:none" class="tlpreqpmcmemberavailid">' +
                  '\2' + '</span>' +
                  '\4'

                if [personname, person.public_name.to_s].any? { |cn| cn.index (chairname) }
                    line += '<span style="display:none" ' \
                          + ' class="tlpreqchairavailid">' + $2 + '</span>'
                end

                # match is defined as having a subset of tokens in any order
                icla = person.icla.name.split(' ').map(&:asciize)
                resolution = line[/#{s}\s+(.*?)\s&/,1].split(' ').map(&:asciize)
                unless (icla-resolution).empty? or (resolution-icla).empty?
                  ldap = person.public_name.split(' ').map(&:asciize)

                  unless (ldap-resolution).empty? or (resolution-ldap).empty?
                    line.sub! /(#{s}\s+)(.*)(\s+&lt;)/, 
                     '\1<span title="name doesn\'t match ICLA" ' +
                     'class="commented">\2</span>\3'
                  end
                end
              else
                line.sub! /(&lt;)(\w+)(@)/, 
                  '\1<span class="missing">\2</span>\3'
              end

              if person.asf_member?
                # have members show up in bold
                line.sub! /(#{s}\s+)(.*?)(\s+&)/, 
                  '\1<strong title="ASF member">\2</strong>\3'
              end
              line
            end
          end

          if report.title =~ /Change (.*?) Chair/
            pmc = $1
            committee = ASF::Committee.find(pmc)
            text.sub! "Apache #{pmc}", 
              "<a href='/roster/committee/#{committee.name}'>Apache #{pmc}</a>"
            committee.members.each do |person|
              simple_name = person.public_name.sub(/ .* /,' ')
              if person.asf_member?
                sub = Proc.new do |name|
                  "<a href='/roster/committer/#{person.id}' title='ASF Member'><strong>#{name}</strong></a>&#65279;"
                 end
              else
                sub = Proc.new do |name|
                  "<a href='/roster/committer/#{person.id}'>#{name}</a>&#65279;"
                end
              end
              begin
                text.sub! person.public_name, &sub
                text.sub! simple_name, &sub if simple_name != person.public_name
              rescue
              end
            end
          end

          if report.title == 'Incubator'
            text.sub! /^---+ Detailed Reports ---+/, '------'
            text.gsub! /\n+\n---+\n+(\w.*?)( \(|\n)/ do |match|
              name = $1
              file = name.gsub(/\W/,'_').untaint
              if File.exist? "/var/www/board/minutes/#{file}.html"
                match.sub(name, "<a href='/board/minutes/#{file}.html'>#{name}</a>")
              else
                match.sub(name, "<b>#{name}</b>")
              end
            end
            text.gsub! /\n+\n---+\n/, "\n\n<hr/>\n"
          end

          _{text.untaint}
        end

        unless report.comments.to_s.empty?
          _label 'Comments', for: 'comments'
          text = CGI.escapeHTML(report.comments).gsub(uri_in_text) do
            pre, link = $1, $2
            "#{pre}<a href=\"#{link.gsub("&amp;amp;", "&amp;")}\">#{link}</a>"
          end
          _pre.comments! do
            _{text.untaint}
          end
        end

        # paste report
        if report.text.to_s.empty? and report.attach =~ /^(\d+|[A-Z]+)$/
          _div.paste_popup! title: "#{report.title} report" do
            _form do
              _textarea.report! comments[report.attach], name: 'report',
                cols: 80, rows: 100 
            end
          end

          _p { _button.paste_report! "Paste report" }

          _script %{
            $("#paste_popup").dialog({
              autoOpen: false,
              height: 400,
              width: 600,
              modal: true,
              buttons: {
                Reflow: function() {
                  text = $('textarea', this).val();
                  text = text.replace(/([^\\s>])\\n(\\w)/g, '$1 $2');
                  lines = text.split("\\n");
                  for (var i=0; i<lines.length; i++) {
                    var indent = lines[i].match(/( *)(.?.?)(.*)/m);
                    if (indent[1] == '' || indent[3] == '') {
                      lines[i] = lines[i].
                        replace(/(.{1,78})( +|$\\n?)|(.{1,78})/g, "$1$3\\n").
                        replace(new RegExp("[\\n\\r]+$"), '');
                    } else {
                      var n = 76 - indent[1].length;
                      var regexp =
                        new RegExp("(.{1,"+n+"})( +|$\\n?)|(.{1,"+n+"})", 'g');
                      lines[i] = indent[3].
                        replace(regexp, indent[1] + "  $1$3\\n").
                        replace(indent[1] + '  ', indent[1] + indent[2]).
                        replace(new RegExp("[\\n\\r]+$"), '');
                    }
                  }
                  $('textarea', this).val(lines.join("\\n"));
                },
                Commit: function() {
                  var form = $(this);
                  var params = { 
                    attach: #{report.attach.inspect},
                    report: $('textarea', this).val(),
                    message: prompt("Commit Message?", 
                      "#{report.title} Report"),
                  };

                  if (!params.message) return false;

                  $.post(#{ENV['SCRIPT_NAME'].inspect}, params, function(_) {
                    $('#paste_popup').hide();
                    $('#paste_report').hide();
                    $('#text').text(params.report);
                    form.dialog("close");
                  }, 'json');
                }
              }
            });

            $("#paste_report").click(function() {
              $("#paste_popup").dialog('open');
            });
          }
        end

        # comment pop-up form
        add_or_edit = comments[report.attach] ? 'Edit' : 'Add a'
        _div.comment_popup! title: "#{add_or_edit} comment" do
          _form do
            _label 'Initials:', for: 'initials'
            _input.initials! name: 'initials', value: director ||
              user.public_name.split.map {|word| word[0]}.join.downcase
            _textarea.comment! comments[report.attach], name: 'comment',
              cols: 50, rows: 5, autofocus: true
          end
        end

        # comment and approval buttons
        _p.comments do
          _button.add_comment! "#{add_or_edit} comment"

          if director and report.comments
            if report.approved and not report.text.empty?
              if !report.approved.to_s.split(/[ ,]+/).include? director
                if approved.include? report.attach
                  _button.approve! 'Unapprove'
                else
                  _button.approve! 'Approve'
                end
              end
            end
          end
        end

        # wire up the form and buttons
        _script %{
          $("#comment_popup").dialog({
            autoOpen: false,
            height: 295,
            width: 600,
            modal: true,
            open: function() { $('textarea', this).focus() },
            buttons: {
              "Commit": function() {
                var form = $(this);
                var params = { 
                  attach: #{report.attach.inspect},
                  comment: $('textarea', this).val(),
                  initials: $('#initials').val()
                };

                if (#{!director}) {
                  params.message = prompt("Commit Message?", 
                    "Comment on #{report.title} report");
                  if (!params.message) return false;
                }

                $.post(#{ENV['SCRIPT_NAME'].inspect}, params, function(_) {
                  var text;
                  if (params.comment == '' || #{!director}) {
                    text = 'Add a comment';
                  } else {
                    text = 'Edit comment';
                  }
                  $('#add_comment').text(text)
                  $('#ui-dialog-title-comment_popup').text(text)
                  form.dialog("close");
                }, 'json');
              }
            }
          });

          $("#add_comment").click(function() {
            $("#comment_popup").dialog('open');
          });

          $("#approve").click(function() {
            var button = $(this);
            var params = { 
              request: button.text(),
              attach: #{report.attach.inspect}
            };

            $.post(#{ENV['SCRIPT_NAME'].inspect}, params, function(_) {
              $('h1').attr('class', _.class);
              if (button.text() == 'Approve') {
                button.text('Unapprove');
              } else {
                button.text('Approve');
              }
            }, 'json');
          });
        }

        # notes (editable by secretary only, for everybody else static)
        if secretary
          _p do
            _label 'Notes', for: 'notes'
            notes = agenda.notes[report.title]
            if ['Roll Call', 'Discussion Items', 
                'Review Outstanding Action Items'].include? report.title
              notes ||= report.text.gsub(/ \(expected.*?\)/, '').
                sub /^ +ASF members are welcome to attend board meetings.*?\n\n/m, ''
            end
            _textarea.notes! notes.to_s.sub(/\A\s*\n/,'').gsub(/^\s+\n/, "\n"), 
              name: 'notes',
              cols: 80, rows: [20, notes.to_s.split("\n").length+2].max
          end
          _input type: :submit, value: 'Update'
          
          # Buttons for common notes
          if agenda.notes[report.title].to_s.empty?
            if report.attach =~ /3\w/
              _input type: 'submit', value: 'Approve', onclick:
                "document.getElementById('notes').value='approved'"
            end
            if report.attach =~ /7\w/
              _input type: 'submit', value: 'Unanimous', onclick:
                "document.getElementById('notes').value='unanimous'"
              _input type: 'submit', value: 'Tabled', onclick:
                "document.getElementById('notes').value='tabled'"
            end
            if report.text.to_s.strip.empty? and not report.shepherd.to_s.empty?
              _input type: 'submit', value: "AI:#{report.shepherd}",
                 onclick: "document.getElementById('notes').value=" +
                "'@#{report.shepherd} to pursue a report for #{report.title}'"
            end
            if ['1.','13.'].include? report.attach
              _input type: 'submit', value: 'Timestamp', onclick:
                "document.getElementById('notes').value=" +
                "new Date().toLocaleTimeString()." +
                "split(':').slice(0,2).join(':')"
            end
          end
        elsif not agenda.notes[report.title].to_s.empty?
          _label 'Secretary Notes', for: 'notes'
          _pre.notes! do
            _{CGI.escapeHTML(agenda.notes[report.title]).
              gsub(/^\s*(@\w+ .*)/, '<span class="ai">\1</span>').
              gsub(/\n+\z/, "\n").
              gsub(/\A\n/, "").untaint}
          end
        end
      end

      # Misc links: Roster and Prior Reports
      if report.attach =~ /^(4[A-Z]|\d+|[A-Z][A-Z]?)$/
        _p do
          title = report.title
          title = 'stdcxx' if title == 'C++ Standard Library'
          unless report.attach =~ /^4[A-Z]$/
            _a 'Roster', href: "/roster/committee/#{CGI.escape title}"
          end
          _a 'Prior Reports', href: "/board/minutes/#{title.gsub(/\W/,'_')}"
        end
      end

      # previous and next links
      index = agenda.order.index(attach)
      if index > 0
        _a.backlink agenda.at(index-1).title,
           href: agenda.at(index-1).link, accesskey: '-'
      end
      if index < agenda.order.length-1
        _a.nextlink agenda.at(index+1).title,
           href: agenda.at(index+1).link, accesskey: '+'
      end

    elsif secretary and ENV['REQUEST_URI'] =~ /\/calendar_summary$/

      ############################################################ 
      #                      Calendar Entry                      #
      ############################################################ 

      text = []
      date =  Date.parse(agenda.filename[/(\d+_\d+_\d+)/,1].gsub('_','-'))
      text << "- [#{date.strftime("%d %B %Y")}]" +
        "(../records/minutes/#{date.strftime("%Y")}/" +
        "board_minutes_#{date.strftime("%Y_%m_%d")}.txt)"
      text << ''
      agenda.order.each do |attach|
        next unless attach =~ /7[A-Z]/
        text << "    * #{agenda[attach].title.
          gsub(/(.{1,76})(\s+|$)/, "\\1\n      ").strip}"
      end
      _h2 do
        _ 'To be added to'
        _a 'calendar.mdtext', href: 'https://svn.apache.org/repos/asf/infrastructure/site/trunk/content/foundation/board/calendar.mdtext'
        _ ':'
      end
      _form action: '../../publish_minutes', method: 'post' do
        _textarea text.join("\n"), name: 'summary',
          cols: 80, rows: text.length+2
        _p
        _input name: 'message', size: 48,
          value: "Publish #{date.strftime("%d %B %Y")} minutes"
        _button 'Commit', type: 'submit'
      end

    elsif ENV['REQUEST_URI'] =~ /\/preapps$/

      ############################################################ 
      #                       Pre-approvals                      #
      ############################################################ 

      _h1 'Pre-approvals'

      all_approvals = agenda.
        select {|key,value| key =~ /^([A-Z]+|[0-9]+|3[A-Z])$/}.
        map { |key,report| report.approved.to_s.strip.split(/[, ]+/) }

      _h2.subtitle 'By Number of Approvals'

      _table do
        _tr do
          _th 'reports'
          _th 'approvals'
        end

        reports = all_approvals.map(&:length).group_by(&:to_i)

        reports.sort.each do |length, count|
          _tr align: 'center' do
            _td count.length
            _td length
          end
        end
      end

      _h2.subtitle 'By Director'

      _table do
        _tr do
          _th 'count'
          _th 'initials'
          _th 'name'
        end

        approvers = all_approvals.flatten.group_by(&:to_s).
          map { |name, approvals| [approvals.length,name]}

        approvers.sort.each do |count, name|
          person = ASF::Person.find(DIRECTORS.invert[name])
          _tr align: 'center' do
            _td count
            _td name
            if person.icla?
              _td align: 'left' do
                _a person.public_name, href: "/roster/committer/#{person.id}"
              end
            else
              _td {_em 'unknown'}
            end
          end
        end
      end

      _footer do
        _ul do
          _li {_a 'Agenda', href: '.'}
          _li {_a 'Comments', href: 'comments'}
          _li {_a 'Notes', href: 'notes'} unless agenda.notes.empty?
        end
      end

    elsif ENV['REQUEST_URI'] =~ /\/comments$/

      ############################################################ 
      #                     Report Comments                      #
      ############################################################ 

      _h1 'Report Comments'

      # full details
      agenda.order.map {|attach| agenda[attach]}.each do |report|
        next if report.comments.to_s.strip.empty?
        _h2 do
          _a report.title, href: report.link
        end
        _pre do
          text = CGI.escapeHTML(report.comments.sub(/\A\n+/,''))

          # make links in text active
          text.gsub!(uri_in_text) do
            pre, link = $1, $2
            "#{pre}<a href=\"#{link.gsub("&amp;amp;", "&amp;")}\">#{link}</a>"
          end
          text.gsub! /(\s)(s\.apache\.org\/\w+)/, '\1<a href="http://\2">\2</a>'

          _{text}
        end
      end

    elsif ENV['REQUEST_URI'] =~ /\/notes$/

      ############################################################ 
      #                   Aggregate notes page                   #
      ############################################################ 

      _h1 'Meeting Notes'
      _a 'View/hide details', onclick: "toggleReport()"

      # full details
      _div.report! do
        agenda.order.map {|attach| agenda[attach]}.each do |report|
          next if agenda.notes[report.title].to_s.empty?
          _h2 do
            _a report.title, href: report.link
          end
          _pre do
            _{CGI.escapeHTML(agenda.notes[report.title]).
              gsub(/^\s*@(\w+ .*)/, '<span class="ai">AI: \1</span>').
              gsub(/\n+\z/, "\n").
              gsub(/\A\n/, "").untaint}
            end
        end
      end

      _div.buttons do
        link = "/board/draft-minutes/#{agenda.filename[/(\d[\d_]+)/,1]}"
        if File.exist? agenda.filename.sub('_agenda_','_minutes_')
          _form action: link do
            _button 'Show minutes', type: 'submit'
          end
          if secretary
            _form action: 'calendar_summary' do
              _button 'Publish Minutes', type: 'submit'
            end
          end
        else
          _form action: link do
            _button 'Draft minutes', type: 'submit'
          end
        end
      end

      _ul do
        _li {_a 'Pre-approvals', href: 'preapps'}
        _li {_a 'Comments', href: 'comments'}
      end
 
      # List of action items (generated dynamically from the full list)
      _div.ais!
      _script! %{
        $('#ais').toggle();

        function toggleReport() {
          if ($('#ais').children().length == 0) {
            var ais = $('.ai');
            var ul = $('<ul></ul>');
            for (var i=0; i < ais.length; i++) {
              ul.append($('<li></li>').text($(ais[i]).text().
                replace(/^AI: /, '')));
            }

            $('#ais').append($('<h2>Action Items</h2>'));
            $('#ais').append(ul);
          }

          $('#report').toggle();
          $('#ais').toggle();
        }
      }

    elsif not link.empty?
      # Report requested and not found.
      raise "Not found: #{link}"
    else

      ############################################################ 
      #                    Overall index page                   #
      ############################################################ 

      # If requested, reload agenda from svn
      if (secretary or director) and _.post? and (@svnup or @svncommit)
        File.open(agenda.filename, 'r') do |file|
          file.flock(File::LOCK_EX)

          Dir.chdir SVN_FOUNDATION_BOARD do
            _div.shell do
              _.system "svn up"

              if @svncommit
                apply_comments agenda.filename, UPDATE_FILE, director
                _.system [
                  'svn', 'commit', '-m', @message, 
                  File.basename(agenda.filename),
                  ['--no-auth-cache', '--non-interactive'],
                  (['--username', $USER, '--password', $PASSWORD] if $PASSWORD)
                ]

                File.rename UPDATE_FILE, UPDATE_FILE.sub('.yml', '.bak')
              end
            end
          end

          load_agenda.call
        end
      end

      # Header
      _h1 do
        meeting = File.basename(agenda.filename)
        _a "ASF Board Agenda #{meeting[/(\d[\d_]+)/,1].gsub('_','-')}",
          href: "https://svn.apache.org/repos/private/foundation/board/#{meeting}"
      end

      # Index of reports
      _table_ do
        _tr do
          _th 'Attach'
          _th 'Title'
          _th 'Author'
          _th 'Shepherd'
        end
        agenda.order.each do |attach|
          report = agenda[attach]
          _tr_ class: report.status do
            _td attach
            _td do
              _a report.title, href: report.link
            end
            _td report.author
            _td report.shepherd
          end
        end
      end

      # Miscellaneous buttons: Draft minutes, Update agenda
      _div.buttons do
        unless agenda.notes.empty?
          link = "/board/draft-minutes/#{agenda.filename[/(\d[\d_]+)/,1]}"
          if File.exist? agenda.filename.sub('_agenda_','_minutes_')
            _form action: link do
              _button 'Show minutes', type: 'submit'
            end
            if secretary
              _form action: 'calendar_summary' do
                _button 'Publish minutes', type: 'submit'
              end
            end
          else
            _form action: link do
              _button 'Draft minutes', type: 'submit'
            end
          end
        end

        if secretary or director
          _form.buttons method: 'post' do
            _button 'Update agenda', type: 'submit', name: 'svnup'

            unless approved.empty? and comments.empty?
              _button 'Commit changes', type: 'submit', name: 'svncommit'

              message = []
              unless approved.empty?
                message << "#{approved.length} reports approved"
              end
              unless comments.empty?
                message << "#{comments.length} comments"
              end
              message = message.join(' and ').gsub(/\b(1 \w+)s\b/, '\1')
              _input name: 'message', id: 'message', type: 'hidden',
                value: message, 'data-value' => message
            end
          end

          _script %{
            // Commit prompt
            $("button[name=svncommit]").click(function() {
              var message = prompt("Commit Message?", $('#message').
                attr('data-value'));
              if (message) {
                $('#message').attr('value', message);
                return true;
              } else {
                return false;
              }
            });
          }
        end
      end

      # Other Board Meeting Agendas
      agendas = Dir["#{SVN_FOUNDATION_BOARD}/board_agenda_*.txt"]
      agendas.delete agenda.filename
      if agendas.length > 0
        _footer_ do
          _h2 'Other Board Meeting Agendas'
          _ul do
            agendas.sort.reverse.each do |agenda|
              link = agenda[/(\d[\d_]+)/,1] + '/'
              link = '../' + link if ENV['REQUEST_URI'] =~ /\d\//
              _li! {_a File.basename(agenda), href: link}
            end
          end
        end
      end
    end
  end
end

_json do
  commit = false

  if @attach and @comment

    if @comment.strip.empty?
      comments.delete @attach
    else
      comments[@attach] = @comment
    end

    if director
      _status 'ok'
    else
      commit = true
    end

  elsif @attach and @request

    if @request.downcase == 'approve'
      approved << @attach

      load_agenda.call if agenda.empty?
      report = agenda[@attach]
      if report.approved.to_s.strip.split(/[, ]+/).length < 5
        _class 'ready'
      elsif report.comments.to_s.strip.size > 0
        _class 'commented'
      else
        _class 'approved'
      end
    else
      approved.delete @attach
      _class 'ready4me'
    end

  elsif @attach and @report
    commit = true
  end

  File.open(UPDATE_FILE, 'w') do |file|
    YAML.dump({'approved' => approved, 'comments' => comments}, file)
  end

  if commit
    Dir.chdir SVN_FOUNDATION_BOARD do
      File.open(agenda.filename, 'r+') do |file|
        file.flock(File::LOCK_EX)
        _up `svn up`

        if @report
          contents = file.read
          contents[/^Attachment #{@attach}:.*\n()/, 1] = "\n#{@report}"
          file.seek(0)
          file.write(contents)
          file.close()
        else
          apply_comments agenda.filename, UPDATE_FILE, @initials
          File.rename UPDATE_FILE, UPDATE_FILE.sub('.yml', '.bak')
        end

        cmd = ['svn', 'commit', '-m', @title || 'board agenda tool']
        cmd += ['--no-auth-cache', '--non-interactive']
        cmd += ['--username', $USER, '--password', $PASSWORD] if $PASSWORD
        _commit `#{Shellwords.join(cmd).untaint}`
      end
    end
  end
end
