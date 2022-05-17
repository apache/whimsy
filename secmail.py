#!/usr/bin/python

"""
The purpose of this script is to find attachments to email messages that
are sent to secretary@apache.org and commit them into svn:documents/received.

This task is made more difficult by the fact that email often uses payloads
for reasons other than attachments, from time to time we get spam, some
people routinely pgp sign all of their emails, and others use pgp signatures
to sign forms.

Deciding what to commit is therefore, necessarily, a bit of heuristics.  When
in doubt, the intent here is to err on the side of committing more than is
necessary than to miss an email.

Examples of heurisitics:
 * Images less than 10K bytes tend to be decorations for HTML formatted
   spam emails, and are not likely to be scanned forms.
 * text/plain email that contain a PGP signature and the ASF fax number
   are likely to be signed forms.
"""

import email
import gzip
import mailbox
import rfc822
import mimetypes
import os
from datetime import datetime
from email.header import decode_header
from glob import glob
import re
from subprocess import Popen, PIPE
from threading import Thread
import commands
import getpass

try:
  from hashlib import md5
except ImportError:
  from md5 import new as md5

# attachment types which generally are not saved.
skip = ['multipart/alternative', 'multipart/related', 'multipart/mixed',
        'message/delivery-status', 'text/plain', 'text/html']

# attachment file names which always are saved, even if they come in
# with one of the 'skip' mime types.
forms = ['pgp.txt', 'icla.txt', 'icla.txt.asc', 'icla.pdf', 'icla.pdf.asc', 'membership-application.txt']

# mime types for pgp signatures
sigs  = ['application/pkcs7-signature', 'application/pgp-signature']

# convert header from whatever encoding it is in to utf-8.  Handle
# mislabelled encodings.
def decode(header, field=0):
  if isinstance(header, unicode):
    data = (header.encode('utf-8'), 'utf-8')
  else:
    data = decode_header(header)[field]

  try:
    return data[0].decode(data[1]).encode('utf-8')
  except:
    return data[0].decode('iso-8859-1').encode('utf-8')

# convert non-ascii characters into rough equivalents for the purpose
# of determining a file name to store in SVN.
def asciize(name):
  if re.search(r"[^\x00-\x7F]", name):
    # digraphs.  May be culturally sensitive
    name=re.sub(r"\xc3\x9f", 'ss', name)
    name=re.sub(r"\xc3\xa4|a\xcc\x88", 'ae', name)
    name=re.sub(r"\xc3\xa5|a\xcc\x8a", 'aa', name)
    name=re.sub(r"\xc3\xa6", 'ae', name)
    name=re.sub(r"\xc3\xb1|n\xcc\x83", 'ny', name)
    name=re.sub(r"\xc3\xb6|o\xcc\x88", 'oe', name)
    name=re.sub(r"\xc3\xbc|u\xcc\x88", 'ue', name)

    # latin 1
    name=re.sub(r"\xc3[\xa0-\xa5]", 'a', name)
    name=re.sub(r"\xc3\xa7", 'c', name)
    name=re.sub(r"\xc3[\xa8-\xab]", 'e', name)
    name=re.sub(r"\xc3[\xac-\xaf]", 'i', name)
    name=re.sub(r"\xc3[\xb2-\xb6]|\xc3\xb8", 'o', name)
    name=re.sub(r"\xc3[\xb9-\xbc]", 'u', name)
    name=re.sub(r"\xc3[\xbd\xbf]", 'y', name)

    # Latin Extended-A
    name=re.sub(r"\xc4[\x80-\x85]", 'a', name)
    name=re.sub(r"\xc4[\x86-\x8d]", 'c', name)
    name=re.sub(r"\xc4[\x8e-\x91]", 'd', name)
    name=re.sub(r"\xc4[\x92-\x9b]", 'e', name)
    name=re.sub(r"\xc4[\x9c-\xa3]", 'g', name)
    name=re.sub(r"\xc4[\xa4-\xa7]", 'h', name)
    name=re.sub(r"\xc4[\xa8-\xb1]", 'i', name)
    name=re.sub(r"\xc4[\xb2-\xb3]", 'ij', name)
    name=re.sub(r"\xc4[\xb4-\xb5]", 'j', name)
    name=re.sub(r"\xc4[\xb6-\xb8]", 'k', name)
    name=re.sub(r"\xc4[\xb9-\xff]|\xc5[\x80-\x82]", 'l', name)
    name=re.sub(r"\xc5[\x83-\x8b]", 'n', name)
    name=re.sub(r"\xc5[\x8c-\x91]", 'o', name)
    name=re.sub(r"\xc5[\x92-\x93]", 'oe', name)
    name=re.sub(r"\xc5[\x94-\x99]", 'r', name)
    name=re.sub(r"\xc5[\x9a-\xa2]", 's', name)
    name=re.sub(r"\xc5[\xa2-\xa7]", 't', name)
    name=re.sub(r"\xc5[\xa8-\xb3]", 'u', name)
    name=re.sub(r"\xc5[\xb4-\xb5]", 'w', name)
    name=re.sub(r"\xc5[\xb6-\xb8]", 'y', name)
    name=re.sub(r"\xc5[\xb9-\xbe]", 'z', name)

    # denormalized diacritics
    name=re.sub(r"\xcc[\x80-\xff]|\xcd[\x80-\xaf]", '', name)

  return re.sub(r"[^.\w]+", '-', name)

# add svn at sign if necessary
def svn(command, file):
  command = 'svn ' + command + ' ' + file
  if '@' in file: command = command + '@'
  # import sys
  # sys.stderr.write(command+"\n")
  return os.system(command)

# spam assassin client
def analyze(msg):
  spamc = Popen('spamc', shell=True, stdin=PIPE, stdout=PIPE)
  class passthru(Thread):
    def __init__(self, stdin, msg):
      Thread.__init__(self)
      self.msg = msg
      self.stdin = stdin
    def run(self):
      try:
        email.generator.Generator(self.stdin).flatten(self.msg)
      except:
        pass
      self.stdin.close()
  thread = passthru(spamc.stdin, msg)
  thread.start()
  subject = msg['subject']
  msg = email.message_from_file(spamc.stdout)
  msg['subject'] = subject # spamc mangles encoded strings
  setattr(msg, 'spam', str(msg['X-Spam-Status']).startswith('Yes'))
  thread.join()
  spamc.wait()
  spamc.stdout.close()
  return msg

# main logic for this script: process attachments for a single message
def detach(msg):
  # quick exit if we have seen this entry before
  if not msg['message-id']: return
  mid = md5(msg['message-id']).hexdigest()
  if os.path.exists(os.path.join('tally',mid)): return

  # known spammers
  if '<r_ieftin@yahoo.ro>' in msg['from']:
    return

  # collect eligible attachments
  attachments = []
  for payload in msg.get_payload():

    # progress into multipart/mixed
    if payload.get_content_type() == 'multipart/mixed':
      payload = payload.get_payload()
    else:
      payload = [payload]

    # iterate over (possibly nested) attachments
    for subpayload in payload:
      if subpayload.get_content_type() in skip:
        if subpayload.get_filename() not in forms: continue
        content = subpayload.get_payload(decode=True)
        if 'License Agreement' not in content and \
          '-----BEGIN PGP SIGNATURE-----' not in content:
          continue
      if subpayload.get_content_type() == 'image/gif':
        if len(subpayload.get_payload(decode=True))<10240: continue
      # if not subpayload.get_payload(decode=True): continue

      # get_filename doesn't appear to have an endswith method
      # if subpayload.get_filename().endswith('.gpg'): continue
      attachments.append(subpayload)

  if len(attachments) == 0: return

  if os.system('svn update received') != 0:
    return

  ## COMMENTED OUT - AS SPAMC IS NOT INSTALLED HERE
  #
  # if 'eFax message from' not in decode(msg['subject']):
  #   msg = analyze(msg)
  #   if msg.spam:
  #     attachments = []

  # determine output file name prefix
  prefix = ''
  if len(attachments) > 1:
    prefix = rfc822.parseaddr(decode(msg['from']).decode('utf-8'))[1]
    received = os.path.join('received',prefix)
    if (not re.match(r'^[.@\w]+$',prefix)) or os.path.exists(received):
      dirname = datetime(*email.utils.parsedate(msg['date'])[:7]).isoformat()
      prefix = dirname.replace(':','_').replace('-','_')
      received = os.path.join('received',prefix)
    if not os.path.exists(received): os.mkdir(received)
    svn('add', received)
    prefix += os.sep
  elif len(attachments) == 1:
    name=asciize(decode(attachments[0].get_filename()))
    if not name: return
    if attachments[0].get_content_type() in sigs: return
    if len(name)<16:
      prefix = decode(msg['from'])
      if prefix.startswith('"eFax"'):
        prefix = 'eFax'
      else:
        prefix = asciize(prefix)
        if prefix.find('<')>=0: prefix = prefix.split('<')[1]
        prefix = prefix.split('@')[0]
      prefix = prefix + '-'
    try:
      name.decode('utf-8')
    except:
      name=name.decode('iso-8859-1').encode('utf-8')

  # determine commit message
  summary = "\n".join([
    'Subject: ' + decode(msg['subject']),
    'From: ' + decode(msg['from']),
    'Date: ' + str(msg['date']),
    'Message-Id: ' + str(msg['message-id']),
    'X-Spam-Status' + str(msg['X-Spam-Status']),
  ])

  count = 0
  file = None

  # decode payloads and place add to svn
  for attachment in attachments:
    mime = attachment.get_content_type()
    if mime == 'application/octet-stream':
      mime = mimetypes.guess_type(decode(attachment.get_filename()))[0]
    name=asciize(decode(attachment.get_filename()))
    if name=='none': name=str(dict(attachment.get_params()).get('name'))

    content = attachment.get_payload(decode=True)
    if content:
      file=os.path.join('received',(prefix+name).strip('-'))
      if os.path.isdir(file): file = os.path.join(file, 'unnamed')
      fh=open(file,'w')
      fh.write(content)
      fh.close()

      svn('add', file)
      if mime: svn('propset svn:mime-type ' + mime, file)
      count = count + 1

  if count>1: file = os.path.join('received',prefix.strip('-'))

  try:
    name = decode(msg['from'],0)
    try:
      addr = rfc822.parseaddr(decode(msg['from'],1))[1]
    except:
      name, addr = rfc822.parseaddr(name)

    if name != 'eFax' and file:
      props = {
        'email:id': msg['message-id'],
        'email:subject': re.sub(r'\n\s*', ' ', decode(msg['subject']))
      }
      if name: props['email:name'] = name
      if addr: props['email:addr'] = addr
      if msg['cc']: props['email:cc'] =  re.sub(r'\s+', ' ', decode(msg['cc']))
      for (key, value) in props.items():
        svn('propset ' + key + ' ' + repr(value), file)
  except:
    pass

  tally = os.path.join('tally',mid)
  fh=open(tally,'w')
  fh.write(summary + "\n")
  fh.close()

  if count>0 and getpass.getuser() != 'www-data':
    if svn('commit --file ' + tally, file) != 0:
      return # try again next cron cycle

if __name__ == "__main__":
  if os.path.exists('/home/apmail/private-arch/officers-secretary'):
    archive = '/home/apmail/private-arch/officers-secretary/20*'
    os.chdir('/home/apmail/secretary-mail')
    previous = os.stat('latest').st_mtime
  elif os.path.exists('mailbox'):
    archive = 'mailbox'
    previous = int(os.stat(archive).st_mtime) - 1
  else:
    import sys
    sys.stderr.write("can't find mailbox.  Exiting.\n")
    sys.exit(1)

  latest = previous
  last_processed = None

  # process updated mbox files
  for file in glob(archive):
    if int(previous) >= int(os.stat(file).st_mtime): continue

    # open gzipped/raw file
    if file.endswith('.gz'):
      fh=gzip.open(file)
    else:
      fh=open(file)

    # process each multipart message in the mailbox 
    for msg in iter(mailbox.UnixMailbox(fh, email.message_from_file)):
      last_processed = msg['Date']

      if msg.is_multipart():
        detach(msg)
      elif '919-573-9199' in msg.get_payload():
        if '-----BEGIN PGP SIGNATURE-----' in msg.get_payload().split("\n"):
          msg.add_header('Content-Disposition', 'attachment',
            filename='pgp.txt')
          wrapper=email.message.Message()
          wrapper.attach(msg)
          for header in msg.keys(): wrapper[header]=msg[header]
          detach(wrapper)

    # keep track of the latest
    if latest < os.stat(file).st_mtime:
      latest = os.stat(file).st_mtime

  # record where we are so that the next run can pick up where we left off
  if latest > previous:
    os.utime('latest', (latest, latest))
     
  # check for any incomplete removals
  if commands.getoutput('svn status received') != '':
    os.system("svn st received | grep '!' | cut -c 8- | xargs -r svn revert --")

  # check for any incomplete commits
  if commands.getoutput('svn status received') != '':
    if getpass.getuser() != 'www-data':
      os.system('svn commit -m "queued documents" received')

  # update web page with last processed information
  if last_processed and os.path.exists('../public_html/secmail.txt'):
    with open('../public_html/secmail.txt', 'w') as fh:
      fh.write("Latest email processed was sent: %s" % last_processed)
