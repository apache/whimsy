#!/usr/bin/ruby1.9.1
require 'wunderbar'
require 'open3'
require './local_paths'
require 'fileutils'
require 'ostruct'
require 'escape'

ENV['LANG'] = 'en_US.UTF-8'

def html_fragment(&block)
  x = Wunderbar::HtmlMarkup.new({})
  x.instance_eval(&block)
  x._.target!.join
end

def asciize(name)
  if name.match /[^\x00-\x7F]/
    # digraphs.  May be culturally sensitive
    name.gsub! /\u00df/, 'ss'
    name.gsub! /\u00e4|a\u0308/, 'ae'
    name.gsub! /\u00e5|a\u030a/, 'aa'
    name.gsub! /\u00e6/, 'ae'
    name.gsub! /\u00f1|n\u0303/, 'ny'
    name.gsub! /\u00f6|o\u0308/, 'oe'
    name.gsub! /\u00fc|u\u0308/, 'ue'

    # latin 1
    name.gsub! /[\u00e0-\u00e5]/, 'a'
    name.gsub! /\u00e7/, 'c'
    name.gsub! /[\u00e8-\u00eb]/, 'e'
    name.gsub! /[\u00ec-\u00ef]/, 'i'
    name.gsub! /[\u00f2-\u00f6]|\u00f8/, 'o'
    name.gsub! /[\u00f9-\u00fc]/, 'u'
    name.gsub! /[\u00fd\u00ff]/, 'y'

    # Latin Extended-A
    name.gsub! /[\u0100-\u0105]/, 'a'
    name.gsub! /[\u0106-\u010d]/, 'c'
    name.gsub! /[\u010e-\u0111]/, 'd'
    name.gsub! /[\u0112-\u011b]/, 'e'
    name.gsub! /[\u011c-\u0123]/, 'g'
    name.gsub! /[\u0124-\u0127]/, 'h'
    name.gsub! /[\u0128-\u0131]/, 'i'
    name.gsub! /[\u0132-\u0133]/, 'ij'
    name.gsub! /[\u0134-\u0135]/, 'j'
    name.gsub! /[\u0136-\u0138]/, 'k'
    name.gsub! /[\u0139-\u0142]/, 'l'
    name.gsub! /[\u0143-\u014b]/, 'n'
    name.gsub! /[\u014C-\u0151]/, 'o'
    name.gsub! /[\u0152-\u0153]/, 'oe'
    name.gsub! /[\u0154-\u0159]/, 'r'
    name.gsub! /[\u015a-\u0162]/, 's'
    name.gsub! /[\u0162-\u0167]/, 't'
    name.gsub! /[\u0168-\u0173]/, 'u'
    name.gsub! /[\u0174-\u0175]/, 'w'
    name.gsub! /[\u0176-\u0178]/, 'y'
    name.gsub! /[\u0179-\u017e]/, 'z'

    # denormalized diacritics
    name.gsub! /[\u0300-\u036f]/, ''
  end

  name.gsub /[^\w]+/, '-'
end

SUFFIXES = /^([Jj][Rr]\.?|I{2,3}|I?V|VI{1,3}|[A-Z]\.)$/

# rearrange name in an order suitable for sorting
def lname(name)
  name = name.split.reverse
  suffix = (name.shift if name.first =~ SUFFIXES)
  suffix += ' ' + name.shift if name.first =~ SUFFIXES
  name << name.shift
  name << name.shift if name.first=='Lewis' and name.last=='Ship'
  name << name.shift if name.first=='Gallardo' and name.last=='Rivera'
  name << name.shift if name.first=="S\u00e1nchez" and name.last=='Vega'
  # name << name.shift if name.first=='van'
  name.last.sub! /^IJ/, 'Ij'
  name.unshift(suffix) if suffix
  name.map! {|word| asciize(word)}
  name.reverse.join(' ')
end

# rearrange name in an order suitable for sorting
def icla_lname(line)
  return '' unless line =~ /^\w.*?:(.*?):(.*?):(.*?)(:(.*))?\n/
  lname($1)
end

def update_pending fields, dest
  # start with the fields provided
  fields = Hash[fields]

  # reject blank fields, normalize the rest
  fields.reject! {|k,v| v == [""]}
  fields.each_key {|k| fields[k]=fields[k].join(' ')}

  # add properties from svn
  at = svn_at(dest)
  at += '/*' if File.directory?(dest) and `svn proplist #{dest}#{at}`.empty?
  `svn proplist #{dest}#{at}`.scan(/  \w+:[-\w]+/).each do |prop|
    prop.untaint if prop.strip =~ /^\w+(:\w+)/
    value = `svn propget #{prop} #{dest}#{at}`.chomp
    value.gsub!(/\\x[0-9a-fA-F][0-9a-fA-F]/) {|c| [c[2..3].to_i(16)].pack('C')}
    value.gsub!(/\\[0-7][0-7][0-7]/) {|c| [c[1..3].to_i(8)].pack('C')}
    fields[prop.strip] = value
  end

  # copy email field
  fields['email'] ||= fields['gemail'] || fields['cemail'] ||
                      fields['nemail'] || fields['memail']
  fields.delete('email') unless fields['email']
  
  # Concatenate the fields to the pending list and write to disk
  pending = YAML.load(open(PENDING_YML)) rescue []
  pending << fields
  open(PENDING_YML, 'w') {|file| file.write pending.to_yaml}
end

class Wunderbar::XmlMarkup
  def move source, dest
    if Dir.chdir(RECEIVED) {Dir['*']}.include? source.chomp('/')
      @_builder.tag! :pre, "svn mv #{source.inspect} #{dest}", class: 'stdin'
      @_builder.tag! "File #{source} doesn't exist.", class: 'stderr'
      return
    end

    source = File.expand_path(source, RECEIVED).untaint
    source += svn_at(source)

    if File.exist?(dest) and !File.directory?(dest)
      # Since svn error messages aren't as helpful as they could be here,
      # let's improve on it... by pretending to run the command and then
      # producing a better error message.
      @_builder.tag! :pre, "svn mv #{source.inspect} #{dest}", class: 'stdin'
      @_builder.tag! "File #{dest} already exists.", class: 'stderr'
    else
      if (`svn --version --quiet`.chomp.split('.') <=> %w(1 5)) >= 1
        self.system "svn mv #{source.inspect} #{dest}"
      else
        if `svn st #{source.inspect}` =~ /^A/
          self.system "cp #{source.inspect} #{dest}"
          self.system "svn add #{dest}"
          `svn proplist #{source.inspect}`.scan(/  \w+:[-\w]+/).each do |prop|
            prop.untaint if prop.strip =~ /^\w+(:\w+)/
            value = `svn propget #{prop.strip} #{source.inspect}`.chomp
            self.system "svn propset #{prop.strip} #{value.inspect} #{dest}"
          end
          self.system "svn revert #{source.inspect}"
        elsif `svn st #{source.inspect}` !~ /^D/
          self.system "svn mv --force #{source.inspect} #{dest}"
        end
      end
      self.system "svn rm #{dest}/Thumbs.db" if File.exist?("#{dest}/Thumbs.db")
    end
  end
end

def check
  email = {}
  prev_name = nil
  output = []

  open("#{OFFICERS}/iclas.txt").each do |line|
    next unless line =~ /^\w.*?:(.*?):(.*?):(.*?)(:(.*))?\n/
    name = $1
 
    if ! $3.index('@')
      output << [ 'email', "#{$1}: #{$3}" ]
    elsif ! $4 or  ! $4.index('CLA')
      output << [ 'nocla', $2 ]
    elsif email[$3.downcase]
      output << [ 'dupemail', "#{$3}: #{name} and #{email[$3.downcase]}" ]
    end
 
    email[$3.downcase] = name

    name.split.each do |word|
      next if word.length == 1 and word !~ /\w/
      next if word =~ /^\W/
      next if %w(van von da de del der den dos i).include? word
      output << ['case', name] if word !~ /[A-Z][a-z]*/
    end

    sort_name = icla_lname(line)
    if prev_name and prev_name > sort_name
      output << [ 'order', "#{prev_name} > #{sort_name}" ]
    end
    prev_name = sort_name
  end

  html_fragment do
    if output.empty?
      _p 'No icla.txt issues.'
    else
      _h3 'icla.txt issues'
      _table border: 1, cellpadding: 10, cellspacing: 0 do
        _thead do
          _th 'issue'
          _th 'name'
        end
        output.each do |type, message|
          _tr do
            _td type
            _td message
          end
        end
      end
    end
  end
end

def svn_info(source)
  source.untaint if Dir.chdir(RECEIVED) {Dir['*']}.include? source.chomp('/')
  source = File.join(RECEIVED, source)
  source += svn_at(source)
  info = {
    'from' =>  `svn propget email:name #{source}`.chomp,
    'email' => `svn propget email:addr #{source}`.chomp
  }

  if info['from'].empty? and info['email'].empty?
    log=`svn log -l 9 #{source}`
    from=log.scan(/\nFrom: (.*)/).flatten.first

    if from and from !~ /"eFax"/
      email = from.gsub(/.*<(.*)>$/, '\1')
      info['email'] = email if email.include?('@')
    
      from.gsub! /\s<.*>$/, ''
      from.gsub! /^"(.*)"$/, '\1'
      info['from'] = from unless from.include?('@')
    end
  end

  info.each do |name, value| 
    value.gsub!(/\\x[0-9a-fA-F][0-9a-fA-F]/) {|c| [c[2..3].to_i(16)].pack('C')}
    value.force_encoding('utf-8')
    value.force_encoding('iso-8859-1') unless value.valid_encoding?
  end

  info
end

def email(target, message)
  pending = YAML.load(open(PENDING_YML))

  require MAIL if defined?(MAIL)
  require 'erb'

  mails = []
  pending.each do |pending_hash|
    next unless pending_hash['email'] == target

    vars = OpenStruct.new(pending_hash.map {|k,v| 
      [k.gsub(/\W/,'_'), v.dup.untaint]
    })
    vars.commit_message = message

    # send email, if template exists
    template = vars.doctype + '.erb'
    template.untaint if template =~ /^[.\w]+/
    if defined?(MAIL) and File.exist?(template)

      # extract fields from the Mail defaults
      Mail.defaults do
        vars.sig  = instance_eval {@sig.gsub(/^ +/,'').strip}
        vars.from = instance_eval {@from}
        vars.bcc  = instance_eval {@bcc}
      end

      # expand template
      def vars.get_binding
        binding
      end
      message = ERB.new(open(template).read.untaint).result(vars.get_binding)
      headers = message.slice!(/\A(\w+: .*\r?\n)*(\r?\n)*/)

      mail = Mail.new do
        # apply headers
        headers.scan(/(\w+):[ \t]*(.*)/).each do |name, value|
          send name, value unless value.empty?
        end

        body message

        # is this a reply?
        if vars.email_id
          in_reply_to vars.email_id
          references  vars.email_id

          # override subject?
          if vars.email_subject and !vars.email_subject.empty?
            if vars.email_subject =~ /^re:\s/i
              subject vars.email_subject
            else
              subject 'Re: ' + vars.email_subject
            end
          end
        end
      end

      # get the list of cc's as an array
      cc = mail.cc.to_a

      # eliminate the legal-archive from the cc list
      cc.reject! {|addr| addr =~ /\blegal-archive@apache\.org\b/}

      # add additional cc if email:addr != email
      if vars.email_addr and !vars.email_addr.include?(mail.to.to_s)
        if vars.email_name
          cc << "#{vars.email_name.inspect} <#{vars.email_addr}>"
        else
          cc << vars.email_addr
        end
      end

      # add original cc list
      cc << vars.email_cc if vars.email_cc

      # add pmc and podling lists, if supplied
      cc << "private@#{vars.pmc}.apache.org" if vars.pmc
      cc << "#{vars.podling}-private@incubator.apache.org" if vars.podling
      cc << "private@incubator.apache.org" if vars.podling and not vars.pmc

      # replace the list of cc's
      mail.cc = cc.uniq.join(', ')

      # update bcc
      if vars.email_bcc and not vars.email_bcc.empty?
        bcc = mail.bcc.to_s.split(/,\s*/)
        bcc += vars.email_bcc.to_s.split(/,\s*/)
        mail.bcc = bcc.uniq.join(', ')
      end

      # for debugging purposes
      mails << [vars.email, mail.to_s]

      # ship it!
      mail.deliver!

      completed = YAML.load(open(COMPLETED_YML)) rescue []
      completed << pending_hash
      open(COMPLETED_YML, 'w') {|file| file.write completed.pop(10).to_yaml}

      # clean up pending list
      pending.delete pending_hash

      if pending.empty?
        FileUtils.rm_f PENDING_YML
      else
        open(PENDING_YML, 'w') {|file| file.write pending.to_yaml}
      end
    end
  end

  html_fragment do
    mails.each do |dest, mail|
      _h2 "email #{dest}"
      _pre.email mail
    end
  end
end

def committable
  files = %W( #{FOUNDATION}/Correspondence/JCP/tck-nda-list.txt )
  if defined?(MEETING)
    files += %W(#{MEETING}/memapp-received.txt #{FOUNDATION}/members.txt)
  end
  files += [DOCUMENTS, OFFICERS]
end

_json do
  if @cmd == 'svninfo'
    _! svn_info(@source)
  elsif @cmd == 'icla.txt issues'
    _html check
  elsif @cmd =~ /email (.*)/
    _html email $1, @message
  elsif @cmd =~ /svn (update|revert -R|cleanup)/ and committable.include? @file
    op, file = $1.split(' '), @file
    _html html_fragment {
      _.system [ 'svn', *op, file ]
    }
  elsif @cmd =~ /svn commit/ and committable.include? @file
    message, file = @message, @file
    _html html_fragment {
      _.system [
        'svn', 'commit', '-m', message, '--no-auth-cache',
        (['--username', $USER, '--password', $PASSWORD] if $PASSWORD),
        file
      ]
    }
  else
    cmd = @cmd
    _html html_fragment { 
      _pre._stdin cmd
      _pre._stderr 'Unauthorized command'
    }
  end
end

DESTINATION = {
  "Jim"       => "to_jim",
  "Sam"       => "to_sam",
  "Upayavira" => "to_upayavira",
  "dup"       => "deadletter/dup",
  "incomplete"=> "deadletter/incomplete"
}

exception = nil
line = nil

_html do
  _head_ do
    _title 'File Document'

    if ! %w{check update commit view}.include?(@action.to_s.downcase)
      _script 'parent.frames[0].location.reload()'
    end

    _style %{
      html {background-color: #F8F8FF}
      pre {font-weight: bold; margin: 0}
      pre._stdin, pre.todo {color: #C000C0; margin-top: 1em}
      .todo {opacity: 0.2}
      pre._stdout {color: #000}
      pre._hilite {color: #000; background-color: #FF0}
      pre._stderr {color: #F00}
      pre.email {background-color: #BDF; padding: 1em 3em}
      pre.email {border-radius: 1em}
      .traceback {background-color:#ff0; margin: 1em 0; padding: 1em;
        border: 2px solid}
      #notice {color: green}
      .collision {background-color: #ee82ee}
    }
  end

  _body? do

    activity_log = nil
    File.open "#{RECEIVED}/activity.yml", File::RDWR|File::CREAT, 0644 do |file|
      file.flock File::LOCK_EX
      activity_log = YAML.load(file.read) || []
      activity_log.unshift({'USER' => $USER, 'time' => Time.now.utc}.
        merge(Hash[params.map {|key,value| [key,value.first]}]))
      file.rewind
      file.write YAML.dump(activity_log[0...5])
      file.flush
      file.truncate file.pos
    end

    filename = [@filename, @cfilename, @gfilename, @mfilename, @nfilename].
      find {|name| name and not name.empty?}
    filename.untaint if filename and filename =~ /^[-.\w]+/
    doctype = (@doctype == 'mem' ? 'member_apps' : @doctype.to_s+'s')
    doctype.untaint if doctype =~ /^\w+$/
    dest = File.join(DOCUMENTS, doctype, filename.to_s)
    stem = ";#{filename.sub(/\.\w+$/,'').split('/').first}" if filename
    alax = false
    if @source and Dir.chdir(RECEIVED) {Dir['*']}.include? @source.chomp('/')
      @source.untaint
    end

    unless %w(clr rubys).include? $USER
      @action = 'welcome' unless @action == 'view'
    end

    case (@action || @doctype).to_s.downcase
    when 'welcome'
      _h1 "Welcome!"
      _p "This tools is for the Secretarial's team use only."
      _p %{
        Feel free to look around, but none of your actions will cause any
        files to be moved, updated, or any emails to be sent.
      }

    when 'icla'
      if @replaces != ''
        remove_id, remove_email = @replaces.strip.split(':',2)
      else
        remove_id, remove_email = 'notinavail', nil
      end

      insert = [
        remove_id, 
        @realname.strip, 
        @pubname.strip, 
        @email.strip, 
        "Signed CLA#{stem}\n"
      ].join(':')

      Dir.chdir(OFFICERS) do
        input = open('iclas.txt') {|file| file.to_a}
        open('iclas.txt','w') do |file|
          input.each do |line|
            if insert and icla_lname(line) >= icla_lname(insert)
              if insert.split(':',2).last != line.split(':',2).last
                file.print insert
              end
              insert = nil
            end
            fields = line.split(':')
            next if fields[0] == remove_id and fields[3] == remove_email
            file.print line
          end
          file.print insert if insert
        end

        _h1 @pubname
        if @source=~/[^\x00-\x7F]/ and RUBY_PLATFORM=~/darwin/i
          require 'unicode'
          @source = Unicode.normalize_KC(@source)
        end
        _.move @source, dest
        _.system "svn diff iclas.txt", hilite: @pubname
      end

      update_pending params, dest

    when 'grant'
      insert = "#{@from.strip}" +
        "\n  file: #{dest.split('/').last}" +
        "\n  for: #{@description.strip.gsub(/\r?\n\s*/,"\n       ")}"

      Dir.chdir(OFFICERS) do
        input = open('grants.txt') {|file| file.read}
        marker = "\n# registering.  documents on way to Secretary.\n"
        input = input.split(marker).insert(1,"\n#{insert}\n",marker)
        open('grants.txt','w') do |file|
          file.write(input.join)
        end

        _h1 "Grant"
        _.move @source, dest
        _.system "svn diff grants.txt", hilite: insert.split("\n")
      end

      update_pending params, dest

    when 'ccla'
      insert = "notinavail:" + @company.strip
       
      unless @contact.empty?
        insert += " - #{@contact.strip}"
      end

      insert += ":#{@cemail.strip}:Signed Corp CLA"

      unless @employees.empty?
        insert += " for #{@employees.strip.gsub(/\s*\n\s*/, ', ')}"
      end

      unless @product.empty?
        insert += " for #{@product.strip}"
      end

      Dir.chdir(OFFICERS) do
        open('cclas.txt','a') {|file| file.write(insert+"\n")}

        _h1 @pubname
        _.move @source, dest
        _.system "svn diff cclas.txt", hilite: insert
      end

      update_pending params, dest

    when 'nda'
      @realname ||= @nname

      _h1 "NDA for #{@realname}"
      _move @source, dest

      Dir.chdir(FOUNDATION) do
        ndalist = "Correspondence/JCP/tck-nda-list.txt"
        _.system "svn update #{ndalist}"
        text = open(ndalist).read
        open(ndalist, 'w') do |fh|
          fh.write(text)
          line = "#{@nname.ljust(20)} #{@nid.ljust(13)} "
          line += Date.today.strftime("%Y/%m/%d    ")
          line += `id -un`.chomp.ljust(10) + ' No TCK access yet'
          fh.write("#{line}\n")
        end
        _.system "svn diff #{ndalist}", hilite: @nid
      end

      update_pending params, dest

    when 'mem'
      @realname ||= @mfname
      dest.untaint if dest =~ /^[-.\w]+$/

      _h1 "Membership Application for #{@realname}"
      _.move @source, dest

      if defined?(MEETING)
        _.system "svn update #{MEETING}"
        received = open("#{MEETING}/memapp-received.txt").read
        begin
          received[/(no )\s+\w+\s+\w+\s+#{@mavailid}/,1] = 'yes'
        rescue
          _pre.stderr $!
        end
        open("#{MEETING}/memapp-received.txt", 'w') do |fh| 
          fh.write(received)
        end
        _.system "svn diff #{MEETING}/memapp-received.txt", hilite: @mavailid
      end

      _.system "svn update #{FOUNDATION}/members.txt"
      pattern = /^Active.*?^=+\n+(.*?)^Emeritus/m
      members_txt = open("#{FOUNDATION}/members.txt").read
      data = members_txt.scan(pattern).flatten.first
      members = data.split(/^\s+\*\)\s+/)
      members.shift

      members.push [
        "#{@mfname}",
        "#{@maddr.gsub(/^/,'    ').gsub(/\r/,'')}",
        ("    #{@mcountry}"     unless @mcountry.empty?),
        "    Email: #{@memail}",
        ("      Tel: #{@mtele}" unless @mtele.empty?),
        ("      Fax: #{@mfax}"  unless @mfax.empty?),
        " Forms on File: ASF Membership Application",
        " Avail ID: #{@mavailid}"
      ].compact.join("\n") + "\n"

      sorted = members.sort_by {|member| lname(member.split("\n").first)}
      members_txt[pattern,1] = " *) " + sorted.join("\n *) ")
      members_txt[/We now number (\d+) active members\./,1] = 
        members.length.to_s
      open("#{FOUNDATION}/members.txt",'w') {|fh| fh.write(members_txt)}

      _.system "svn diff #{FOUNDATION}/members.txt"

      update_pending params, dest

    when 'staple'
      _h1 'Staple'
      Dir.chdir(RECEIVED) do
        @source.sub! /\/$/, ''
        @source.untaint if Dir['*'].include? @source
        selected = params.keys.grep(/include\d+/)
        selected.map! {|key| "#{@source}/#{params[key].first}"}
        selected=Dir["#{@source}/*"] if selected.empty?
        cleanup = []

        # convert to pdf, if necessary
        sources = []
        selected.sort.each do |file|
          file.untaint if Dir["#{@source}/*"].include? file
          ext = file.split('.').last
          if ext.downcase == 'pdf'
            sources << file
          else
            cleanup << file.sub(Regexp.new(ext+'$'),'pdf').sub(' ', '_')
            sources << cleanup.last
            _.system(['convert', file, cleanup.last])
          end
        end

        dest,i = @source,0
        dest = @source + (i+=1).to_s while File.exist?("#{dest}.pdf")
        at = svn_at(@source)

        # concatenate sources
        if sources.length > 1
          _.system "pdftk #{sources.sort.join(' ')} cat output #{dest}.pdf"
          _.system "svn add #{dest}.pdf#{at}"
        elsif selected.first =~ /\.pdf$/i
          _.system "svn mv #{sources.first}#{at} #{dest}.pdf"
        else
          _.system "mv #{cleanup.shift} #{dest}.pdf"
          _.system "svn add #{dest}.pdf#{at}"
        end

        # copy properties
        sfx = at
        `svn proplist #{@source}#{sfx}`.scan(/  \w+:[-\w]+/).each do |prop|
          prop.untaint if prop.strip =~ /^\w+(:\w+)/
          value = `svn propget #{prop} #{@source}#{sfx}`.chomp
          _.system(['svn', 'propset', prop.strip, value, "#{dest}.pdf#{at}"])
        end
        _.system "svn propset svn:mime-type application/pdf #{dest}.pdf#{at}"

        # remove temporary file and source directory
        _.system "rm #{cleanup.join(' ')}" unless cleanup.empty?
        if not (Dir["#{@source}/*"]-selected).empty?
          selected.each do |file| 
            if `svn st #{file}` !~ /^D/ and File.exist? file
              _.system "svn rm --force #{file}" 
            end
          end
          if Dir["#{@source}/*"].empty?
            _.system "svn remove --force #{@source}#{at}"
          end
        elsif `svn st #{@source}#{at}` !~ /^D/ and File.exist? @source
          _.system "svn remove --force #{@source}#{at}"
        end
      end

    when 'cleanup'
      _h1 'Revert all and cleanup'

      committable.each do |file|
        status = `svn status #{file}`
        unless status.empty?
          status.scan(/^[?A]\s*\+?\s*(.*)/).flatten.each do |uncommitted|
            _.system ['rm', '-rf', uncommitted]
          end
          if status =~ /^\w/
            _pre.todo "svn revert -R #{file}", 'data-file' => file
          end
        end

        if File.directory? file
           _pre.todo "svn cleanup #{file}", 'data-file' => file
        end
      end

      if File.exist?(PENDING_YML)
        _.system "rm #{PENDING_YML}"
      end

      ajax=true

    when 'commit'
      _h1 'Commit'
      log = Escape.shell_single_word(@message)
      committable.each do |file|
        unless `svn status #{file}`.empty?
          _pre.todo "svn commit -m #{log} #{file}",
            'data-message' => @message, 'data-file' => file
        end
      end

      if File.exist?(PENDING_YML)
        pending = YAML.load(open(PENDING_YML))

        pending.each do |vars|
          _h2.todo "email #{vars['email']}", 'data-message' => @message
        end
      end

      ajax = true

    when 'other'
      at = svn_at(@source)
      Dir.chdir(RECEIVED) do
        if @dest == 'burst'
          _h1 'Burst'
          dest = @source.sub(/\.\w+$/,'')

          _.system "mkdir #{dest}"
          _.system "pdftk #{@source} burst output #{dest}/%02d.pdf"
          _.system "svn add #{dest}#{at}"
          # copy properties
          `svn proplist #{@source}#{at}`.scan(/ \w+:[-\w]+/).each do |prop|
             prop.untaint if prop.strip =~ /^\w+(:\w+)/
             next if prop.strip == 'svn:mime-type'
             value = `svn propget #{prop} #{@source}#{at}`.chomp
             _.system ['svn', 'propset', prop.strip, value, dest+at]
          end
          _.system "rm doc_data.txt" if File.exist? 'doc_data.txt'
          _.system "svn rm #{@source}#{at}"
        elsif @dest == 'flip'
          _h1 'Flip'
          _.system "pdftk #{@source} cat 1-endS output #{@source}.tmp"
          _.system "mv #{@source}.tmp #{@source}"
        elsif @dest == 'rotate right'
          _h1 'Rotate Right'
          _.system "pdftk #{@source} cat 1-endE output #{@source}.tmp"
          _.system "mv #{@source}.tmp #{@source}"
        elsif @dest == 'rotate left'
          _h1 'Rotate Left'
          _.system "pdftk #{@source} cat 1-endW output #{@source}.tmp"
          _.system "mv #{@source}.tmp #{@source}"
        elsif @dest == 'junk'
          _.system(['svn', 'rm', '--force', "#{@source}#{at}"])
        elsif DESTINATION.include? @dest
          _.move @source, DESTINATION[@dest]
        else
          pre.stderr "Unknown destination: #{@dest}"
        end
      end

    when 'update'
      _h1 'Update'
      _pre.todo "svn update #{OFFICERS}", 'data-file' => OFFICERS
      _pre.todo "svn update #{DOCUMENTS}", 'data-file' => DOCUMENTS
      _h3.todo 'icla.txt issues'
      ajax = true
      cleanup = Dir["#{DOCUMENTS}/members/received/*"].map(&:untaint).
        select {|name| File.directory?(name) and Dir["#{name}/*"].empty?}.
        reject {|name| name =~ /\/to_\w+$/}
      unless cleanup.empty?
        _h2 'Empty directories'
        _ul do
          cleanup.each { |name| _li name }
        end
      end

      _h2 'Recent Activity'
      _table border: 1, cellpadding: 5, cellspacing: 0 do
        _thead do
          _tr do
            _th 'Time'
            _th 'User'
            _th 'Action'
            _th 'Parameters'
          end
        end
        _tbody do
          activity_log[1..-1].each do |entry|
            collision = (entry['USER'] != $USER)
            collision &&= (Time.now-entry['time'] < 600)
            _tr_ class: ('collision' if collision) do
              _td entry.delete('time')
              _td entry.delete('USER')
              if entry['action']
                _td entry.delete('action')
              elsif entry['doctype'] == 'other'
                _td entry['dest']
              else
                _td entry['doctype']
              end
              entry.delete_if {|name, value| value.empty?}
              _td entry.inspect
            end
          end
        end
      end

    when 'view'
      @dir.untaint if Dir.chdir(RECEIVED) {Dir['*'].include? @dir.chomp('/')}
      files = Dir["#{RECEIVED}/#{@dir}/*"].sort

      if files.length == 2
        if files.last == files.first + '.sig'
          _pre `gpg --verify #{files.last} #{files.first} 2>&1`
        elsif files.last == files.first + '.asc'
          _pre `gpg --verify #{files.last} #{files.first} 2>&1`
        elsif files.last =~ /\/signature.asc$/
          _pre `gpg --verify #{files.last} #{files.first} 2>&1`
        elsif files.first =~ /\/signature.asc$/
          _pre `gpg --verify #{files.first} #{files.last} 2>&1`
        end
      end

      _form.buttons target: 'viewport', action: 'file.cgi', method: 'post' do
        _ul style: 'list-style: none; padding: 0' do
          files.each_with_index do |line,i|
            file = line.split('/').last
            _li do
              _input type: :checkbox, name: "include#{i}", value: file
              if %w(jpg).include?(file.split('.').last)
                _img src: "/members/received/#{@dir}/#{file}"
              else
                _a file, href: "/members/received/#{@dir}/#{file}"
              end
            end
          end
        end

        _input name: 'source', id: 'source', type: 'hidden', value: @dir

        if files.length > 0
          _input type: 'submit', name: 'action', value: 'Staple'
        else
          file = "#{RECEIVED}/#{@dir}"
          _pre `gpg --verify #{file} 2>&1`
          open(file) {|fh| _pre fh.read} 
        end

        _script src: "jquery-1.7.2.min.js"
        _script %{
          // first, check all of the checkboxes
          $('input[type=checkbox]').attr('checked', 'checked');

          // on click, unclick all if all are checked.
          $('input[type=checkbox]').mousedown(function() {
            if (!$('input[type=checkbox]:not(:checked)').length) {
              $('input[type=checkbox]').removeAttr('checked');
            }
          });
        }
      end

    when 'cancel', 'check'
      _h1 @action
      check
  
    when 'edit cc'
      _h1 @action

      if File.exist?(PENDING_YML)
        pending = YAML.load(open(PENDING_YML))

        if @email
          pending.each do |vars|
            if vars['email'] == @email
              vars['email:cc'] = @cc.strip.gsub(/\r?\n/, ", ") 
              vars['email:bcc'] = @bcc.strip.gsub(/\r?\n/, ", ") 
              vars.delete('email:bcc') if vars['email:bcc'].empty?

              open(PENDING_YML, 'w') {|file| file.write pending.to_yaml}
              _p.notice! "cc list for #{@email} updated"
            end
          end
        end

        pending.each do |vars|
          vars = OpenStruct.new(vars.map {|k,v| [k.gsub(/\W/,'_'),v]})
          _h2 "email #{vars.email}"
          _form do
            _input name: 'email', value: vars.email, type: 'hidden'
            _table do
              _tr do
                _td 'cc:'
                _td do
                  _textarea vars.email_cc.to_s.gsub(/,\s+/,"\n"),
                    name: 'cc', cols: 60
                end
              end
              _tr do
                _td 'bcc:'
                _td do
                  _textarea vars.email_bcc.to_s.gsub(/,\s+/,"\n"),
                    name: 'bcc', cols: 60
                end
              end
            end
            _input type: 'hidden', name: 'action', value: @action
            _input type: 'submit', value: 'Update'
          end
        end
      end
  
    else
      _h2 'Unsupported action'
      _table border: 1, cellpadding: 10, cellspacing: 0 do
        params.sort.each do |key, value|
          _tr do
            _td key
            _td value
          end
        end
      end
    end

    if ajax
      _script src: 'jquery-1.7.2.min.js'
      _script %{
        function execute_todos() {
          var todo = $('.todo:first');
          if (todo.length == 1) {
            // add a spinner
            var spinner = $('<img src="spinner.gif"/>');
            todo.after(spinner);

            // params = cmd plus all of the data-* attributes
            var params = {cmd: todo.text()};
            for (var i=0; i<todo[0].attributes.length; i++) {
              var attr = todo[0].attributes[i];
              if (attr.name.match("^data-")) {
                params[attr.name.substr(5)] = attr.value;
              }
            }

            // issue request
            $.post(#{ENV['SCRIPT_NAME'].inspect}, params, function(response) {
              var replacement = $(response.html);
              spinner.remove();
              todo.replaceWith(replacement);
              if (replacement.filter('._stderr,._traceback').length > 0) {
                if (!confirm("Error detected.  Continue?")) return;
              }
              execute_todos();
            }, 'json');
          } else {
            parent.frames[0].location.reload();
          }
        }
        execute_todos();
      }
    end
  end
end
