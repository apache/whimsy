#!/usr/bin/env ruby
<<~HEREDOC
ComDev Talks: Parse ComDev listings of Apache-related talks

Currently requires local checkout; future use for displaying talks by category
HEREDOC
require 'yaml'
require 'json'

COMDEVTALKS = 'https://svn.apache.org/repos/asf/comdev/site/trunk/content/speakers/talks/' # *.yaml
COMDEVDIR = '/Users/curcuru/src/comdev/site/trunk/content/speakers/talks/' # *.yaml

# Parse all talks and submitters
def parse_talks(dir)
  talks = {}
  submitters = {}
  Dir[File.join("#{dir}", "*.yaml")].each do |fname|
    begin
      if fname =~ /_/
        talks["#{File.basename(fname, ".*")}"] = YAML.load(File.read(fname))
      else
        submitters["#{File.basename(fname, ".*")}"] = YAML.load(File.read(fname))
      end
    rescue Exception => e
      puts "Bogosity! analyzing #{fname} raised #{e.message[0..255]}"
      puts "\t#{e.backtrace.join("\n\t")}"
    end
  end

  return talks, submitters
end

# ## ### #### ##### ######
# Main method for command line use
if __FILE__ == $PROGRAM_NAME
  dir = COMDEVDIR
  outfile = File.join("#{dir}", "comdevtalks.json")
  puts "BEGIN: Parsing YAMLs in #{dir}"
  talks, submitters = parse_talks dir
  results = {}
  results['talks'] = talks
  results['submitters'] = submitters
  File.open(outfile, "w") do |f|
    f.puts JSON.pretty_generate(results)
  end
  puts "END: Thanks for running, see #{outfile}"
end
