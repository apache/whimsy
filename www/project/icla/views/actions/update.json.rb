#
# Common methods to update the progress file
# TODO also send emails?
#

$LOAD_PATH.unshift '/srv/whimsy/lib'

require 'json'
require 'whimsy/lockfile'

# TODO add emails where necessary
# TODO add some kind of history to show who changed the phase and when
# This probably needs to be held separately from comments

def update(data)
  token = data['token'] 
  file = "/srv/icla/#{token}.json"
  action = data['action']
  timestamp = Time.now.to_s[0..9]
  member = data['member']
  comment = data['comment'] # may be nil

  if action == 'submitVote'
    vote = data['vote']
    raise 'vote must not be nil' unless vote
    raise 'member must not be nil' unless member
    if vote == '-1'
      raise '-1 vote must have comment' unless comment
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
  end
  contents = {} # define the var outside the block
  LockFile.lockfile(file, 'r+', File::LOCK_EX) do |f|
    contents = JSON::parse(f.read)
    rewrite = false # should the file be updated?
    case action
      # These are the vote actions
      when 'submitVote'
        # keep the same phase
        contents['votes'] << voteinfo
        rewrite = true
      when 'cancelVote'
        contents['phase'] = 'cancelled'
        rewrite = true
      when 'tallyVote'
        contents['phase'] = 'tallied' # is that necessary? Can we tally again?
        rewrite = true # only needed if phase is updated

      # these are the discuss actions
      when 'submitComment', 'startVoting', 'invite' # discuss
        contents['comments'] << {
          comment: comment,
          member: member,
          timestamp: timestamp,
        }
        # Might be better for the caller to provide the new phase
        if action == 'startVoting'
          contents['phase'] = 'vote'
          contents['votes'] ||= [] # make sure there is a votes array
        end 
        contents['phase'] = 'invite' if action == 'invite'
        rewrite = true

      # unknown
      else
        raise "InvalidAction: #{action}" 
    end
    if rewrite
      f.rewind # back to start
      f.truncate(0) # need to empty the file otherwise can result in leftover data
      f.write(JSON.pretty_generate(contents))
    end
  end
  contents
end

# error handler
def process(data)
  contents = {}
  begin
    contents = update(data)
  rescue => e
    _error e.inspect
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
  def method_missing(m, *args) # handles _error etc
    $ret[m.to_s[1..-1]]=args[0] if m[0] == '_'
  end
  main(Hash[*ARGV])
  puts JSON.pretty_generate($ret) # output the return data
else
  embed # Sinatra sets params
end