#
# File an additional ICLA:
#  - [optional] move existing ICLA into a directory
#  - add files to (new) documents/iclas direcotry
#  - modify officers/iclas.txt entry
#  - respond to original email
#

# extract message
message = Mailbox.find(@message)

# extract file extension
fileext = File.extname(@selected).downcase if @signature.empty?

# obtain per-user information
_personalize_email(env.user)

########################################################################
#                        move existing document                        #
########################################################################

iclas = ASF::SVN['private/documents/iclas'].untaint
@filename.untaint if @filename =~ /\A\w[-.\w]*\Z/

if not Dir.exist? "#{iclas}/#@filename"
  @existing = File.basename(Dir["#{iclas}/#@filename.*"].first)
  task "svn mv #@existing #@filename/icla#{File.extname(@existing)}" do
    form do
      _input value: @existing, name: 'existing'
    end

    complete do
    end
  end
end

########################################################################
#                            document/iclas                            #
########################################################################

# write attachment (+ signature, if present) to the documents/iclas directory
task "svn commit documents/iclas/#@filename#{fileext}" do
  form do
    _input value: @selected, name: 'selected'

    if @signature and not @signature.empty?
      _input value: @signature, name: 'signature'
    end
  end

  complete do |dir|
    # checkout empty directory
    svn 'checkout', '--depth', 'empty',
      'https://svn.apache.org/repos/private/documents/iclas', "#{dir}/iclas"

    # create/add file(s)
    if @signature.to_s.empty? or fileext != '.pdf'
      message.write_svn("#{dir}/iclas", @filename, @selected, @signature)
    else
      message.write_svn("#{dir}/iclas", @filename, 
        @selected => 'icla.pdf', @signature => 'icla.pdf.asc')
    end

    # Show files to be added
    svn 'status', "#{dir}/iclas"

    # commit changes
    svn 'commit', "#{dir}/iclas/#{@filename}#{fileext}",
      '-m', "ICLA from #{@pubname}"
  end
end

########################################################################
#                          officers/iclas.txt                          #
########################################################################

# insert line into iclas.txt
task "svn commit foundation/officers/iclas.txt" do
  # construct line to be inserted
  @iclaline ||= [
    'notinavail',
    @realname.to_s.strip,
    @pubname.strip,
    @email.strip,
    "Signed CLA;#{@filename}"
  ].join(':')

  form do
    _input value: @iclaline, name: 'iclaline'
  end

  complete do |dir|
    # checkout empty officers directory
    svn 'checkout', '--depth', 'empty',
      'https://svn.apache.org/repos/private/foundation/officers', 
      "#{dir}/officers"

    # retrieve iclas.txt
    dest = "#{dir}/officers/iclas.txt"
    svn 'update', dest

    # update iclas.txt
    iclas_txt = ASF::ICLA.sort(File.read(dest) + @iclaline + "\n")
    File.write dest, iclas_txt

    # show the changes
    svn 'diff', dest

    # commit changes
    svn 'commit', dest, '-m', "ICLA for #{@pubname}"
  end
end

########################################################################
#                           email submitter                            #
########################################################################

# send confirmation email
task "email #@email" do
  # chose reply based on whether or not the project/userid info was provided
  if @user and not @user.empty?
    reply = 'icla-account-requested.erb'
  elsif @pmc
    @notify = "the #{@pmc.display_name} PMC has"

    if @podling
      @notify.sub! /has$/, "and the #{@podling.display_name} podling have"
    end

    reply = 'icla-pmc-notified.erb'
  else
    reply = 'icla.erb'
  end

  # build mail from template
  mail = message.reply(
    subject: "ICLA for #{@pubname}",
    from: @from,
    to: "#{@pubname.inspect} <#{@email}>",
    cc: [
      'secretary@apache.org',
    ],
    body: template(reply)
  )

  # echo email
  form do
    _message mail.to_s
  end

  # deliver mail
  complete do
    mail.deliver!
  end
end
