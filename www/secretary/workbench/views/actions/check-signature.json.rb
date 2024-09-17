# frozen_string_literal: true

require 'uri'
require 'net/http'

MAX_KEY_SIZE = 125000 # don't import if the ascii keyfile is larger than this

# check signature on an attachment
#

if $0 == __FILE__
  require 'wunderbar'
  $LOAD_PATH.unshift '/srv/whimsy/lib'
  require 'whimsy/asf'
  require_relative '../../models/mailbox'
end

ENV['GNUPGHOME'] = GNUPGHOME if GNUPGHOME

# see WHIMSY-274 for secure servers
# ** N.B. ensure the keyserver URI is known below **

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

# fetch the Key from the URI and store in the file
def getURI(uri, file)
  uri = URI.parse(uri)
  opts = {use_ssl: uri.scheme == 'https'}
  # The pool needs a special CA cert
  Net::HTTP.start(uri.host, uri.port, opts ) do |https|
    https.request_get(uri.request_uri) do |res|
      unless res.code == '200'
        raise Exception.new("Get #{uri} failed with #{res.code}: #{res.message}")
      end
      cl = res.content_length
      if cl
        Wunderbar.warn "Content-Length: #{cl}"
        if cl > MAX_KEY_SIZE # fail early
          raise Exception.new("Content-Length: #{cl} > #{MAX_KEY_SIZE}")
        end
      else
        Wunderbar.warn 'Content-Length not provided, continuing'
      end
      File.open(file, 'w') do |f|
        # Save the data directly; don't store in memory
        res.read_body do |segment|
          f.write segment
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

def validate_sig(attachment, signature, msgid)
  # pick the latest gpg version
  gpg = `which gpg2`.chomp
  gpg = `which gpg`.chomp if gpg.empty?

  # run gpg verify command - this is needed to determine the key-id
  # TODO: may need to drop the keyid-format parameter when gpg is updated as it might
  # reduce the keyid length from the full fingerprint
  out, err, rc = Open3.capture3 gpg,
    '--keyid-format', 'long', # Show a longer id
    '--verify', signature.path, attachment.path

  # N.B. the code now always fetches the key, so it is guaranteed current.
  # Might need to consider allowing for using a cached key if fetches fail frequently,
  # but this should probably be on demand only

  # Allow auto key fetch to be turned off; create the file /srv/gpg/whimsy_use_db
  # This is intended for local testing
  fetchKey = !File.exist?('/srv/gpg/whimsy_use_db')
  # If the key is not in the database, we need to try and fetch it
  unless fetchKey
    if
      err.include? "gpg: Can't check signature: No public key" or
      err.include? "gpg: Can't check signature: public key not found"
    then
      fetchKey = true
    end
  end

  # Look for the keyid so we can fetch the current key
  keyid = err[/[RD]SA key (ID )?(\w+)/,2]

  # we have a keyid and we need to fetch it
  if keyid and fetchKey
  then
    # Try to fetch the key
    Dir.mktmpdir do |dir|
      found = false
      tmpfile = File.join(dir, keyid)
      KEYSERVERS.each do |server|
        begin
          uri = getServerURI(server, keyid)
          # get the public key if possible (throws if not)
          getURI(uri, tmpfile)
          # import the key for use in validation
          out, err, rc = Open3.capture3 gpg,
            '--batch', '--import', tmpfile
          # For later analysis
          Wunderbar.warn "#{gpg} --import #{tmpfile} rc=#{rc} out=#{out} err=#{err}"
          if err.include?('processed: 1') # downloaded key is valid; store it for posterity
            Dir.mktmpdir do |tmpdir|
              container = ASF::SVN.svnpath!('iclas', '__keys__')
              ASF::SVN.svn!('checkout',[container, tmpdir], {depth: 'empty', env: env})
              outfile = File.join(tmpdir, keyid)
              # Just in case we already have a copy
              ASF::SVN.svn!('update', outfile, {env: env})
              present = File.exist? outfile
              FileUtils.cp(tmpfile, outfile) # add the latest copy
              if present # must have been dropped from the pubkey database (or was maybe backfilled)
                Wunderbar.warn "Already have a copy of #{keyid}"
                # Has it changed?
                Wunderbar.warn ASF::SVN.svn('diff', outfile, {verbose: true}).inspect
              else # we have a new key
                ASF::SVN.svn!('add', outfile, {verbose: true})
              end
              ASF::SVN.svn!('commit', outfile, {msg: "Adding key for msgid: #{msgid}", env: env})
            end
          else
            Wunderbar.warn "Failed to import #{keyid}"
          end
          found = true
        rescue Exception => e
          Wunderbar.warn "GET uri=#{uri} e=#{e}"
          err = "Key #{keyid} not found: #{e.to_s}".dup # Dup needed to unfreeze string for later
        end
        break if found
      end
      if found

        # run gpg verify command again
        # TODO: may need to drop the keyid-format parameter when gpg is updated as it might
        # reduce the keyid length from the full fingerprint
        out, err, rc = Open3.capture3 gpg,
          '--keyid-format', 'long', # Show a longer id
          '--verify', signature.path, attachment.path
      end
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

  return out, err, rc
end

def process
  message = Mailbox.find(@message) # e.g. /secretary/workbench/yyyymm/123456789a/

  begin
    # fetch attachment and signature
    # e.g. icla.pdf and icla.pdf.asc
    attachment = message.find(URI::RFC2396_Parser.new.unescape(@attachment)).as_file # This is derived from a URI
    signature  = message.find(@signature).as_file # This is derived from the YAML file
    msgid = message.headers.select{|k,v| k.downcase == 'message-id'}.values.first

    out, err, rc = validate_sig(attachment, signature, msgid)

  ensure
    attachment.unlink if attachment
    signature.unlink if signature
  end

  return {output: out, error: err, rc: rc.exitstatus}
end

# Allow direct testing
if $0 == __FILE__
  yyyymmid = ARGV.shift or fail 'Need yyyymm/msgid'
  att = ARGV.shift || 'icla.pdf'
  sig = ARGV.shift || att + '.asc'
  @message = "/secretary/workbench/#{yyyymmid}/"
  @attachment=att
  @signature=sig
  ret = process
  if ret[:rc] == 0
    puts "Success: #{ret[:output]} #{ret[:error]}"
  else
    puts "Failure(#{ret[:rc]}): #{ret[:output]} #{ret[:error]}"
  end
else
  process # must be the last executable statement
end
