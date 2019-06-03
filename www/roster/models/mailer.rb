#
# Provide simple way to send notification emails.
#
# Once tested, this code could migrate into whimsy/asf, and be available
# for all Rack application (e.g., secmail, board/agenda, roster)
#

# provide methods to encapsulate LDAP update
module ASF
  class Mailer
    # Deliver an LDAP notification email, e.g. pmc/ppmc/group/etc. changes
    # Uses creates and mail.deliver! using a template for body
    # Includes X-headers to mark as Whimsy email
    # DEBUGGING: options: true to prevent actual mail sending
    def self.mail_ldap_notification(
      from: nil,
      to: nil,
      cc: nil,
      bcc: nil,
      subject: nil,
      template: nil,
      data: nil, # Hash for ERB
      options: nil
    )
      # TODO how should this method report problems?
      raise ArgumentError, "From must not be nil or blank" if from.nil? || ''.eql?(from)
      raise ArgumentError, "To or CC must not be nil" if to.nil? && cc.nil?
      raise ArgumentError, "Subject must not be nil or blank" if subject.nil? || ''.eql?(subject)
      template ||= 'ldap_notification.erb'
      
      path = File.expand_path("../templates/#{template}", __FILE__.untaint)
      file = File.join(path, template)
      puts "-> #{path} #{template} #{file}"
      tmplt = File.read(file.untaint).untaint
      mail = Mail.new do
        from from
        to to
        cc cc
        bcc bcc
        subject subject
        b = binding # Bind the passed in data hash to send to ERB
        data.each do |key, val|
          b.local_variable_set(key.to_sym, val)
        end
        body ERB.new(tmplt).result(b) 
      end

      # Header for root@ mail filters, per request infra
      mail.header['X-For-Root'] = 'yes'
      # Header to denote automated mail from whimsy
      mail.header['X-Mailer'] = 'whimsy/www/roster/utils(0.1)'

      # Deliver email
      mail.delivery_method :test if options # TODO DEBUGGING don't actually send mail, just log it
      mail.deliver!
      return mail
    end
  end
end
