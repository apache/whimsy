require 'erb'

require_relative '../../defines'

# TODO method this belongs elsewhere
def template(name)
  path = File.expand_path("../../../templates/#{name}.erb", __FILE__.untaint)
  ERB.new(File.read(path.untaint).untaint).result(binding)
end


# extract message headers
headers = Mailbox.hdrs(@id)

return {error: 'not found', id: @id} unless headers
  
allow = headers[:allow]
accept = headers[:accept]
reject = headers[:reject]

body = ''
case @action
  # These values must agree with messages.js.rb
  when ':Accept'
    to = accept
  when ':AcceptAllow'
    to = [accept, allow]
  when ':Reject'
    to = reject
    body = template('reject-off-topic') # TODO
  else
    return {error: 'action missing or unknown', action: @action}
end
#
# obtain per-user information
user = env.user
person = ASF::Person.find(user)

from = "#{person.public_name} <#{user}@apache.org>".untaint

#
#########################################################################
##                            build email                               #
#########################################################################
#
# build new message
mail = Mail.new
mail.subject = "#{@action} #{@id}"
mail.to = to
mail.from = from

mail.text_part = body

#  # deliver mail
#  complete do
#    mail.deliver!
#  end

{
  id: @id,
  action: @action,
#  headers: headers.inspect,
#  allow: allow,
#  accept: accept,
#  reject: reject,
#  from: from,
#  [:@_scope, :@_target, :@file, :@selected, :@name, :@default_layout, :@preferred_extension, :@app, :@template_cache, :@request, :@response]"
#  vars: self.instance_variables.inspect,
#  request: @request.inspect, # Sinatra
#  response: @response.inspect, # Sinatra
  mail: mail.to_s,
}