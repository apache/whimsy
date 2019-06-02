# Utility functions used throughout roster tool
class Utils

  # Common processing to handle a response that is expected to be JSON
  def self.handle_json(response, success)
    content_type = response.headers.get('content-type') || ''
    isJson = content_type.include? 'json'
    if response.status == 200 and isJson
      response.json().then do |json|
        success json
      end
    else
      footer = 'See server log for full details'
      if isJson
        response.json().then do |json|
          # Pick out the exception
          message = json['exception'] || ''
          alert "#{response.status} #{response.statusText}\n#{message}\n#{footer}"
        end
      else # not JSON
        response.text() do |text|
          alert "#{response.status} #{response.statusText}\n#{text}\n#{footer}"
        end
      end
    end
  end
  
  # Deliver an LDAP notification email, e.g. pmc/ppmc/group/etc. changes
  # Uses creates and mail.deliver! using a template for body
  # Includes X-headers to mark as Whimsy email
  # DEBUGGING: options: true to prevent actual mail sending
  def self.mail_ldap_notification(
    from,
    to,
    cc,
    bcc,
    subject,
    template,
    data, # Hash for ERB
    options
  )
    # TODO how should this method report problems?
    raise ArgumentError, "From must not be nil or blank" if from.nil? || from == ''
    raise ArgumentError, "To or CC must not be nil" if to.nil? && cc.nil?
    raise ArgumentError, "Subject must not be nil or blank" if subject.nil? || subject == ''
    raise ArgumentError, "Template must not be nil or blank" if template.nil? || template == ''
    
    path = File.expand_path("../../templates/#{template}", __FILE__.untaint)
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
