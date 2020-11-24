#!/usr/bin/env ruby
# Utility function to scan various scripts
#   Docs: for Wvisible PAGETITLE and categories in .cgi
#   Repos: for ASF::SVN access in .cgi|rb
$LOAD_PATH.unshift '/srv/whimsy/lib'
require 'wunderbar'
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
ASFSVN = /ASF::SVN/
SCANDIRSVN = "../"
WWWAUTH = /WWW-Authenticate: Basic realm/
CONSTANT_DEF = /(?<matchconst>[A-Z_]+)\s+=\s+['"](?<matchval>[^#]+)['"]/ # Attempt to capture CONSTANT = "value"

HTTPD_SITES = '/etc/apache2/sites-enabled'
# Use wild-card to allow for possible renames (normally 10-whimsy-vm-443.conf)
# Also allows testing on a developer system (use a different suffix that is not Included by httpd)
WHIMSY_CONF = File.join(HTTPD_SITES, '*-whimsy-vm-443.*')

# Output ul of key of AUTHMAP for use in helpblock
def emit_authmap
  _ul do
    _li do
      _span.glyphicon :aria_hidden, :class => AUTHPUBLIC
      _ 'Publicly available'
    end
    AUTHMAP.each do |realm, style|
      _li do
        _span.glyphicon.glyphicon_lock :aria_hidden, :class =>  style, aria_label: realm
        _ realm
      end
    end
  end
end

# Output a span with the auth level
def emit_auth_level(level)
  if level
    _span :class =>  level, aria_label: AUTHMAP.key(level) do
      _span.glyphicon.glyphicon_lock :aria_hidden
    end
  else
    _span.glyphicon :aria_hidden, :class =>  AUTHPUBLIC
  end
end

# Scan single file for PAGETITLE and categories when Wvisible
# @return [PAGETITLE, [cat,egories] ] or ["!Bogosity error", "stacktrace"]
def scan_file(f)
  begin
    File.open(f).each_line.map(&:chomp).each do |line|
      if line =~ /\APAGETITLE\s?=\s?"([^"]+)"\s?#\s?Wvisible:(.*)/i then
        return [$1, $2.chomp.split(%r{[\s,]})]
      end
    end
    return nil
  rescue Exception => e
    return ["#{ISERR}Bogosity! #{e.message[0..255]}", "\t#{e.backtrace.join("\n\t")}"]
  end
end

# Return data only about Wvisible cgis, plus any errors
# @return [ [PAGETITLE, [cat,egories] ], ... ]
def scan_dir(dir)
  links = {}
  Dir["#{dir}/**/*.cgi"].each do |f|
    l = scan_file(f)
    links[f.sub(dir, '')] = l if l
  end
  return links
end


# Parse httpd config file so we can annotate links with access hints
# Sample data:
# <LocationMatch ^/board/subscriptions>
#   AuthName "ASF Committers"
# <Directory /x1/srv/whimsy/www/committers>
#   AuthName "ASF Committers"
# @return { "/path" => "auth realm",... }
def get_auth
  hash = {}
  files = Dir[WHIMSY_CONF]
  return hash unless files.size == 1 # must match just one
  file = files.first
  loc = nil
  File.read(file).each_line do |l|
    if l =~ %r{<LocationMatch ([^>]+)>}
      loc = $1.gsub(/^\^/,'') # remove ^ prefix
    elsif l =~ %r{<Directory ([^>]+)>}
      # remove standard prefix and append '/' directory marker
      loc = $1.sub('/x1/srv/whimsy/www','')+'/'
    elsif l =~ %r{AuthName\s+"(.+)"} # generate the entry
      hash[loc] = $1 if loc
      loc = nil
    end
  end
  hash
end

# Annotate scan_dir entries with hints only for paths that require auth
# Side Effects:
#   - REMOVES any error scan entries
#   - Adds array element of auth realm if login required
def annotate_scan(scan, auth)
  annotated = scan.reject{ |_k, v| v[0] =~ /\A#{ISERR}/ }
  annotated.each do |path, ary|
    realm = auth.select { |k, _v| path.match(/\A#{k}/) }
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

# Build a regex union from ASFSVN and an array
# @return Regexp.union(r...)
def build_regexp(list)
  r = []
  list.each do |itm|
    r << "#{ASFSVN.source}\['#{itm}']"
  end
  return Regexp.union(r)
end

# Scan file for use of ASF::SVN symbolic names like apmail_bin; unmapping any CONSTANT_DEF
# @return [["x = ASF::SVN['Meetings'] # Whole line of code accessing private repo", ...], [<public repos same>], 'WWW-Authenticate code line' ]
def scan_file_svn(f, regexs)
  repos = [[], [], []]
  consts = {}
  begin
    File.open(f).each_line.map(&:chomp).each do |line|
      line.strip!
      if line =~ WWWAUTH # Fastest compare first
        repos[2] << line
      elsif line =~ ASFSVN # Find all ASF::SVN and also map if it uses a CONSTANT_DEF
        consts.each do |k,v|
          line.sub!(k, v)
        end
        if line =~ regexs[0]
          repos[0] << line
        elsif line =~ regexs[1]
          repos[1] << line
        end
      elsif line =~ CONSTANT_DEF
        consts[$~['matchconst']] = "'#{$~['matchval']}'"
      end
    end
    return repos
  rescue Exception => e
    return [["#{ISERR}Bogosity! #{e.message[0..255]}", "\t#{e.backtrace.join("\n\t")}"],[]]
  end
end

# Scan directory for use of ASF::SVN (private or public)
# @return { "file" => [['private line', ...], ['public svn', ...], 'WWW-Authenticate code line' (, 'authrealm')] }
def scan_dir_svn(dir, regexs)
  links = {}
  auth = get_auth()
  Dir["#{dir}/**/*.{cgi,rb}"].sort.each do |f|
    l = scan_file_svn(f, regexs)
    if (l[0].length + l[1].length) > 0
      fbase = f.sub(dir, '')
      realm = auth.select { |k, _v| fbase.sub('/www', '').match(/\A#{k}/) }
      if realm.values.first
        l << AUTHMAP[realm.values.first]
      end
      links[fbase] = l
    end
  end
  return links
end
