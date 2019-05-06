#!/usr/bin/env ruby
# Utility function to scan various scripts
#   Docs: for WVisible PAGETITLE and categories in .cgi
#   Repos: for ASF::SVN access in .cgi|rb
$LOAD_PATH.unshift '/srv/whimsy/lib'
require 'whimsy/asf'
SCANDIR = "../www"
ISERR = '!'
AUTHMAP = { # From whimsy-vm4.apache.org.yaml
  'ASF Committers' => 'text-muted',
  'ASF Members and Officers' => 'text-primary',
  'ASF Members and Incubator PMC' => 'text-success',
  'ASF Members' => 'text-warning',
  'ASF Secretarial Team' => 'text-danger'
}
AUTHPUBLIC = 'glyphicon-eye-open'
IS_PRIVATE = /\A(private|infra\/infrastructure)/
ASFSVN = 'ASF::SVN'
SCANDIRSVN = "../"

# Return [PAGETITLE, [cat,egories] ] after WVisible; or same as !Bogosity error
def scan_file(f)
  begin
    File.open(f).each_line.map(&:chomp).each do |line|
      if line =~ /\APAGETITLE\s?=\s?"([^"]+)"\s?#\s?WVisible:(.*)/i then
        return [$1, $2.chomp.split(%r{[\s,]})]
      end
    end
    return nil
  rescue Exception => e
    return ["#{ISERR}Bogosity! #{e.message[0..255]}", "\t#{e.backtrace.join("\n\t")}"]
  end
end

# Return data only about WVisible cgis, plus any errors
def scan_dir(dir)
  links = {}
  Dir["#{dir}/**/*.cgi".untaint].each do |f|
    l = scan_file(f.untaint)
    links[f.sub(dir, '')] = l if l
  end
  return links
end

# Process authldap so we can annotate links with access hints
def get_auth()
    node = ASF::Git.find('infrastructure-puppet')
    if node
      node += '/data/nodes/whimsy-vm4.apache.org.yaml'
    else
      raise Exception.new("Cannot find Git: infrastructure-puppet")
    end
    yml = YAML.load(File.read("#{node}"))
    authldap = yml['vhosts_whimsy::vhosts::vhosts']['whimsy-vm-443']['authldap']
    # Unwrap so we can easily compare base path
    auth = {}
    authldap.each do |ldap|
      ldap['locations'].each do |loc|
        auth[loc] = ldap['name']
      end
    end
    return auth
end

# Annotate scan entries with hints only for paths that require auth
def annotate_scan(scan, auth)
  annotated = scan.reject{ |k, v| v[1] =~ /\A#{ISERR}/ }
  annotated.each do |path, ary|
    realm = auth.select { |k, v| path.match(/\A#{k}/) }
    if realm.values.first
      ary << AUTHMAP[realm.values.first]
    end
  end
  return annotated
end

# Common use case # TODO these could be static generated files nightly
def get_annotated_scan(dir)
  scan = scan_dir(dir)
  auth = get_auth()
  return annotate_scan(scan, auth)
end

# Read repository.yml for all :svn dirs names to scan for
# @return [['private1', 'privrepo2', ...], ['public1', 'pubrepo2', ...]
def read_repository()
  svn = YAML.load_file('../repository.yml')[:svn]
  repos = [[], []]
  svn.each do |repo, data|
    data['url'] =~ IS_PRIVATE ? repos[0] << repo : repos[1] << repo
  end
  return repos
end

# Build a regex union from ASFSVN and an array
# @return Regexp.union(r...)
def build_regexp(list)
  r = []
  list.each do |itm|
    r << "#{ASFSVN}\['#{itm}']"
  end
  return Regexp.union(r)
end

# Scan file for use of ASF::SVN (private or public)
# @return [["x = ASF::SVN['Meetings'] # Whole line private repo", ...], [] ]
def scan_file_svn(f, regexs)
  repos = [[], []]
  begin
    File.open(f).each_line.map(&:chomp).each do |line|
      if line =~ regexs[0] then
        repos[0] << line
      elsif line =~ regexs[1] then
        repos[1] << line
      end
    end
    return repos
  rescue Exception => e
    return [["#{ISERR}Bogosity! #{e.message[0..255]}", "\t#{e.backtrace.join("\n\t")}"],[]]
  end
end

# Scan directory for use of ASF::SVN (private or public)
# @return { file: [['private line'], []] }
def scan_dir_svn(dir, regexs)
  links = {}
  Dir["#{dir}/**/*.{cgi,rb}".untaint].each do |f|
    l = scan_file_svn(f.untaint, regexs)
    if (l[0].length + l[1].length) > 0
      links[f.sub(dir, '')] = l
    end
  end
  return links
end

