# frozen_string_literal: true

require 'uri'

# check signature on an attachment
#

ENV['GNUPGHOME'] = GNUPGHOME if GNUPGHOME

# see WHIMSY-274 for secure servers
# ** N.B. ensure the keyserver URI is known below **

# Restored keys.openpgp.org; sks-keryservers is dead; we can do without email
# gozer.rediris.es certificate has expired
KEYSERVERS = %w{keyserver.ubuntu.com}
# openpgp does not return the uid needed by gpg

# ** N.B. ensure the keyserver URI is known below **
def getServerURI(server, keyid)
  if server == 'keys.openpgp.org'
    if keyid.length == 40
      uri = "https://#{server}/vks/v1/by-fingerprint/#{keyid}"
    else
      uri = "https://#{server}/vks/v1/by-keyid/#{keyid}"
    end
  elsif server == 'keyserver.ubuntu.com'
    uri = "https://#{server}/pks/lookup?search=0x#{keyid}&op=get"
  else
    # default to format used by sks-keyserver pool members
    uri = "https://#{server}/pks/lookup?search=0x#{keyid}&exact=on&options=mr&op=get"
  end
  Wunderbar.warn uri
  return uri
end

MAX_KEY_SIZE = 125000 # don't import if the ascii keyfile is larger than this

require 'net/http'

# fetch the Key from the URI and store in the file
def getURI(uri, file)
  uri = URI.parse(uri)
  opts = {use_ssl: uri.scheme == 'https'}
  # The pool needs a special CA cert
  Net::HTTP.start(uri.host, uri.port, opts ) do |https|
    https.request_get(uri.request_uri) do |res|
      unless res.code == "200"
        raise Exception.new("Get #{uri} failed with #{res.code}: #{res.message}")
      end
      cl = res.content_length
      if cl
        Wunderbar.warn "Content-Length: #{cl}"
        if cl > MAX_KEY_SIZE # fail early
          raise Exception.new("Content-Length: #{cl} > #{MAX_KEY_SIZE}")
        end
      else
        Wunderbar.warn "Content-Length not provided, continuing"
      end
      File.open(file, "w") do |f|
        # Save the data directly; don't store in memory
        res.read_body do |segment|
          f.puts segment
        end
      end
      size = File.size(file)
      Wunderbar.warn "File: #{file} Size: #{size}"
      if size > MAX_KEY_SIZE
        raise Exception.new("File: #{file} size #{size} > #{MAX_KEY_SIZE}")
      end
    end
  end
end

message = Mailbox.find(@message)

begin
  # fetch attachment and signature
  attachment = message.find(URI::RFC2396_Parser.new.unescape(@attachment)).as_file # This is derived from a URI
  signature  = message.find(@signature).as_file # This is derived from the YAML file

  # pick the latest gpg version
  gpg = `which gpg2`.chomp
  gpg = `which gpg`.chomp if gpg.empty?

  # run gpg verify command
  # TODO: may need to drop the keyid-format parameter when gpg is updated as it might
  # reduce the keyid length from the full fingerprint
  out, err, rc = Open3.capture3 gpg,
    '--keyid-format', 'long', # Show a longer id
    '--verify', signature.path, attachment.path

  # if key is not found, fetch and try again
  if
    err.include? "gpg: Can't check signature: No public key" or
    err.include? "gpg: Can't check signature: public key not found"
  then
    # extract and fetch key
    keyid = err[/[RD]SA key (ID )?(\w+)/,2]

    out2 = err2 = '' # needed later

    #+++ TEMPORARY HACK (WHIMSY-275)

#    KEYSERVERS.each do |server|
#      out2, err2, rc2 = Open3.capture3 gpg, '--keyserver', server,
#        '--debug', 'ipc', # seems to show communication with dirmngr
#        '--recv-keys', keyid
#      # for later analysis
#      Wunderbar.warn "#{gpg} --keyserver #{server} --recv-keys #{keyid} rc2=#{rc2} out2=#{out2} err2=#{err2}"
#      if rc2.exitstatus == 0 # Found the key
#        out2 = err2 = '' # Don't add download error to verify error
#        break
#      end
#    end

    KEYSERVERS.each do |server|
      found = false
      Dir.mktmpdir do |dir|
        begin
          tmpfile = File.join(dir, keyid)
          uri = getServerURI(server, keyid)
          getURI(uri, tmpfile)
          out2, err2, rc2 = Open3.capture3 gpg,
            '--batch', '--import', tmpfile
          # For later analysis
          Wunderbar.warn "#{gpg} --import #{tmpfile} rc2=#{rc2} out2=#{out2} err2=#{err2}"
          found = true
        rescue Exception => e
          Wunderbar.warn "GET uri=#{uri} e=#{e}"
          err2 = e.to_s
        end
      end
      break if found
    end
    #--- TEMPORARY HACK (WHIMSY-275)

    # run gpg verify command again
    # TODO: may need to drop the keyid-format parameter when gpg is updated as it might
    # reduce the keyid length from the full fingerprint
    out, err, rc = Open3.capture3 gpg,
      '--keyid-format', 'long', # Show a longer id
      '--verify', signature.path, attachment.path

    # if verify failed, concatenate fetch output
    if rc.exitstatus != 0
      out += out2
      err += err2
    end
  end

  # list of strings to ignore
  ignore = [
    /^gpg:\s+WARNING: This key is not certified with a trusted signature!$/,
    /^gpg:\s+There is no indication that the signature belongs to the owner\.$/
  ]

  unless err.valid_encoding?
    err = err.force_encoding('windows-1252').encode('utf-8')
  end

  ignore.each {|re| err.gsub! re, ''}

ensure
  attachment.unlink if attachment
  signature.unlink if signature
end

{output: out, error: err, rc: rc.exitstatus}
