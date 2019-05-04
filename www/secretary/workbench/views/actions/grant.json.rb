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
# File an ICLA:
#  - add files to documents/grants
#  - add entry to officers/grants.txt
#  - respond to original email
#

# extract message
message = Mailbox.find(@message)

# extract file extension
fileext = File.extname(@selected).downcase if @signature.empty?

# verify that a grant under that name doesn't already exist
if "#@filename#{fileext}" =~ /\w[-\w]*\.?\w*/
  grant = "#{ASF::SVN['grants']}/#@filename#{fileext}"
  if File.exist? grant.untaint
    _warn "documents/grants/#@filename#{fileext} already exists"
  end
end

# extract/verify project
_extract_project

# obtain per-user information
_personalize_email(env.user)

# initialize commit message
@document = "Software Grant from #{@company}"

########################################################################
#                           document/grants                            #
########################################################################

# write attachment (+ signature, if present) to the documents/grants directory
task "svn commit documents/grants/#@filename#{fileext}" do
  form do
    _input value: @selected, name: 'selected'

    if @signature and not @signature.empty?
      _input value: @signature, name: 'signature'
    end
  end

  complete do |dir|
    # checkout empty directory
    svn 'checkout', '--depth', 'empty',
      'https://svn.apache.org/repos/private/documents/grants', "#{dir}/grants"

    # create/add file(s)
    dest = message.write_svn("#{dir}/grants", @filename, @selected, @signature)

    # Show files to be added
    svn 'status', "#{dir}/grants"

    # commit changes
    svn 'commit', "#{dir}/grants/#{@filename}#{fileext}", '-m', @document
  end
end

########################################################################
#                         officers/grants.txt                          #
########################################################################

# insert line into grants.txt
task "svn commit foundation/officers/grants.txt" do
  # construct line to be inserted
  @grantlines = "#{@company.strip}" +
    "\n  file: #{@filename}#{fileext}" +
    "\n  for: #{@description.strip.gsub(/\r?\n\s*/,"\n       ")}"

  form do
    _textarea @grantlines, name: 'grantlines', 
      rows: @grantlines.split("\n").length
  end

  complete do |dir|
    # checkout empty officers directory
    svn 'checkout', '--depth', 'empty',
      'https://svn.apache.org/repos/private/foundation/officers', 
      "#{dir}/officers"

    # retrieve grants.txt
    dest = "#{dir}/officers/grants.txt"
    svn 'update', dest

    # update grants.txt
    marker = "\n# registering.  documents on way to Secretary.\n"
    File.write dest,
      File.read(dest).split(marker).insert(1, "\n#{@grantlines}\n", marker).join

    # show the changes
    svn 'diff', dest

    # commit changes
    svn 'commit', dest, '-m', @document
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
    to: "#{@name.inspect} <#{@email}>",
    cc: [
      'secretary@apache.org',
      ("private@#{@pmc.mail_list}.apache.org" if @pmc), # copy pmc
      (@podling.private_mail_list if @podling) # copy podling
    ],
    body: template('grant.erb')
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
