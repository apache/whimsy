#!/usr/bin/env ruby

#  ComDev Talks: Parse ComDev listings of Apache-related talks
$LOAD_PATH.unshift '/srv/whimsy/lib'
require 'whimsy/asf'

require 'yaml'
require 'json'

COMDEVTALKS = ASF::SVN.svnurl!('comdevtalks') # *.yaml
COMDEVDIR = ASF::SVN['comdevtalks'] # *.yaml
SKIPFILE = 'README.yaml'

# Parse all talks and submitters
def parse_talks(dir = COMDEVDIR)
  talks = {}
  submitters = {}
  Dir[File.join(dir, "*.yaml")].each do |fname|
    begin
      if fname =~ /_/
        talks[File.basename(fname, ".*")] = YAML.safe_load(File.read(fname))
      elsif fname !~ /SKIPFILE/
        submitters[File.basename(fname, ".*")] = YAML.safe_load(File.read(fname))
      end
    rescue Exception => e
      puts "Bogosity! analyzing #{fname} raised #{e.message[0..255]}"
      puts "\t#{e.backtrace.join("\n\t")}"
    end
  end

  return talks, submitters
end

# Abstract how cgi gets data
def get_talks_submitters()
  # return parse_talks
  # HACK static data until we have generated public/ or other format
  talks = {
    "Apache_Way_2017" => {
      "title" => "Apache Way: Effective Open Source Project Management",
      "teaser" =>  "Learn how to manage long-lived diverse open source project communities by " \
                  "following the behaviors of the Apache Way.",
      "submitter" => "curcuru",
      "speakers" => ["curcuru"],
      "abstract" => "The \"Apache Way\" is the process by which Apache Software Foundation projects are managed. " \
                    "It has evolved 18 years and has produced over 170 highly successful open source Apache projects." \
                    " But what is it and how does it work?\n\nLearn the core behaviors that make up the Apache Way, " \
                    "and how they are used in successful Apache projects from core technologies, to big data, to " \
                    "user facing projects.\n\nThe behaviors in the Apache Way are required for all Apache projects, " \
                    "but can be simply used by any open source projects.  Distributed " \
                    "decision making, open communication, do-ocracy, and diverse communities are the cornerstones." \
                    "\n\nBenefit from the experience of over 5,000 Apache committers and 170 successful projects by " \
                    "applying these behaviors and techniques in your own projects! \n",
      "audience" => "Community managers, developers, project managers involved with FOSS projects.",
      "slides" => "http://shaneslides.com/apachecon/TheApacheWay-Intro-ApacheConNA2017.html",
      "video" => "https://www.youtube.com/watch?v=hpAv54KIgK8",
      "topics" => ["apacheway", "community"],
      "present_at" => ["http://apachecon.com/2017"],
      "present_date" => "2017-05-16"
    },
    "Committed_To_The_Apache_Way" => {
      "title" => "Committed To The Apache Way",
      "teaser" => "Learn how being involved in an Apache project is not just about code.",
      "submitter" => "sharan",
      "speakers" => ["sharan"],
      "abstract" => "'To be committed' is a strange phrase. In the past it was used to describe people who were sent " \
                    "to mental institutions or 'facilities'. Fast forward to today and words like committed and " \
                    "commitment are used throughout the Open Source world. Are we all a little crazy? - Perhaps!" \
                    "\n\nIn this presentation Sharan shares her thoughts and experiences about being a Committer, " \
                    "life at the ASF (facility) and how not being able to code is still OK.\n",
      "audience" => "Community managers, developers, project managers involved with FOSS projects.",
      "slides" => "http://events.linuxfoundation.org/sites/events/files/slides/Commited%20to%20Apache.pdf",
      "video" => "https://www.youtube.com/watch?v=vT-kxmoLs5k&index=25&list=PLbzoR-pLrL6pLDCyPxByWQwYTL-JrF5Rp",
      "topics" => ["community", "contributors"],
      "present_at" => ["http://apachecon.com/2017"],
      "present_date" => "2017-05-16"
    },
    "From_Dev_To_User" => {
      "title" => "From dev@ to user@ to the Apache Way",
      "teaser" => "The story of how an existing project community improved by coming to Apache.",
      "submitter" => "sblackmon",
      "speakers" => ["sblackmon"],
      "abstract" => "This talk will cover the journey of Apache Streams (incubating) beyond a solution solely " \
                    "by and for java developers, toward a solution that can provide value for anyone, anywhere " \
                    "along the experience spectrum, regardless of technical preferences.  " \
                    "We'll share feedback that served as concentrate focus on mission and usability. " \
                    "\n\nWe'll walk through some of the improvements made to project code and tooling (maven), " \
                    "documentation (website, examples), and usability (command line interface, maven plugins, " \
                    "zeppelin support, network APIs) to move the project from dev@ to user@, and the " \
                    "opportunities we see to increase usability and relevance still further.\n",
      "audience" => "Community managers, developers, project managers involved with FOSS projects.",
      "slides" => "http://events.linuxfoundation.org/sites/events/files/slides/ApacheConNA2017-Blackmon.pdf",
      "video" => "https://www.youtube.com/watch?v=E9A54x6af8o&index=27&list=PLbzoR-pLrL6pLDCyPxByWQwYTL-JrF5Rp",
      "topics" => ["incubator", "apacheway"],
      "present_at" => ["http://apachecon.com/2017"],
      "present_date" => "2017-05-16"
    },
    "Tale_Of_Two_Developers" => {
      "title" => "A Tale of Two Developers: Finding Harmony Between Commercial Software Development and the Apache Way",
      "teaser" => "Learn from the real-life lunchtime dialog between an experienced Apache committer and a new coder.",
      "submitter" => "wang",
      "speakers" => ["wang", "Alex Leblang"],
      "abstract" => "Apache community members can reference tenets from the Apache Way such as \u201Ccommunity over " \
                    "code\u201D and \u201Copenness\u201D as if it were second nature. While they may sound simple, " \
                    "these concepts can be foreign to developers coming to open source for the first time. " \
                    "Success as an Apache contributor stresses skills not emphasized in other types of software " \
                    "development, including reconciling the requirements of the upstream development process with " \
                    "the realities of running a commercial software business.\n\n" \
                    "With the assistance of choreographed Socratic dialogue, our two protagonists, an experienced " \
                    "Apache committer and an enthusiastic young gun contributor, explore the tensions of working on " \
                    "an Apache project as employees of a for-profit company. The audience will learn practical " \
                    "advice and problem solving techniques for working effectively as part of an Apache community. " \
                    "By the end, our greenhorn comes to understand that the yin and yang of commercial software " \
                    "development and the Apache Way can exist in harmony.\n\nOur talk contextualizes the Apache Way " \
                    "for developers who are paid to work on open-source full-time, drawn from our real-world " \
                    "experience working at Cloudera. " \
                    "This is presented through a series of short vignettes accompanied by intervening discussion and " \
                    "review slides. Tenets of the Apache Way like meritocracy, community, and hats are introduced " \
                    "and referred to throughout as the backbone to building strong open-source communities. " \
                    "We examine the tension between corporate pressures and open-source, emphasizing the underlying " \
                    "value that companies gain from open-source software.\n\n" \
                    "Our two main characters are:\n* Alex, an energetic young developer who is new to open source " \
                    "but not to development. Excited to get stuff done on this new project.\n* Andrew, a long-time " \
                    "Apache committer who takes Alex under his wing and teaches him the importance of open-source.\n" \
                    "\nThe outline for our skits are:\n* Act 1: Introduction to Apache and the Apache Way, FAQs from " \
                    "Alex as someone getting started as a new contributor\n* Act 2: How to build consensus when " \
                    "there's conflict (e.g. someone -1's your patch), public communication, demonstrating merit " \
                    "and the path to committership\n* Act 3: No jerks allowed. Andrew does a heel turn and is " \
                    "ruling the project with an iron fist, Alex intervenes in a " \
                    "come-to-jesus/student-becomes-the-teacher moment. Re-emphasize the importance of community, " \
                    "and how dictators are bad for projects.\n",
      "audience" => "Community managers, developers, project managers involved with FOSS projects.",
      "slides" => nil,
      "video" => "https://www.youtube.com/watch?v=ea_9qkaTeVw&index=26&list=PLbzoR-pLrL6pLDCyPxByWQwYTL-JrF5Rp",
      "topics" => ["apacheway", "developers"],
      "present_at" => ["http://apachecon.com/2017"],
      "present_date" => "2017-05-16"
    }
}

  submitters = {
    "curcuru" => {
      "name" => "Shane Curcuru",
      "website" => "http://communityovercode.com/",
      "twitter" => "shanecurcuru",
      "facebook" => nil,
      "bio" => "Shane has been involved at the Apache Software Foundation (ASF) since 1999, and serves as Director " \
                "and VP of Brand Management, setting trademark policies and helping all 200+ Apache projects " \
                "implement and defend their brands.\n\nOtherwise, Shane is: a father and husband, a friend, a geek, " \
                "a Member of the ASF, a baker, and a punny guy.  Oh, and we have cats.  Shane blogs at " \
                "http://communityovercode.com/ and regularly speaks on FOSS governance and branding topics.\n"
    },
   "README" => {
      "title" => "Talk Title: Strings with colons must be quoted",
      "teaser" => "Teaser is one sentence for use on session grids or tweets or the like (where supported).",
      "submitter" => "curcuru",
      "speakers" => ["curcuru", "Court Jester"],
      "abstract" => "Abstracts are the full description of a talk, session, or panel that has already been presented." \
                    "\n\nAbstracts may have line breaks, and some systems may allow **formatting** or the like.\n\n" \
                    "Using the YAML pipe \"|\" character for a literal multiline scalar means linebreaks are " \
                    "preserved in the abstract. \n",
      "audience" => "Brief description of the expected audience for this talk.",
      "slides" => "URL.to/posted-slides",
      "video" => "URL.to/posted-video?if-any",
      "present_at" => ["URL.to/last-conference-presented-at"],
      "present_date" => "2017-05-16"
    },
    "sblackmon" => {
      "name" => "Steve Blackmon",
      "website" => nil,
      "twitter" => "steveblackmon",
      "facebook" => nil,
      "bio" => "VP Technology at People Pattern, previously Director of Data Science at W2O Group, co-founder of " \
               "Ravel, stints at Boeing, Lockheed Martin, and Accenture. Committer and PMC for Apache Streams " \
               "(incubating). " \
               "Experienced user of Spark, Storm, Hadoop, Pig, Hive, Nutch, Cassandra, Tinkerpop, and more.\n"
    },
    "sharan" => {
      "name" => "Sharan Foga",
      "website" => nil,
      "twitter" => nil,
      "facebook" => nil,
      "bio" => "Sharan Foga have been involved with the ASF since 2008 and has presented at previous Apachecons " \
               "(Vancouver 2016, Budapest 2015 & 2014). She enjoys working on community management and related areas " \
               "and is a Committer and PMC Member for Apache OFBiz and Community Development.\n"
    },
    "wang" => {
      "name" => "Andrew Wang",
      "website" => "http://umbrant.com/",
      "twitter" => nil,
      "facebook" => nil,
      "bio" => "Andrew Wang is a software engineer at Cloudera on the HDFS team, where he has worked on projects " \
               "including in-memory caching, transparent encryption, and erasure coding. Previously, he was a PhD " \
               "student in the AMP Lab at UC Berkeley, where he worked on problems related to distributed systems " \
               "and warehouse-scale computing. He is a committer and PMC member on the Apache Hadoop project, a " \
               "committer on Apache Kudu (incubating), and holds masters and bachelors degrees in computer science " \
               "from UC Berkeley and UVa respectively. Andrew has spoken at conferences including Hadoop Summit EU, " \
               "Strata NYC, Strata London, HBaseCon, ACM SoCC, and USENIX HotCloud.\n"
    }
  }

  return talks, submitters
end

# ## ### #### ##### ######
# Main method for command line use
if __FILE__ == $PROGRAM_NAME
  dir = COMDEVDIR
  outfile = File.join(dir, "comdevtalks.json")
  puts "BEGIN: Parsing YAMLs in #{dir}"
  talks, submitters = parse_talks dir
  results = {}
  results['talks'] = talks
  results['submitters'] = submitters
  File.open(outfile, "w") do |f|
    f.puts JSON.pretty_generate(results)
  end
  puts talks
  puts "END: Thanks for running, see #{outfile}"
  puts submitters
end
