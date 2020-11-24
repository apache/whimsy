#!/usr/bin/env ruby
require 'json'

puts 'DANGER, WILL ROBINSON! THIS IS NOT READY FOR PRODUCTION USE!'

# Map usernames between different systems (id.a.o and JIRA|Confluence)
# Input data is:
#   committers = [{ID=>'curcuru', NAME =>'Shane Curcuru', MAIL=>['mail1', 'mail2',...]}, ...]
#   other = [{ID=>'curcuru', NAME =>'Shane Curcuru', MAIL=>'mailone'}, ...]
# Analyzes matching IDs and emails, and returns:
#   matches = hash by committer id of all committers, and if they matched
#     SAME:... committer ID and an email address match exactly
#       Most likely committer has same ID on both
#     DIFF:... committer ID matches, but none of the emails matched
#       Most likely the other account is a different person than committer
#     NONE:... there were no ID matches
#       Committer's ID is not found in other system
#   crossmatches = hash by email address of any other matches from
#     any of the other system's emails to any committer's emails
#     REVIEW:... email address(es) matched, but IDs did not
#       Note: emails may not be unique across accounts on either side
#       Need to manually investigate, since may involve multiple people/accounts
#     DIFF: an email address matched, but the IDs did not
#       Manually invesigate to see why
# NOTE: You *must* manually evaluate the results!
module NameMap
  extend self
  COMMITTER_JSON = 'https://whimsy.apache.org/roster/committer/index.json'
  ID = 'id'
  MAIL = 'mail'
  NAME = 'name'

  TEST_COMMITTERS = [ # Drawn from Whimsy's committer data
    {
      'id' => 'curcuru',
      'name' => 'Shane Curcuru',
      'mail' => [
        'asf@shanecurcuru.org',
        'asfl@shanecurcuru.org',
        'curcuru@apache.org'
      ],
      'member' => true
    },
    {
      'id' => 'makemyday',
      'name' => 'Clint Eastwood',
      'mail' => [
        'clint@eastwood.com',
        'gun@smoke.org'
      ],
    },
    {
      'id' => 'robocop',
      'name' => 'Peter Weller',
      'mail' => [
        'peter@buckaroo.com',
        'both@lists.find',
      ],
    },
    {
      'id' => 'laurel',
      'name' => 'Yanni (musician)',
      'mail' => [
        'both@lists.find',
      ],
    },
    {
      'id' => 'emailUnMatch',
      'name' => 'Test Case1c',
      'mail' => [
        'email@example.com',
      ],
    },
  ]

  TEST_OTHER = [ # Any other system must provide id,name,email for each user
    {
      'id' => 'curcuru',
      'name' => 'Shane Curcuru',
      'mail' => 'asf@shanecurcuru.org',
    },
    {
      'id' => 'bogie',
      'name' => 'Rick Blaine',
      'mail' => 'piano@sam.org',
    },
    {
      'id' => 'makemyday',
      'name' => 'Doris Day',
      'mail' => 'doris@day.movies',
    },
    {
      'id' => 'yanni',
      'name' => 'Laurel Hardy',
      'mail' => 'both@lists.find',
    },
    {
      'id' => 'yannidouble',
      'name' => 'Laurel and Hardy',
      'mail' => 'both@lists.find',
    },
    {
      'id' => 'emailNotMatch',
      'name' => 'Test Case1o',
      'mail' => 'email@example.com',
    },
  ]

  # Read committer accounts
  # @param io stream to read JSON from
  # @return json data
  def get_committers(io)
    if io
      return JSON.parse(io)
    else
      return TEST_COMMITTERS
    end
  end

  # Read other system accounts
  # TODO Depends on file format of exported other system accounts
  # @param f filename to read from
  # @return json data
  def get_other(_f)
    return TEST_OTHER
  end

  # Transform committer accounts into lookup hashes
  # @param committers array from COMMITTER_JSON
  # @return byid, bymail - hashes for lookups to committer accounts
  #    byid - hash by id of data
  #    bymail - hash by id of array of datum (in case non-unique emails)
  def hash_committers(committers)
    byid = {}
    bymail = {}
    committers.each do |hsh|
      byid[hsh[ID]] = hsh
      hsh[MAIL].each do |addr| # Committers can have multiple emails
        (bymail[addr] ||= []) << hsh
      end
    end
    return byid, bymail
  end

  # Transform other system accounts into lookup hashes
  # @param other array of hashes including 'id', 'name', 'mail' keys
  # @return byid, bymail - hashes for lookups to other system accounts
  #    byid - hash by id of data
  #    bymail - hash by id of array of datum (in case non-unique emails)
  def hash_other(other)
    byid = {}
    bymail = {}
    other.each do |hsh|
      byid[hsh[ID]] = hsh
      (bymail[hsh[MAIL]] ||= []) << hsh
    end
    return byid, bymail
  end

  # Compare committer ids to other system account ids
  # @param cids - hash by id of committer data
  # @param cmails - hash by email of [committer1, ...]
  # @param cids - hash by id of other system account data
  # @param cmails - hash by email of [other1, ...]
  # @return matches, crossmatches - list of committer ids matched or not; list of emails cross-matched
  def compare(cids, cmails, oids, omails)
    matches = {}
    crossmatches = {}

    # For every committer, check for a matching account in other system
    cids.each do |cid, committer|
      # If the other system has identical id as committer
      if oids.has_key?(cid)
        # Cross-check all our mails with the other account to see if *any* match
        committer[MAIL].each do |caddr|
          # If one matches exactly with a single other account, log a likely match
          if caddr.eql?(oids[cid][MAIL])
            matches[cid] = "SAME:email match:(#{committer[NAME]},#{caddr}):(#{oids[cid][NAME]},#{oids[cid][MAIL]})"
            break
          end
        end
        if matches[cid].nil?
          # None of our emails matched the other2 email, log
          if committer[MAIL].length == 1
            matches[cid] = "DIFF:email no match:(#{committer[NAME]},#{committer[MAIL][0]}):(#{oids[cid][NAME]},#{oids[cid][MAIL]})"
          else
            matches[cid] = "DIFF:email no match:(#{committer[NAME]},#{committer[MAIL].length} addresses):(#{oids[cid][NAME]},#{oids[cid][MAIL]})"
          end
        end
      else # No id match, log it
        matches[cid] = "NONE:no id match found"
      end
    end

    # Also cross-check email addresses of other system to all committer emails
    omails.each do |omail, other_accounts|
      if cmails.has_key?(omail)
        # Each bymail entry is an array; usually 1 element, but sometimes more
        if cmails[omail].length == 1 && other_accounts.length == 1
          # Simple case: check single id value
          if cmails[omail][0][ID].eql?(other_accounts[0][ID])
            # no-op: If both emails have single account that matches, ignore (was logged above)
          else
            # Mismatch of two IDs with same (unique) emails
            crossmatches[omail] = "DIFF:id no match:(#{cmails[omail][0][ID]},#{cmails[omail][0][NAME]}):(#{other_accounts[0][ID]},#{other_accounts[0][NAME]})"
          end
        else
          # Complex case: check through arrays of accounts with same email
          str = "REVIEW:#{omail}:"
          cmails[omail].each do |itm|
            str += "(#{itm[ID]},#{itm[NAME]})"
          end
          str += ':'
          other_accounts.each do |itm|
            str += "(#{itm[ID]},#{itm[NAME]})"
          end
          crossmatches[omail] = str
        end
      end
    end
    return matches, crossmatches
  end

  # Compare a committer list to another system's list
  # @param cio io stream to read committer accounts from
  # @param ofile filename to read other system accounts from
  # @return matches, crossmatches - list of committer ids matched or not; list of emails cross-matched
  def report(cio = nil, ofile = nil)
    cids, cmails = hash_committers(get_committers(cio))
    oids, omails = hash_other(get_other(ofile))
    matches, crossmatches = compare(cids, cmails, oids, omails)
    return matches, crossmatches
  end

  # Check for email duplicates in committer roster
  # @return hash of any committers with duplicate emails
  # @return histogram of how many aliases committers list
  def committer_dups(io)
    dups = {}
    histogram = Hash.new {|k, v| k[v] = 0}
    cids, cmails = hash_committers(get_committers(io))
    cids.each do |_id, hsh|
      histogram[hsh[MAIL].length] += 1
    end
    cmails.each do |addr, ary|
      if ary.length > 1
        dups[addr] = ''
        ary.each do |hsh|
          dups[addr] += "#{hsh[ID]},"
        end
      end
    end
    return dups, histogram
  end
end

#### MAIN TESTING CODE
matches, crossmatches = NameMap.report()
puts JSON.pretty_generate(matches)
puts JSON.pretty_generate(crossmatches)

# dups, histogram = NameMap.committer_dups(File.read('committerlist-from-whimsy.json'))
# puts JSON.pretty_generate(dups)
# puts JSON.pretty_generate(histogram)

