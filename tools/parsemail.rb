#!/usr/bin/env ruby

#
# Parse mail files and update summary YAML file
#

# DRAFT DRAFT DRAFT DRAFT
#
# Could perhaps be incorporated into the deliver script, once proven


$LOAD_PATH.unshift '/srv/whimsy/lib'
require 'whimsy/asf/yaml'

require 'mail'

MAIL_ROOT = '/srv/mail'

list = ARGV.shift || 'board' # provide the list on the command line (e.g. board)
yyyymm = ARGV.shift || Time.now.strftime('%Y%m')
yamlfile = ARGV.shift || File.join(MAIL_ROOT, list, "#{yyyymm}.yaml") # where to find the YAML summary

maildir = File.join(MAIL_ROOT, list, yyyymm) # where to find the mail files

data = Hash.new

begin
  current = YamlFile.read(yamlfile)
rescue Errno::ENOENT
  current = {}
end

Dir.glob("#{maildir}/[0-9a-f][0-9a-f]*").each do |p|
    name = File.basename(p)
    unless current[name]
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
        }
        data[name] = entry
    end
end

# update the file with any new entries
YamlFile.update(yamlfile) do |yaml|
    data.each do |k,v|
        unless yaml[k] # don't update existing entries
            yaml[k] = v
        end
    end
    yaml
end
