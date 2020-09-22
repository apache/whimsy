#
# Where to find the archive (remote and local)
#

if Dir.exist? '/srv/mail'
  SOURCE = 'whimsy.apache.org:/srv/mail/secretary'
  ARCHIVE = '/srv/mail/secretary'
else
  SOURCE = 'minotaur.apache.org:/home/apmail/private-arch/officers-secretary'
  ARCHIVE = File.basename(SOURCE)
end

#
# GPG's work directory override
#

GNUPGHOME = (Dir.exist?('/srv/gpg') ? '/srv/gpg' : nil)

# sks keyserver certificate locations for use with hkps.pool.sks-keyservers.net
# - whimsy on ubuntu
# - macos
%w{
   /usr/share/gnupg2/sks-keyservers.netCA.pem
   /usr/local/gnupg-2.2/share/gnupg/sks-keyservers.netCA.pem
   /usr/local/share/gnupg/sks-keyservers.netCA.pem
  }.each do |cert|
  if File.exist? cert
    SKS_KEYSERVER_CERT = cert
    break
  end
end
