version = File.read(File.expand_path('../asf.version', __FILE__)).strip
ldapversion = 
begin
  File.read(File.expand_path('../asfldap.version', __FILE__)).strip
rescue Exception => e
  nil
end

# Allow override of ldap gem name
ldapname = 
begin
  File.read(File.expand_path('../asfldap.gemname', __FILE__)).strip
rescue Exception => e
  'ruby-ldap'
end


Gem::Specification.new do |s|

  # Change these as appropriate
  s.name           = 'whimsy-asf'
  s.license        = 'Apache-2.0'
  s.version        = version
  s.summary        = "Whimsy 'model' of the ASF"
  s.author         = 'Sam Ruby'
  s.email          = 'rubys@intertwingly.net'
  s.homepage       = 'https://whimsy.apache.org/'
  s.description    = <<-EOD
    This package contains a set of classes which encapsulate access
    to a number of data sources such as LDAP, ICLAs, auth lists, etc.
  EOD

  # Add any extra files to include in the gem
  s.files             = Dir.glob(['asf.*', 'lib/**/*'])
  s.require_paths     = ['lib']

  # If you want to depend on other gems, add them here, along with any
  # relevant versions
  s.add_dependency('nokogiri')
  s.add_dependency('rack')
  s.add_dependency(ldapname, ldapversion)
  s.add_dependency('tzinfo')
  s.add_dependency('tzinfo-data')
  s.add_dependency('wunderbar')
  s.add_dependency('rdoc')

  # If your tests use any gems, include them here
  # s.add_development_dependency("mocha") # for example
end
