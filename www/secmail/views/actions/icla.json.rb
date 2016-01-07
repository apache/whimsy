#
# File an ICLA
#

message = Mailbox.find(@message)
iclas = ASF::SVN['private/documents/iclas']

# write attachment (+ signature, if present) to the documents/iclas directory
svn_reset iclas
dest = message.write_svn(iclas, @filename, @selected, @signature)

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

{result: "stub for ICLA, filename: #{@filename}"}
