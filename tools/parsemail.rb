#!/usr/bin/env ruby

#  Licensed to the Apache Software Foundation (ASF) under one or more
#  contributor license agreements.  See the NOTICE file distributed with
#  this work for additional information regarding copyright ownership.
#  The ASF licenses this file to You under the Apache License, Version 2.0
#  (the "License"); you may not use this file except in compliance with
#  the License.  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.

#
# Parse mail files and update summary YAML file

# Currently used by a cron job to process board and member emails

$LOAD_PATH.unshift '/srv/whimsy/lib'
require 'whimsy/asf/yaml'

require 'mail'
require 'date'
require 'fileutils'

module ParseMail
  MAIL_ROOT = '/srv/mail'

  def self.log(level, text)
    out = nil
    out = $stdout if __FILE__ == $0 # only write to stdout from this script
    out = $stderr if level == :WARN
    out.puts "#{Time.now} #{level}: #{text}" unless out.nil?
  end

  def self.parse_dir(maildir, yamlfile)
    # Has the directory changed since the last run?
    # If not, don't reprocess
    begin
      ytime = File.mtime(yamlfile)
    rescue Errno::ENOENT # not yet created
      ytime = Time.at(0)
    end
    dtime = File.mtime(maildir) # must exist
    if ytime > dtime + 60 # Allow for yaml update window
      log :INFO, "No change to #{maildir} (#{dtime}) since #{yamlfile} (#{ytime}), skipping"
      return
    else
      log :INFO, "Timediff #{dtime - ytime}"
    end
    data = Hash.new

    begin
      current = YamlFile.read(yamlfile)
    rescue Errno::ENOENT
      current = {}
    end
    log :INFO, "Current size #{current.size}"
    entries = 0
    dupes = 0
    Dir.glob("#{maildir}/[0-9a-f][0-9a-f]*").each do |p|
      entries += 1
      name = File.basename(p)
      if current[name]
        dupes += 1
      else
        mail=Mail.read(p)
        entry = {
          Subject:   mail.subject,
          Date:      (mail['Date'].decoded rescue ''), # textual
          DateParsed: (mail.date.to_s rescue ''), # parsed
          From:      (mail['From'].decoded rescue ''),
          To:        (mail['To'].decoded rescue ''),
          Cc:        (mail['Cc'].decoded rescue ''),
          # list of destination emails
          Emails:     [(mail[:to].addresses.map(&:to_str) rescue []),(mail[:cc].addresses.map(&:to_str) rescue [])].flatten,
          MessageId: mail.message_id, # could be nil
          EnvelopeFrom: mail.envelope_from,
          EnvelopeDate: mail.envelope_date.to_s, # effectively the delivery date to the mailing list
          InReplyTo: mail['In-Reply-To']&.decoded, # will be nil if not present
        }
        data[name] = entry
      end
    end

    log :INFO, "Found #{entries} files, with #{dupes} duplicates, giving #{data.size} new entries"

    if data.size == 0
      log :INFO, 'No new entries found, updating last date'
      FileUtils.touch yamlfile # needed to skip processing next time
      # Should not happen often, an updated dir should result in updating the yaml
    else
      # update the file with any new entries (this locks the file)
      YamlFile.update(yamlfile) do |yaml|
        data.each do |k,v|
            unless yaml[k] # don't update existing entries (should rarely happen)
                yaml[k] = v
            end
        end
        yaml
      end
    end
  end

  # indirection is to allow external code to require this file so it can be invoked
  # without needing to shell out for a possibly expensive ruby!

  def self.parse_main(args)
    list = args.shift || 'board' # provide the list on the command line (e.g. board)
    lastmonth = nil # may need to process last month as well
    # This should only be done if overrides have not been provided
    yyyymm = args.shift
    yamlfile = args.shift
    unless yyyymm
      now = Time.now
      yyyymm = now.strftime('%Y%m')
      unless yamlfile
        ddhh = now.strftime('%d%H') # current day and hour
        if ddhh == '0100' or ddhh == '0101' # start of month
          lastmonth = (Date.parse(yyyymm+'01') - 1).strftime('%Y%m')
        end
      end
    end
    yamlfile ||= File.join(MAIL_ROOT, list, "#{yyyymm}.yaml") # where to find the YAML summary

    maildir = File.join(MAIL_ROOT, list, yyyymm) # where to find the mail files
    if Dir.exist? maildir
      log :INFO, "Processing #{maildir} into #{yamlfile}"
      parse_dir(maildir, yamlfile)
    else
      log :WARN, "Could not find #{maildir}"
    end
    if lastmonth
      log :INFO, "Updating previous month: #{lastmonth}"
      yamlfile = File.join(MAIL_ROOT, list, "#{lastmonth}.yaml") # where to find the YAML summary

      maildir = File.join(MAIL_ROOT, list, lastmonth) # where to find the mail files
      if Dir.exist? maildir
        log :INFO, "Processing #{maildir} into #{yamlfile}"
        parse_dir(maildir, yamlfile)
      else
        log :WARN, "Could not find #{maildir}"
      end
    end
  end
end

if __FILE__ == $0
  ParseMail.parse_main(ARGV)
end
