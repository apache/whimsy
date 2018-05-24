# send summary email to committers
header, body = @text.untaint.split(/\r?\n\r?\n/, 2)
header.gsub! /\r?\n/, "\r\n"

mail = Mail.new("#{header}\r\n\r\n#{body}")
mail.deliver!

{delivered: true, mail: mail.to_s}
