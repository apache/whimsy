#
# Produce the set of commands that would recreate the current svn checkouts
#

Dir.chdir '/srv/svn'

Dir['*'].sort.each do |name|
  if Dir.exist? name
    Dir.chdir name do
      url = `svn info`[/URL: (.*)/, 1]

      if Dir['*/*'].empty?
        depth = ' --depth=files'
      else
        depth = ''
      end

      puts "svn checkout#{depth} #{url} #{name}"
    end
  end
end
