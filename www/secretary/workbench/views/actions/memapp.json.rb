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

# verify that a membership form under that name doesn't already exist
if "#@filename#{fileext}" =~ /\w[-\w]*\.?\w*/
  form = "#{ASF::SVN['member_apps']}/#@filename#{fileext}"
  if File.exist? form.untaint
    _warn "documents/member_apps/#@filename#{fileext} already exists"
  end
end

# obtain per-user information
_personalize_email(env.user)

# initialize commit message
@document = "Membership Application for #{@fullname}"

########################################################################
#                         document/member_apps                         # 
########################################################################

# write attachment (+ signature, if present) to the documents/member_apps
# directory
task "svn commit documents/member_apps/#@filename#{fileext}" do
  form do
    _input value: @selected, name: 'selected'

    if @signature and not @signature.empty?
      _input value: @signature, name: 'signature'
    end
  end

  complete do |dir|
    # checkout empty directory
    svn 'checkout', '--depth', 'empty',
      'https://svn.apache.org/repos/private/documents/member_apps',
      "#{dir}/member_apps"

    # create/add file(s)
    dest = message.write_svn("#{dir}/member_apps", @filename, @selected,
      @signature)

    # Show files to be added
    svn 'status', "#{dir}/member_apps"

    # commit changes
    svn 'commit', "#{dir}/member_apps/#{@filename}#{fileext}", '-m', @document
  end
end

########################################################################
#                             members.txt                              #
########################################################################

# insert entry into members.txt
task "svn commit foundation/members.txt" do
  # construct line to be inserted
  @entry = [
    "#{@fullname}",
    "#{@addr.gsub(/^/,'    ').gsub(/\r/,'')}",
    ("    #{@country}"     unless @country.empty?),
    "    Email: #{@email}",
    ("      Tel: #{@tele}" unless @tele.empty?),
    ("      Fax: #{@fax}"  unless @fax.empty?),
    " Forms on File: ASF Membership Application",
    " Avail ID: #{@availid}"
  ].compact.join("\n") + "\n"

  form do
    _textarea @entry, name: 'entry', rows: @entry.split("\n").length
  end

  complete do |dir|
    # checkout empty foundation directory
    svn 'checkout', '--depth', 'empty',
      'https://svn.apache.org/repos/private/foundation', "#{dir}/foundation"

    # retrieve members.txt
    dest = "#{dir}/foundation/members.txt"
    svn 'update', dest

    # update members.txt
    pattern = /^Active.*?^=+\n+(.*?)^Emeritus/m
    members_txt = open(dest).read
    data = members_txt.scan(pattern).flatten.first
    members = data.split(/^\s+\*\)\s+/)
    members.shift
    members.push @entry
    members_txt[pattern,1] = " *) " + members.join("\n *) ")
    members_txt[/We now number (\d+) active members\./,1] = members.length.to_s
    File.write(dest, ASF::Member.sort(members_txt))

    # show the changes
    svn 'diff', dest

    # commit changes
    svn 'commit', dest, '-m', @document
  end
end

########################################################################
#             update cn=member,ou=groups,dc=apache,dc=org              #
########################################################################

task "update cn=member,ou=groups,dc=apache,dc=org in LDAP" do
  form do
    _input value: @availid, name: 'availid'
  end

  complete do
    ldap = ASF.init_ldap(true)
    if ASF::Group.find('member').include? ASF::Person.find(@availid)
      _transcript ["#@availid already in group member"]
    else
      ldap.bind("uid=#{env.user.untaint},ou=people,dc=apache,dc=org",
        env.password.untaint)

      ldap.modify "cn=member,ou=groups,dc=apache,dc=org",
        [LDAP.mod(LDAP::LDAP_MOD_ADD, 'memberUid', [@availid])]

      log = ["LDAP mod add: #{ldap.err2string(ldap.err)} (#{ldap.err})"]
      if ldap.err == 0
        _transcript log
      else
        _backtrace log
      end

      ldap.unbind
    end
  end
end

########################################################################
#                   subscribe to members@apache.org                    #
########################################################################

task "subscribe to members@apache.org" do
  user = ASF::Person.find(@availid)
  vars = {
    version: 3, # This must match http://s.apache.org/008
    availid: @availid,
    addr: @email,
    listkey: 'members',
    member_p: true,
    chair_p: ASF.pmc_chairs.include?(user),
  }
  @subreq = JSON.pretty_generate(vars) + "\n"

  form do
    _textarea @subreq, name: 'subreq', rows: @subreq.split("\n").length
  end

  complete do |dir|
    # determine file name
    fn = "#{@availid}-members-#{Time.now.strftime '%Y%m%d-%H%M%S-%L'}.json"
    fn.untaint if @availid =~ /^\w[-.\w]+$/

    # checkout empty directory
    svn 'checkout', '--depth', 'empty',
      "https://svn.apache.org/repos/infra/infrastructure/trunk/subreq",
      "#{dir}/subreq"

    # write out subscription request
    File.write "#{dir}/subreq/#{fn}", @subreq
    Kernel.system 'svn', 'add', "#{dir}/subreq/#{fn}"

    # Show changes
    svn 'diff', "#{dir}/subreq"

    # commit changes
    svn 'commit', "#{dir}/subreq", '-m', @document
  end
end

########################################################################
#                      update memapp-received.txt                      #
########################################################################

task "svn commit memapp-received.text" do
  meetings = ASF::SVN['Meetings']
  file = Dir["#{meetings}/2*/memapp-received.txt"].sort.last.untaint
  received = File.read(file)
  if received =~ /^no\s+\w+\s+\w+\s+\w+\s+#{@availid}\s/
    received[/^(no )\s+\w+\s+\w+\s+\w+\s+#{@availid}\s/,1] = 'yes'
  end
  received[/(no )\s+\w+\s+\w+\s+#{@availid}\s/,1] = 'yes'
  received[/(no )\s+\w+\s+#{@availid}\s/,1] = 'yes'
  received[/(no )\s+#{@availid}\s/,1] = 'yes'
  @line = received[/.*\s#{@availid}\s.*/]

  form do
    _input value: @line, name: 'line'
  end

  complete do |dir|
    # checkout empty directory
    meeting = file.split('/')[-2]
    svn 'checkout', '--depth', 'empty',
      "https://svn.apache.org/repos/private/foundation/Meetings/#{meeting}",
      "#{dir}/#{meeting}"

    # retrieve memapp-received.txt
    dest = "#{dir}/#{meeting}/memapp-received.txt"
    svn 'update', dest

    # create/add file(s)
    received = File.read(dest)
    received[/.*\s#{@availid}\s.*/] = @line
    File.write(dest, received)

    # Show changes
    svn 'diff', "#{dir}/#{meeting}"

    # commit changes
    svn 'commit', "#{dir}/#{meeting}/memapp-received.txt", '-m', @document
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
