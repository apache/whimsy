##   Licensed to the Apache Software Foundation (ASF) under one or more
##   contributor license agreements.  See the NOTICE file distributed with
##   this work for additional information regarding copyright ownership.
##   The ASF licenses this file to You under the Apache License, Version 2.0
##   (the "License"); you may not use this file except in compliance with
##   the License.  You may obtain a copy of the License at
## 
##       http://www.apache.org/licenses/LICENSE-2.0
## 
##   Unless required by applicable law or agreed to in writing, software
##   distributed under the License is distributed on an "AS IS" BASIS,
##   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
##   See the License for the specific language governing permissions and
##   limitations under the License.

#
# check signature on an attachment
#

ENV['GNUPGHOME'] = GNUPGHOME if GNUPGHOME

#KEYSERVER = 'pgpkeys.mit.edu'
# Perhaps also try keyserver.pgp.com
KEYSERVERS = %w{hkps.pool.sks-keyservers.net keyserver.ubuntu.com pgpkeys.mit.edu}

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
    keyid = err[/[RD]SA key (ID )?(\w+)/,2].untaint

    out2, err2 = '' # needed later
    KEYSERVERS.each do |server|
      out2, err2, rc2 = Open3.capture3 gpg, '--keyserver', server,
        '--debug', 'ipc', # seems to show communication with dirmngr
        '--recv-keys', keyid
      # for later analysis
      Wunderbar.warn "#{gpg} --keyserver #{server} --recv-keys #{keyid} rc2=#{rc2} out2=#{out2} err2=#{err2}"
      if rc2.exitstatus == 0 # Found the key
        out2 = err2 = '' # Don't add download error to verify error
        break
      end
    end
  
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
