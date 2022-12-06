#!/usr/bin/env ruby
# Defines partial standards for Apache website checker
# TODO better document with specific policies

# Encapsulate (most) scans/validations done on website content
module SiteStandards
  extend self
  CHECK_TEXT      = 'text'      # (optional) Regex of <a ...>Text to scan for</a>, of a.text.downcase.strip
  CHECK_CAPTURE   = 'capture'   # a_href minimal regex to capture - for license, we capture the link if it points to apache.org somewhere
  CHECK_VALIDATE  = 'validate'  # a_href detailed regex to expect for compliance; it must point to one of our actual licenses to pass
  CHECK_TYPE      = 'type'      # true = validation checks href/url; false = checks text node
  CHECK_POLICY    = 'policy'    # URL to policy statement for this check
  CHECK_DOC       = 'doc'       # Explanation of what the check is looking for

  # Checks done only for TLPs (i.e. not podlings)
  TLP_CHECKS = {
    'uri' => { # Custom: merely saves uri of site
      CHECK_TEXT => nil,
      CHECK_CAPTURE => nil,
      CHECK_VALIDATE => %r{https?://[^.]+\.apache\.org},
      CHECK_TYPE => true,
      CHECK_POLICY => 'https://www.apache.org/foundation/marks/pmcs#websites',
      CHECK_DOC => 'The homepage for any ProjectName must be served from http://ProjectName.apache.org',
      },
  }
  # Checks done only for Incubator podlings
  PODLING_CHECKS = {
    'uri' => {
      CHECK_TEXT => nil,
      CHECK_CAPTURE => %r{https?://[^.]+\.incubator\.apache\.org},
      CHECK_VALIDATE => %r{https?://[^.]+\.incubator\.apache\.org},
      CHECK_TYPE => true,
      CHECK_POLICY => 'https://www.apache.org/foundation/marks/pmcs#websites',
      CHECK_DOC => 'The homepage for any ProjectName must be served from http://ProjectName(.incubator).apache.org',
      },
    'disclaimer' => { # textnode_check: txt =~ / Incubation is required of all newly accepted projects /
      CHECK_TEXT => %r{Incubation is required of all newly accepted projects},
      CHECK_CAPTURE => %r{Incubation is required of all newly accepted projects},
      CHECK_VALIDATE =>  %r{Apache \S+( \S+)?( \([Ii]ncubating\))? is an effort undergoing [Ii]ncubation at [Tt]he Apache Software Foundation \(ASF\),? sponsored by the (Apache )?\S+( PMC)?. Incubation is required of all newly accepted projects until a further review indicates that the infrastructure, communications, and decision making process have stabilized in a manner consistent with other successful ASF projects. While incubation status is not necessarily a reflection of the completeness or stability of the code, it does indicate that the project has yet to be fully endorsed by the ASF.},
      CHECK_TYPE => false,
      CHECK_POLICY => 'https://incubator.apache.org/guides/branding.html#disclaimers',
      CHECK_DOC => 'All Apache Incubator Podling sites must contain the incubating disclaimer.',
      },
  }
  # Checks done for all podlings|projects
  COMMON_CHECKS = {
    'foundation' => { # Custom: a_href =~ ... then custom checking for hover/title text
      CHECK_TEXT => %r{apache|asf|foundation}i,
      CHECK_CAPTURE => %r{^(https?:)?//(www\.)?apache\.org/?$},
      CHECK_VALIDATE => %r{apache|asf|foundation}i,
      CHECK_TYPE => false,
      CHECK_POLICY => 'https://www.apache.org/foundation/marks/pmcs#navigation',
      CHECK_DOC => 'All projects must feature some prominent link back to the main ASF homepage at http://www.apache.org/',
    },
    'events' => { # Custom: a_href.include? 'apache.org/events/' then custom check for img
      CHECK_TEXT => nil,
      CHECK_CAPTURE => %r{apache\.org/events},
      CHECK_VALIDATE => %r{^https?://.*apache.org/events/current-event},
      CHECK_TYPE => true,
      CHECK_POLICY => 'https://www.apache.org/events/README.txt',
      CHECK_DOC => 'Projects SHOULD include a link to any current ApacheCon event, as provided by VP, Conferences.',
    },
    'license' => { # link_check a_text =~ /^license$/ and a_href.include? 'apache.org'
      CHECK_TEXT => /^license$/,
      CHECK_CAPTURE => %r{apache\.org},
      CHECK_VALIDATE => %r{^https?://.*apache.org/licenses/?$},
      CHECK_TYPE => true,
      CHECK_POLICY => 'https://www.apache.org/foundation/marks/pmcs#navigation',
      CHECK_DOC => 'There should be a "License" (*not* "Licenses") navigation link which points to: http[s]://www.apache.org/licenses[/]. (Do not link to sub-pages)',
    },
    'thanks' => { # link_check a_text =~ /\A(sponsors|thanks!?|thanks to our sponsors)\z/
        CHECK_TEXT => /\A(sponsors|thanks!?|thanks to our sponsors)\z/,
        CHECK_CAPTURE => /\A(sponsors|thanks!?|thanks to our sponsors)\z/,
        CHECK_VALIDATE => %r{^https?://.*apache.org/foundation/thanks},
        CHECK_TYPE => true,
        CHECK_POLICY => 'https://www.apache.org/foundation/marks/pmcs#navigation',
        CHECK_DOC => '"Sponsors", "Thanks" or "Thanks to our Sponsors" should link to: http://www.apache.org/foundation/thanks.html',
    },
    'security' => { # link_check a_text == 'security'
      CHECK_TEXT => /security/,
      CHECK_CAPTURE => /security/,
      CHECK_VALIDATE => %r{^https?://.*apache.org/.*[Ss]ecurity},
      CHECK_TYPE => true,
      CHECK_POLICY => 'https://www.apache.org/foundation/marks/pmcs#navigation',
      CHECK_DOC => '"Security" should link to either to a project-specific page [...], or to the main http://www.apache.org/security/ page.',
    },
    'sponsorship' => { # link_check ['sponsorship', 'donate', 'sponsor apache','sponsoring apache'].include? a_text
      CHECK_TEXT => %r{sponsorship|\bdonate\b|sponsor\sapache|sponsoring\sapache|sponsor},
      CHECK_CAPTURE => %r{sponsorship|\bdonate\b|sponsor\sapache|sponsoring\sapache|sponsor},
      CHECK_VALIDATE => %r{^https?://.*apache.org/foundation/sponsorship},
      CHECK_TYPE => true,
      CHECK_POLICY => 'https://www.apache.org/foundation/marks/pmcs#navigation',
      CHECK_DOC => '"Sponsorship", "Sponsor Apache", or "Donate" should link to: http://www.apache.org/foundation/sponsorship.html',
    },

    'trademarks' => { # textnode_check: if (txt =~ /\btrademarks\b/  and not data[:trademarks]) or txt =~/are trademarks of [Tt]he Apache Software/
      CHECK_TEXT => %r{\btrademarks\b},
      CHECK_CAPTURE => %r{\btrademarks\b},
      CHECK_VALIDATE => %r{trademarks of [Tt]he Apache Software Foundation},
      CHECK_TYPE => false,
      CHECK_POLICY => 'https://www.apache.org/foundation/marks/pmcs#attributions',
      CHECK_DOC => 'All project or product homepages must feature a prominent trademark attribution of all applicable Apache trademarks.',
    },
    'copyright' => { # textnode_check: txt =~ /Copyright / or txt =~ /©/
      CHECK_TEXT => %r{((Copyright|©).*apache|apache.*(Copyright|©))}i,
      CHECK_CAPTURE => %r{(Copyright|©)}i,
      CHECK_VALIDATE => %r{((Copyright|©).*apache|apache.*(Copyright|©))}i,
      CHECK_TYPE => false,
      CHECK_POLICY => 'https://www.apache.org/legal/src-headers.html#headers',
      CHECK_DOC => 'All website content SHOULD include a copyright notice for the ASF.',
    },

    'privacy' => { # link_check
      CHECK_TEXT => %r{Privacy Policy}i,
      CHECK_CAPTURE => %r{(Privacy)}i,
      CHECK_VALIDATE => %r{\Ahttps://privacy\.apache\.org/policies/privacy-policy-public.html\z}i,
      CHECK_TYPE => true,
      CHECK_POLICY => 'https://www.apache.org/foundation/marks/pmcs.html#navigation',
      CHECK_DOC => 'All websites must link to the Privacy Policy.',
    },

    'resources' => { # Custom: resources not outside ASF
      CHECK_TEXT => %r{Found \d+ external resources},
      CHECK_CAPTURE => %r{Found \d+ external resources},
      CHECK_VALIDATE => %r{Found 0 external resources},
      CHECK_TYPE => false,
      CHECK_POLICY => 'https://privacy.apache.org/faq/committers.html',
      CHECK_DOC => 'Websites must not link to externally hosted resources',
    },

    'image' => { # Custom: merely looks in IMAGE_DIR for #{id}.*
      CHECK_TEXT => nil,
      CHECK_CAPTURE => nil,
      CHECK_VALIDATE => %r{.},
      CHECK_TYPE => true,
      CHECK_POLICY => 'https://www.apache.org/logos/',
      CHECK_DOC => 'Projects SHOULD add a copy of their logo to https://www.apache.org/logos/ to be included in ASF homepage.',
    },
  }

  SITE_PASS       = 'label-success'
  SITE_WARN       = 'label-warning'
  SITE_FAIL       = 'label-danger'
  # Determine the color of a given table cell, given:
  #   - overall analysis of the sites, in particular the third column
  #     which is a list projects that successfully matched the check
  #   - list of links for the project in question
  #   - the column in question (which indicates the check being reported on)
  #   - the name of the project
  def label(analysis, links, col, name)
    if not links[col]
      SITE_FAIL
    elsif analysis[2].include? col and not analysis[2][col].include? name
      SITE_WARN
    else
      SITE_PASS
    end
  end

  # Get hash of checks to be done for tlp | podling
  # @param tlp true if project; podling otherwise
  def get_checks(tlp = true)
    tlp ? (return TLP_CHECKS.merge(COMMON_CHECKS)) : (return PODLING_CHECKS.merge(COMMON_CHECKS))
  end

  # Get filename of check data for tlp | podling
  # @param tlp true if project; podling otherwise
  def get_filename(tlp = true)
    tlp ? (return 'site-scan.json') : (return 'pods-scan.json')
  end

  # Get URL to default filename location on server
  def get_url(is_local = true)
    is_local ? (return '../../../www/public/') : (return 'https://whimsy.apache.org/public/')
  end

  # Get check data for tlp | podling
  #   Uses a local_copy if available; w.a.o/public otherwise
  # @param tlp true if project; podling otherwise
  # @return [hash of site data, crawl_time]
  def get_sites(tlp = true)
    local_copy = File.expand_path("#{get_url(true)}#{get_filename(tlp)}", __FILE__)
    if File.exist? local_copy
      crawl_time = File.mtime(local_copy).httpdate # show time in same format as last-mod
      sites = JSON.parse(File.read(local_copy))
    else
      response = Net::HTTP.get_response(URI("#{get_url(false)}#{get_filename(tlp)}"))
      crawl_time = response['last-modified']
      sites = JSON.parse(response.body)
    end
    return sites, crawl_time
  end

  # Analyze data returned from site-scan.rb by using checks[CHECK_VALIDATE] regex
  #   If value =~ CHECK_VALIDATE, SITE_PASS
  #   If value is present (presumably from CHECK_TEXT|CAPTURE), then SITE_WARN
  #   If value not present, SITE_FAIL (i.e. site-scan.rb didn't find it)
  # @param sites hash of site-scan data collected
  # @param checks to apply to sites to determine status
  # @return [overall counts, description of statuses, success listings]
  def analyze(sites, checks)
    success = Hash.new { |h, k| h[k] = Hash.new(&h.default_proc) }
    counts = Hash.new { |h, k| h[k] = Hash.new(&h.default_proc) }
    checks.each do |nam, check_data|
      success[nam] = sites.select { |_, site| site[nam] =~ check_data[SiteStandards::CHECK_VALIDATE]  }.keys
      counts[nam][SITE_PASS] = success[nam].count
      counts[nam][SITE_WARN] = 0 # Reorder output
      counts[nam][SITE_FAIL] = sites.select { |_, site| site[nam].nil? }.count
      counts[nam][SITE_WARN] = sites.size - counts[nam][SITE_PASS] - counts[nam][SITE_FAIL]
    end

    return [
      counts, {
      SITE_PASS => '# Sites with links to primary ASF page',
      SITE_WARN => '# Sites with link, but not an expected ASF one',
      SITE_FAIL => '# Sites with no link for this topic'
      }, success
    ]
  end
end
