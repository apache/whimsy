# attempt to determine where 'HOME' is
unless ENV['HOME']
  ENV['HOME'] = $1 if ENV['SCRIPT_FILENAME'] =~ /(.*?)\/public_html\//
  ENV['HOME'] = $1 if ENV['SCRIPT_FILENAME'] =~ /(.*?)\/Sites\//
end

# look for local_paths.yml or ~/.secassist (in that order)
config = 'local_paths.yml'
if not File.exist?(config) and ENV['HOME']
  config = File.expand_path('~/.secassist')
end

# set constants based on the configuration file
require 'yaml'
YAML.load(open(config).read).each do |key, value|
  Object.const_set key.upcase, File.expand_path(value).untaint
end

# pending file
PENDING_YML = File.join(RECEIVED, 'pending.yml')
COMPLETED_YML = File.join(RECEIVED, 'completed.yml')

# svn >= 1.5 requires a trailing '@' if the file name contains an '@'
# http://stackoverflow.com/questions/1985203/why-subversion-skips-files-which-contain-the-symbol
def svn_at name
  svn_version = `svn --version --quiet`.chomp.split('.').map {|s| s.to_i}
  if (svn_version <=> [1,6,4]) < 1
    ''
  elsif name.include? '@'
    '@'
  else
    ''
  end
end
