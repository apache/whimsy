#
# Update packaging information if the previous info is over a day old
# Install update-notifier-common to keep the update-success-stamp current
#

ruby_block 'upgrade subversion' do
  block do
    if File.exist? '/mnt/svn/foundation/.svn/format'
      cmd = Chef::ShellOut.new(
        'apt-key adv --keyserver keyserver.ubuntu.com --recv-key A2F4C039 2>&1'
      ).run_command

      unless cmd.exitstatus == 0
        Chef::Application.fatal! 'Failed to import subversion signing key'
      end

      File.open('/etc/apt/sources.list.d/subversion.list', 'w') do |file|
        file.write <<-EOF.gsub(/^ +/,'')
          deb http://ppa.launchpad.net/svn/ppa/ubuntu precise main 
          deb-src http://ppa.launchpad.net/svn/ppa/ubuntu precise main
        EOF
      end
    end
  end
end

execute "apt-get-update-periodic" do
  timestamp = '/var/lib/apt/periodic/update-success-stamp'
  command "apt-get update && touch #{timestamp}"
  ignore_failure true
  only_if do
    not File.exists?(timestamp) or File.mtime(timestamp) < Time.now - 86400
  end
end

package 'update-notifier-common'
