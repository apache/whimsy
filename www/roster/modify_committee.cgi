#!/usr/bin/ruby1.9.1

require 'wunderbar'
require '/var/tools/asf'

exceptions = %w(hudson-jobadmin).map {|name| ASF::Committee.find name}



# only allow apache host (and janIV local)
cgi = CGI.new
unless cgi.host.nil? or cgi.host =~ /^192[.]168/
  print "Status: 401 Unauthorized\r\n"
  exit
end



# class to to the actual work
class Modify_user
  def initizalize()
  end

  def add_user(project,person)
    user = ASF::Person.new(person)
    unless user
      return "Person not found in apache"
    end
    pmcs = ASF::Committee.new(project)
    unless pmcs
      return "Project not found in apache"
    end

    # call modify_group_members.pl project --add --filter 
    #                                   --notify root@apache.org'
    #                                   < person
  end

  def remove_user(project,person)
    committee = ASF::Committee.new(project)
    unless pmcs
      return "Project not found in apache"
    end

    # call modify_group_members.pl project --rm --filter 
    #                                   --notify root@apache.org'
    #                                   < person
  end

  def add_group(group,person)
    user = ASF::Person.new(person)
    unless user
      return "Person not found in apache"
    end
    group = ASF::Group.new(project)
    unless group
      return "Group not found in apache"
    end

    # call modify_group_members.pl group --add --filter --posix
    #                                    --notify root@apache.org'
    #                                   < person
  end

  def remove_group(project,person)
    group = ASF::Group.new(project)
    unless group
      return "Group not found in apache"
    end

    # call modify_group_members.pl group --rm --filter --posix
    #                                    --notify root@apache.org'
    #                                   < person
  end
end



# test parameters
showUI = false
if !cgi.has_key?('project') or !cgi.has_key?('action') or
   !cgi.has_key?('type')    or !cgi.has_key?('person')
  showUI = true
else
  if cgi['project'].to_s == ''     or  cgi['person'] == ''        or
     (cgi['action'] != 'add'       and cgi['action'] != 'remove') or
     (cgi['type']   != 'committee' and cgi['type']   != 'group' )
    showUI = true
  end
end



# if no errors modify user 
if !showUI
  mu = Modify_user.new
  if cgi['action'] == 'add'
    if cgi['type'] == 'committee'
      error = mu.add_user(cgi['project'], cgi['person'])
    else
      error = mu.add_group(cgi['project'], cgi['person'])
    end
  else
    if cgi['type'] == 'committee'
      error = mu.remove_user(cgi['project'], cgi['person'])
    else
      error = mu.remove_group(cgi['project'], cgi['person'])
    end
  end
end


_html do
  _head_ do
     _title_ "Apache modify " + cgi['project'] + " " + cgi['action'] + " " + cgi['group'] + " " + cgi['person']
    _meta charset: 'utf-8'
    if error.nil?
      if showUI
        _style %{ body {background-color: #ffffff;} }
      else
        _style %{ body {background-color: #00ff00;} }
      end
    else
      _style %{ body {background-color: #0000ff;} }
    end
  end

  _body? do
    # common banner
    _a href: 'https://id.apache.org/' do
      _img title: "Logo", alt: "Logo", 
        src: "https://id.apache.org/img/asf_logo_wide.png"
    end
    _h1_ 'WARNING EXPERIMENTEL SCRIPT, NOT ACTIVE!'

    if error.nil?
      if showUI == false
        _h1_ cgi['person'] + ' ' + cgi['action'] +  " to/from " + cgi['type'] + " in project " + cgi['project'] + " with SUCCESS!"
      end
    else
      _h1_ 'Modify user problem:' 
      _text_ error
      _br_
      showUI = true
    end

    if showUI
      _h1_ 'modify user' 
      _form method: 'post' do
        _table do
          _tr do
            _td_ 'project:'
            _td colspan: 2 do
              _input_ type: 'text', name: 'project', value: cgi['project'], required: true
            end
          end
          _tr do
            _td_ 'person:'
            _td colspan: 2 do
              _input_ type: 'text', name: 'person', value: cgi['person'], required: true
            end
          end
          _tr do
            _td_ 'type:'
            _td do
              if cgi['type'] == 'group'
                _input_ type: "radio", name: "type", value: "group", required: true, checked: true
              else
                _input_ type: "radio", name: "type", value: "group", required: true, checked: false
              end
              _ 'group'
            end
            _td do
              if cgi['type'] == 'committee'
                _input_ type: "radio", name: "type", value: "committee", required: true, checked: true
              else
                _input_ type: "radio", name: "type", value: "committee", required: true, checked: false
              end
              _ 'committee' 
            end
          end
          _tr do
            _td_ 'action:'
            _td do
              if cgi['action'] == 'add' 
                _input_ type: "radio", name: "action", value: "add", required: true, checked: true
              else
                _input_ type: "radio", name: "action", value: "add", required: true, checked: false
              end
              _ 'add'
            end
            _td do
              if cgi['action'] == 'remove'
                _input_ type: "radio", name: "action", value: "remove", required: true, checked: true
              else
                _input_ type: "radio", name: "action", value: "remove", required: true, checked: false
              end
              _ 'remove'
            end
          end
        end
        _input_ type: 'submit', value: 'Submit Request'
      end
    end 
  end
end
