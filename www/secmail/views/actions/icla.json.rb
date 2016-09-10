#
# File an ICLA
#

message = Mailbox.find(@message)
iclas = ASF::SVN['private/documents/iclas']

# extract file extension
fileext = File.extname(@selected) if @signature.empty?

# write attachment (+ signature, if present) to the documents/iclas directory
_task "svn commit documents/iclas/#@filename#{fileext}" do
  svn_reset iclas
  dest = message.write_svn(iclas, @filename, @selected, @signature)
end

# insert line into iclas.txt
_task "svn commit foundation/officers/iclas.txt" do
  # construct line to be inserted
  insert = [
    'notinavail',
    @realname.strip,
    @pubname.strip,
    @email.strip,
    "Signed CLA;#{@filename}"
  ].join(':')

  # update iclas.txt
  svn_reset ASF::ICLA::OFFICERS
  iclas_txt = ASF::ICLA.sort(File.read(ASF::ICLA::SOURCE) + insert + "\n")
  File.write ASF::ICLA::SOURCE, iclas_txt
end

# send confirmation email
_task "email #@email" do
end

{result: "stub for ICLA, filename: #{@filename}"}
