require 'fileutils'
require 'yaml'
require 'mail'

Dir.chdir File.absolute_path('..', __FILE__)

# Create a 'received' repository in work/repositories
FileUtils.rm_rf 'work'
FileUtils.mkdir_p 'work/repositories'

Dir.chdir 'work/repositories' do
  system 'svnadmin create received'
end

svn = File.absolute_path('work/repositories')

# Checkout 'received' repository into work/svn
FileUtils.mkdir_p 'work/svn'

Dir.chdir 'work/svn' do
  `svn checkout file://#{svn}/received`
end

RECEIVED = File.absolute_path('work/svn/received')

# define pending yaml files
PENDING_YML = File.join(RECEIVED, 'pending.yml')
COMPLETED_YML = File.join(RECEIVED, 'completed.yml')

# define where the mail configuration can be found
MAIL = File.absolute_path('secmail.rb')
