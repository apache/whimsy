#!/usr/bin/ruby1.9.1

require 'wunderbar'
require 'whimsy/asf'
require 'ldap'

exceptions = %w(hudson-jobadmin).map {|name| ASF::Committee.find name}


# The following is needed to cover the differences between POST,GET and params
# using e.g. @project is nullified by _html_
cgi = CGI.new
xProject = cgi['project']
xPerson  = cgi['person']
xType    = cgi['type']
xAction  = cgi['action']
# and this is to make string handling easier
xProject = '' if xProject.nil?
xPerson  = '' if xPerson.nil?
xType    = '' if xType.nil?
xAction  = '' if xAction.nil?


# do not allow execution in production
unless cgi.host.nil? or cgi.host =~ /^192[.]168/
  print "Status: 401 Unauthorized\r\n"
  exit
end


# test parameters
if xProject == '' and xPerson == '' and xAction == '' and xType == ''
  error = 'show'
else
  if  xProject == ''          or  xPerson  == ''       or 
     (xAction  != 'add'       and xAction != 'remove') or
     (xType    != 'committee' and xType   != 'group' )
    error = "wrong params in cgi call"
  end
end


# check user/group exist in LDAP
def runLDAPcheck(lType, lProject, lPerson, lAction)
  # verify that project or group exist
  if lType == 'committee'
    mySel = ASF::Committee.find(lProject)
  else
    mySel = ASF::Group.find(lProject)
  end
  if mySel.nil?
    return "name: #lProject not found in apache/ldap"
  end
 
  # verify that person exist (NOT done for group/remove)
  if !(lAction == 'remove' and lType == 'group')
    myUser = ASF::Person.find(lPerson)
    if myUser.nil?
      return "person: #lPerson not found in apache/ldap"
    end
  end
end

def runLDAPmodify
  ldap = LDAP::Conn.new('localhost', 1636)
  print "\nConn done\n"
  print ldap.perror("conn")
  print "\ntesting bind\n"

  # bind ldap instance to defined user
  ldap.bind('uid=USER,dc=apache,dc=org', 'PASSWORD')
  print ldap.perror("bind")


# BIND fails with ssh -L, --- the rest of this func is not tested ---

#  rescue LDAP::ResultError=>re
#    return  "Error new LDAP server: message: ["+ re.message + "]"
  ldap.unbind
  return 'SSLCon is ok'


  # set filter
#  @response = @ldap.search(@xProject, 'base', ['member', 'memberUid'], 'cn=*')
# This is not done, because LDAP gives error if xPerson does not exist (remove)
# and also if person already exist (add)

#  if xAction == 'add'
#    @myModType = new LDAP::mod_type(LDAP_MOD_ADD)
#  else
#    @myModType = new LDAP::mod_type(LDAP_MOD_DELETE)
#  end
 
#  if @xType == 'group'
#    @myMod = new LDAP::mod(@myModType, 'memberUid' ,@xPerson)
#  else
#    @myMod = new LDAP::mod(@myModType, 'member' ,@xPerson)
#  end

#  @ldap.unbind


#Ruby and rubygem, has no standard method for sending mail.

#OLD TO BE DONE
#   my $date = gmtime;
#   open my $sendmail, "|-", "/usr/sbin/sendmail -oi -t -odq"
#       or die "Can't open sendmail: $!";
#   print $sendmail <<EOH;
#To: <$opt_notify>
#From: "$uname" <$uid\@apache.org>
#Subject: LDAP $action on $groupdn
#Date: $date +0000
#
#Members acted on:
#EOH
#    print $sendmail "$_\n" for @members;
#
#    if ($opt_filter) {
#        if ($opt_rm and not @members) {
#            print $sendmail "$_\n" for sort keys %oldmember;
#        }
#        print $sendmail <<EOH;
#
#Filtered members:
#EOH
#        print $sendmail "$_\n" for @filtered;
#
#    }
#
#    close $sendmail or die "Sendmail failed: " . ($! || $? >> 8) . "\n";
#    print "Notification sent to <$opt_notify>.\n";
#}
end


def runExecute
  return 'jan was in runExecute'
  # verify that project or group exist
  if @type == 'committee'
    mySel = ASF::Committee.new(project)
  else
    mySel = ASF::Group.new(project)
  end
  unless mySel
    return "name: #@project not found in apache/ldap"
  end

  # verify that person exist (NOT done for group/remove)
  if !(@action == 'remove' and @type == 'group')
    myUser = ASF::Person.new(person)
    unless myUser
      return "Person #@person not found in apache/ldap"
    end
  end
end


# if no errors check user 
if error.nil?
  error = runLDAPcheck(xType, xProject, xPerson, xAction)
end

# if no errors execute modify user 
if error.nil?
  error = runLDAPmodify
end


_html do
  _head_ do
     _title_ 'Apache modify ' + xProject + ' ' + xAction + ' ' + xType + ' ' + xPerson
    _meta charset: 'utf-8'
    if error.nil?
      _style %{ body {background-color: #00ff00;} }
    else
      if error == 'show'
        _style %{ body {background-color: #ffffff;} }
      else
        _style %{ body {background-color: #0000ff;} }
      end
    end
  end

  _body? do
    # common banner
    _a href: 'https://id.apache.org/' do
      _img title: "Logo", alt: "Logo", 
        src: "https://id.apache.org/img/asf_logo_wide.png"
    end

    if error.nil?
      _text xPerson
      _h1_ xPerson + ' ' + xAction + ' to/from ' + xType + ' in ' + xProject + ' with SUCCESS!'
    else
      _h1_ 'modify user' 
      if error != 'show'
        _text_ 'problem: ' + error
        _br_
        _text_ 'please correct'
        _br_
      end

      _form method: 'post' do
        _table do
          _tr do
            _td_ 'project:'
            _td colspan: 2 do
              _input_ type: 'text', name: 'project', value: xProject, required: true
            end
          end
          _tr do
            _td_ 'person:'
            _td colspan: 2 do
              _input_ type: 'text', name: 'person', value: xPerson, required: true
            end
          end
          _tr do
            _td_ 'type:'
            _td do
              _input_ type: "radio", name: "type", value: "group", required: true, checked: xType == 'group'
              _ 'group'
            end
            _td do
              _input_ type: "radio", name: "type", value: "committee", required: true, checked: xType == 'committee'
              _ 'committee' 
            end
          end
          _tr do
            _td_ 'action:'
            _td do
              _input_ type: "radio", name: "action", value: "add", required: true, checked: xAction == 'add'
              _ 'add'
            end
            _td do
              _input_ type: "radio", name: "action", value: "remove", required: true, checked: xAction == 'remove'
              _ 'remove'
            end
          end
        end
        _input_ type: 'submit', value: 'Submit Request'
      end
    end 
  end
end
