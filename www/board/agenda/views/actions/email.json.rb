#
# send email
#

ASF::Mail.configure

# extract values for each field
to, cc, subject, body = @to, @cc, @subject, @body

# construct from address
sender = ASF::Person.find(env.user)
from = "#{sender.public_name.inspect} <#{sender.id}@apache.org>"

# construct email
mail = Mail.new do
  from from
  to to
  cc cc if cc and not cc.empty?
  subject subject

  body body
end

# deliver mail
mail.deliver!

# return email in the response
{mail: mail.to_s}
