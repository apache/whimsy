#
# check signature on an attachment
#

ENV['GNUPGHOME'] = GNUPGHOME if GNUPGHOME

message = Mailbox.find(@message)

begin
  # fetch attachment and signature
  attachment = message.find(URI.decode(@attachment)).as_file # This is derived from a URI
  signature  = message.find(@signature).as_file # This is derived from the YAML file

  # pick the latest gpg version
  gpg = `which gpg2`.chomp
  gpg = `which gpg`.chomp if gpg.empty?
  gpg.untaint

  # run gpg verify command
  out, err, rc = Open3.capture3 gpg, '--verify', signature.path,
    attachment.path

  # if key is not found, fetch and try again
  if 
    err.include? "gpg: Can't check signature: No public key" or
    err.include? "gpg: Can't check signature: public key not found"
  then
    # extract and fetch key
    keyid = err[/[RD]SA key (ID )?(\w+)/,2].untaint

    out2, err2, rc2 = Open3.capture3 gpg, '--keyserver', 'pgpkeys.mit.edu',
      '--keyserver-options', 'verbose',
      '--recv-keys', keyid

    # run gpg verify command again
    out, err, rc = Open3.capture3 gpg, '--verify', signature.path,
      attachment.path

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
