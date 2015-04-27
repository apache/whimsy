#
# chat message received from the client
#

Events.post type: :chat, user: env.user, text: @text,
  timestamp: Time.now.to_f*1000
