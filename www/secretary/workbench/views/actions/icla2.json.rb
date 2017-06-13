#
# File an additional ICLA:
#  - [optional] move existing ICLA into a directory
#  - add files to (new) documents/iclas dirctory
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
@filename.untaint if @filename =~ /\A\w[-.\w]*\z/

if not Dir.exist? "#{iclas}/#@filename"
  @existing = File.basename(Dir["#{iclas}/#@filename.*"].first)
  task "svn mv #@existing #@filename/icla#{File.extname(@existing)}" do
    form do
      _input value: @existing, name: 'existing'
    end

    complete do |dir|
      # checkout empty officers directory
      svn 'checkout', '--depth', 'empty',
        'https://svn.apache.org/repos/private/documents/iclas', "#{dir}/iclas"

      # update file to be moved
      svn 'update', "#{dir}/iclas/#{@existing}"

      # create target directory
      FileUtils.mkdir "#{dir}/iclas/#{@filename}"
      svn 'add', "#{dir}/iclas/#{@filename}"

      # update file to be moved
      svn 'mv', "#{dir}/iclas/#{@existing}", 
        "#{dir}/iclas/#@filename/icla#{File.extname(@existing)}"

      # commit changes
      svn 'commit', "#{dir}/iclas", '-m', "move previous ICLA from #{@pubname}"
    end
  end
end

########################################################################
#                          file new document                           #
########################################################################

# determine initial value for the counter
svndir = ASF::SVN['https://svn.apache.org/repos/private/documents/iclas']
count = Dir["#{svndir}/#@filename/*"].
      map {|name| name[/.*(\d+)\./, 1] || 1}.map(&:to_i).max + 1

# write attachment (+ signature, if present) to the documents/iclas directory
task "svn commit documents/iclas/icla#{count}#{fileext}" do
  form do
    _input value: @selected, name: 'selected'

    if @signature and not @signature.empty?
      _input value: @signature, name: 'signature'
    end
  end

  complete do |dir|
    # checkout directory
    svn 'checkout', 
      "https://svn.apache.org/repos/private/documents/iclas/#@filename",
      "#{dir}/#@filename"

    # determine numeric suffix for the new ICLA
    count = Dir["#{dir}/#@filename/*"].
      map {|name| name[/.*(\d+)\./, 1] || 1}.map(&:to_i).max + 1

    # create/add file(s)
    files = {@selected => "icla#{count}#{fileext}"}
    files[@signature]  = "icla#{count}pdf.asc" unless @signature.to_s.empty?
    message.write_svn(dir, @filename, files)

    # Show files to be added
    svn 'status', "#{dir}/#@filename"

    # commit changes
    svn 'commit', "#{dir}/#@filename/#{@filename}#{fileext}",
      '-m', "additional ICLA from #{@pubname}"
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
