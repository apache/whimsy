#
# Common methods to update the progress file
#
# Called from JS pages using POST
#

$LOAD_PATH.unshift '/srv/whimsy/lib'

require 'json'
require 'whimsy/lockfile'

# TODO add some kind of history to show who changed the phase and when
# This probably needs to be held separately from comments

# Simplify validation
VALID_ACTIONS=%w{submitVote cancelVote tallyVote submitComment startVoting invite}
HAS_COMMENT=%w{submitComment startVoting invite} # do we update the comments array?
VALID_PHASES=%w{discuss vote cancelled tallied invite}
VALID_VOTES=%w{+1 +0 -0 -1}

def update(data)
  # setup and validation
  token = data['token']
  raise ArgumentError.new('token must not be nil') unless token
  action = data['action']
  raise ArgumentError.new("Invalid action: '#{action}'") unless VALID_ACTIONS.include? action
  member = data['member']
  comment = data['comment'] # may be nil
  expectedPhase = data['expectedPhase']
  raise ArgumentError.new('expectedPhase must not be nil') unless expectedPhase
  newPhase = data['newPhase'] # nil for no change
  if newPhase and not VALID_PHASES.include? newPhase
    raise ArgumentError.new("Invalid newPhase: '#{newPhase}'")
  end

  timestamp = Time.now.utc.to_s
  addComment = nil
  voteinfo = nil
  if action == 'submitVote'
    vote = data['vote']
    raise ArgumentError.new("Invalid vote: '#{vote}'") unless VALID_VOTES.include? vote
    raise ArgumentError.new('member must not be nil') unless member
    if vote == '-1'
      raise ArgumentError.new('-1 vote must have comment') unless comment
    end
    if comment # allow comment for other votes
      voteinfo = {
        'vote' => vote,
        'comment' => comment,
        'member' => member,
        'timestamp' => timestamp,
      }
    else
      voteinfo = {
        'vote' => vote,
        'member' => member,
        'timestamp' => timestamp,
      }
    end
  elsif HAS_COMMENT.include? action
    if comment
      addComment = 
      {
        'comment' => comment,
        'member' => member,
        'timestamp' => timestamp,
      } 
    else
      raise ArgumentError.new("comment must not be nil for '#{action}'")
    end
  end

  file = "/srv/icla/#{token}.json"

  # now read/update the file if necessary
  contents = {} # define the var outside the block
  rewrite = false # should the file be updated?
  phases = *expectedPhase # convert string to array

  LockFile.lockfile(file, 'r+', File::LOCK_EX) do |f|
    contents = JSON::parse(f.read)
    phase = contents['phase']
    raise ArgumentError.new("Phase '#{phase}': expected '#{expectedPhase}'") unless expectedPhase == '*' or phases.include? phase 
    if newPhase && newPhase != phase
      contents['phase'] = newPhase
      rewrite = true
    end
    if action == 'startVoting' # need to add a vote to start this off
      comment0 = contents['comments'][0]['comment'] # initial comment
      voteinfo = {
        'vote' => '+1',
        'comment' => "#{comment0}\nHere is my +1", # append to original comment
        'member' => member,
        'timestamp' => timestamp,
      }
      addComment['comment'] += "\n**Starting the vote.**"
    end
    if voteinfo
      contents['votes'] << voteinfo
      rewrite = true
    end
    if addComment
      contents['comments'] << addComment
      rewrite = true
    end
    if rewrite
      f.rewind # back to start
      f.truncate(0) # need to empty the file otherwise can result in leftover data
      f.write(JSON.pretty_generate(contents))
    end
  end

  # return the data
  _rewrite rewrite # debug
  contents
end

# error handler
def process(data)
  contents = {}
  begin
    contents = update(data)
  rescue => e
    _error e
    _backtrace e.backtrace[0] # can be rather large
  end
  _contents contents
end

def embed # called by Sinatra which sets params
  process(params)
end

def main(params) # called by CLI which passes params
  process(params)
end

if __FILE__ == $0 # Allow independent testing
  $ret = {}
  # method_missing caused some errors to be overlooked
  %w{backtrace error contents rewrite}.each do |n|
    define_method("_#{n}") do |a|
      $ret[n] = a
    end
  end
  data = Hash[*ARGV] # cannot combine this with next line as hash doesn't yet exist
  data.each{|k,v| data[k] = v.split(',') if v =~ /,/} # fix up lists
  puts data.inspect
  main(data)
  puts JSON.pretty_generate($ret) # output the return data
else
  embed # Sinatra sets params
end