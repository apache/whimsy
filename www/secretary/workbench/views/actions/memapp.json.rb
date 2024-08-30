#
# File an membership application:
#  - add files to documents/member_apps
#  - add entry to foundation/members.txt
#  - update memapp-received.txt
#  - respond to original email
#

# extract message
message = Mailbox.find(@message)

# extract file extension
fileext = File.extname(@selected).downcase if @signature.empty?

# verify that a membership form under that name stem doesn't already exist
if "#{@filename}#{fileext}" =~ /\A\w[-\w]*\.?\w*\z/ # check taint requirements
  # returns name if it matches as stem or fully (e.g. for directory)
  ASF::MemApps.update_cache(env)
  form = ASF::MemApps.search @filename
  if form
    _warn "documents/member_apps/#{form} already exists"
  end
else
  _warn 'Invalid filename or extension'
end

_warn "Invalid availid #{@availid}" unless @availid =~ /^\w[-.\w]+$/

# obtain per-user information
_personalize_email(env.user)

# initialize commit message
@document = "Membership Application for #{@fullname}"

########################################################################
#                         document/member_apps                         #
#                             members.txt                              #
########################################################################

# write attachment (+ signature, if present) to the documents/member_apps
# directory
task "svn commit documents/member_apps/#{@filename}#{fileext} and update members.txt" do
  # Construct initial entry:
  fields = {
    fullname: @fullname,
    availid: @availid,
  }
  @entry = ASF::Member.make_entry(fields)

  form do
    _input value: @selected, name: 'selected'

    if @signature and not @signature.empty?
      _input value: @signature, name: 'signature'
    end

    _textarea @entry, name: 'entry', rows: @entry.split("\n").length
  end

  complete do

    svn_multi('foundation', 'members.txt', 'member_apps',
      @selected, @signature, @filename, fileext, message, @document) do |members_txt|

      # update members.txt
      # TODO this should be a library method
      pattern = /^Active.*?^=+\n+(.*?)^Emeritus/m
      data = members_txt.scan(pattern).flatten.first
      members = data.split(/^\s+\*\)\s+/)
      members.shift
      members.push @entry
      members_txt[pattern, 1] = ' *) ' + members.join("\n *) ")
      members_txt[/We now number (\d+) active members\./, 1] = members.length.to_s
      ASF::Member.sort(members_txt)
    end

  end
end

########################################################################
#             update cn=member,ou=groups,dc=apache,dc=org              #
########################################################################

task 'update cn=member,ou=groups,dc=apache,dc=org in LDAP' do
  form do
    _input value: @availid, name: 'availid'
  end

  complete do
    if ASF.memberids.include? @availid
      _transcript ["#{@availid} already in group member"]
    else
      ASF::LDAP.bind(env.user, env.password) do
        # TODO there ought to be a library method to do this
        ASF::LDAP.modify(ASF::Group['member'].dn, [ASF::Base.mod_add('memberUid', @availid)])
      end
    end
  end
end

########################################################################
#                   subscribe to members@apache.org                    #
########################################################################

task 'subscribe to members@apache.org' do
  user = ASF::Person.find(@availid)
  vars = {
    version: 3, # This must match committers/subscribe.cgi#FORMAT_NUMBER
    availid: @availid,
    addr: @availid + '@apache.org', # use ASF email here
    listkey: 'members@apache.org',
    member_p: true,
    chair_p: ASF.pmc_chairs.include?(user),
  }
  @subreq = JSON.pretty_generate(vars) + "\n"

  form do
    _textarea @subreq, name: 'subreq', rows: @subreq.split("\n").length
  end

  complete do
    # determine file name
    fn = "#{@availid}-members-#{Time.now.strftime '%Y%m%d-%H%M%S-%L'}.json"

    rc = ASF::SVN.create_(ASF::SVN.svnurl!('subreq'), fn, @subreq, @document, env, _)
    raise RuntimeError.new("exit code: #{rc}") if rc != 0
  end
end

########################################################################
#              subscribe to members-notify@apache.org                  #
########################################################################

task 'subscribe to members-notify@apache.org' do
  user = ASF::Person.find(@availid)
  vars = {
    version: 3, # This must match committers/subscribe.cgi#FORMAT_NUMBER
    availid: @availid,
    addr: @availid + '@apache.org', # use ASF email here
    listkey: 'members-notify@apache.org',
    member_p: true,
    chair_p: ASF.pmc_chairs.include?(user),
  }
  @subreq = JSON.pretty_generate(vars) + "\n"

  form do
    _textarea @subreq, name: 'subreq', rows: @subreq.split("\n").length
  end

  complete do
    # determine file name
    fn = "#{@availid}-members-notify-#{Time.now.strftime '%Y%m%d-%H%M%S-%L'}.json"

    rc = ASF::SVN.create_(ASF::SVN.svnurl!('subreq'), fn, @subreq, @document, env, _)
    raise RuntimeError.new("exit code: #{rc}") if rc != 0
  end
end

########################################################################
#                      update memapp-received.txt                      #
########################################################################

# TODO combine with other SVN updates

task 'svn commit memapp-received.text' do
  file = ASF::MeetingUtil.get_latest_file('memapp-received.txt')
  received = File.read(file)
  original = received[/.*\s#{@availid}\s.*/]
  @line = original.gsub('no ','yes')

  form do
    _input value: @line, name: 'line'
  end

  complete do
    meeting = file.split('/')[-2]
    path = ASF::SVN.svnpath!('Meetings', meeting,'memapp-received.txt')
    rc = ASF::SVN.update(path, @document, env, _, {diff: true}) do |_tmpdir, input|
      input.sub!(original, @line)
      input
    end
    raise RuntimeError.new("exit code: #{rc}") if rc != 0
  end
end

########################################################################
#                           email submitter                            #
########################################################################

# send confirmation email
task "email #@email" do
  # build mail from template
  mail = message.reply(
    subject: @document,
    from: @from,
    to: "#{@fullname.inspect} <#{@email}>",
    cc: 'secretary@apache.org',
    body: template('mem.erb')
  )

  # drop members@ from the replies
  if mail.cc.include? 'members@apache.org'
    mail.cc = mail['cc'].value.select {|name| name !~ /\bmembers@apache.org\b/}
  end

  # echo email
  form do
    _message mail.to_s
  end

  # deliver mail
  complete do
    mail.deliver!
  end
end
