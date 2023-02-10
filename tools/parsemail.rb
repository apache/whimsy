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

module ParseMail
  MAIL_ROOT = '/srv/mail'

  def self.log(level, text)
    out = nil
    out = $stdout if __FILE__ == $0 # only write to stdout from this script
    out = $stderr if level == :WARN
    out.puts "#{Time.now} #{level}: #{text}" unless out.nil?
  end

  def self.parse_dir(maildir, yamlfile)
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
        }
        data[name] = entry
      end
    end

    log :INFO, "Found #{entries} files, with #{dupes} duplicates, giving #{data.size} new entries"

    if data.size == 0
      log :INFO, "No new entries found"
    else
      # update the file with any new entries
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
    yyyymm = args.shift || Time.now.strftime('%Y%m')
    yamlfile = args.shift || File.join(MAIL_ROOT, list, "#{yyyymm}.yaml") # where to find the YAML summary
    
    maildir = File.join(MAIL_ROOT, list, yyyymm) # where to find the mail files
    if Dir.exists? maildir
      log :INFO, "Processing #{maildir}"
      parse_dir(maildir, yamlfile)
    else
      log :WARN, "Could not find #{maildir}"
    end
  end
end

if __FILE__ == $0
  ParseMail.parse_main(ARGV)
end
