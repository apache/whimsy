#!/usr/bin/env ruby
# Encapsulate (most) display of website checks between projects|podlings
require 'wunderbar'
require 'wunderbar/bootstrap'
require_relative '../whimsy/asf/themes'

# Display data for a single project's checks
# @param project id of project
# @param links site data for that specific project
# @param columns list of check types to report on
# @param analysis complete scan data
# @param tlp true if project (default); podling otherwise
def display_project(project, links, analysis, checks, tlp = true)
  _whimsy_panel_table(
    title: "Site Check For #{tlp ? 'Project' : 'Podling'} - #{links['display_name']}",
    helpblock: -> {
      _a href: '../', aria_label: 'Home to site checker' do
        _span.glyphicon.glyphicon_home :aria_hidden
      end
      _span.glyphicon.glyphicon_menu_right
      _ "Results for #{tlp ? 'Project' : 'Podling'} "
      _a links['display_name'], href: links['uri']
      _ '. '
      unless tlp
        _ %{Reminder: Incubation is the process of becoming an Apache project
          - podlings are not required to meet these checks until graduation.  See }
        _a "this project's incubation status.", href: "http://incubator.apache.org/projects/#{project}"
      end
      _br
      _ 'Check Results column is the actual text or URL found on the homepage for this check (when applicable).'
    }
  ) do
    _table.table.table_striped do
      _thead do
        _tr do
          _th! 'Check Type'
          _th! 'Check Results'
          _th! 'Check Description'
        end
      end
      _tbody do
        checks.each_key do |col|
          cls = SiteStandards.label(analysis, links, col, project)
          _tr do
            _td do
              _a col.capitalize, href: "../check/#{col}"
            end
            if links[col] =~ /^https?:/
              _td class: cls do
                _a links[col], href: links[col]
              end
            else
              _td links[col], class: cls
            end
            _td do
              if cls != SiteStandards::SITE_PASS
                if checks.keys.include? col
                  if checks[col][SiteStandards::CHECK_TYPE]
                    _ 'URL expected to match regular expression: '
                    _code checks[col][SiteStandards::CHECK_VALIDATE].source
                  else
                    _ 'Text of a link expected to match regular expression: '
                    _code checks[col][SiteStandards::CHECK_TEXT].source
                  end
                  _br
                  _a checks[col][SiteStandards::CHECK_DOC], href: checks[col][SiteStandards::CHECK_POLICY]
                else
                  _ ''
                end
              end
            end
          end
        end
      end
    end
  end
end

# Display data for a single check across all projects/podlings
# @param col id of check to display
# @param sites site data for all projects
# @param analysis complete scan data
# @param checks complete set of checks performed
# @param tlp true if project (default); podling otherwise
def display_check(col, sites, analysis, checks, tlp = true)
  _whimsy_panel_table(
    title: "Site Check Of Type - #{col.capitalize}",
    helpblock: -> {
      _a href: '../', aria_label: 'Home to site checker' do
        _span.glyphicon.glyphicon_home :aria_hidden
      end
      _span.glyphicon.glyphicon_menu_right
      if checks.keys.include? col
        if checks[col][SiteStandards::CHECK_TYPE]
          _ 'Check Results URL expected to match regular expression: '
          _code checks[col][SiteStandards::CHECK_VALIDATE].source
        else
          _ 'Check Results Text of a link expected to match regular expression: '
          _code checks[col][SiteStandards::CHECK_TEXT].source
        end
        if checks.include? col
          _br
          _a checks[col][SiteStandards::CHECK_DOC], href: checks[col][SiteStandards::CHECK_POLICY]
        end
        _li.small " Click column badges to sort"
      else
        _span.text_danger %{WARNING: the site checker may not understand type: #{col},
                            results may not be complete/available.}
      end
    }
  ) do
    _table.table.table_condensed.table_striped do
      _thead do
        _tr do
          _th! tlp ? 'Project' : 'Podling', data_sort: 'string-ins'
          _th! data_sort: 'string' do
            _ 'Check Results'
            _br
            analysis[0][col].each do |cls, val|
              _ ' '
              _span.label val, class: cls
            end
          end
        end
      end
      _tbody do
        sites.each do |n, links|
          _tr do
            _td do
              _a links['display_name'], href: "../project/#{n}"
            end
            if links[col] =~ /^https?:/
              _td class: SiteStandards.label(analysis, links, col, n) do
                _a links[col], href: links[col]
              end
            else
              _td links[col], class: SiteStandards.label(analysis, links, col, n)
            end
          end
        end
      end
    end
  end
end

# Display an overview of all checks/sites
# @param sites site data for all projects
# @param analysis complete scan data
# @param checks complete set of checks performed
# @param tlp true if project (default); podling otherwise
def display_overview(sites, analysis, checks, tlp = true)
  _whimsy_panel_table(
    title: "Site Check - All #{tlp ? 'Project' : 'Podling'} Results",
    helpblock: -> {
      _ul.list_inline do
        _li.small "Data key: "
        analysis[1].each do |cls, desc|
          _li.label desc, class: cls
        end
        _li.small " Click column badges to sort"
      end
    }
  ) do
    _table.table.table_condensed.table_striped do
      _thead do
        _tr do
          _th! tlp ? 'Project' : 'Podling', data_sort: 'string-ins'
          checks.each_key do |col|
            _th! data_sort: 'string' do
              _a col.capitalize, href: "check/#{col}"
              _br
              analysis[0][col].each do |cls, val|
                _ ' '
                _span.label val, class: cls
              end
            end
          end
        end
      end
      sort_order = {
        SiteStandards::SITE_PASS => 1,
        SiteStandards::SITE_WARN => 2,
        SiteStandards::SITE_FAIL => 3
      }
      _tbody do
        sites.each do |n, links|
          _tr do
            _td do
              _a links['display_name'], href: "project/#{n}"
            end
            checks.each_key do |c|
              cls = SiteStandards.label(analysis, links, c, n)
              _td '', class: cls, data_sort_value: sort_order[cls]
            end
          end
        end
      end
    end
  end
end

# Display an error page if a suburl we're given isn't supported
def display_error(path)
  _whimsy_panel_table(
    title: "ERROR - bad url provided",
    helpblock: -> {
      _a href: '../', aria_label: 'Home to site checker' do
        _span.glyphicon.glyphicon_home :aria_hidden
      end
      _span.glyphicon.glyphicon_menu_right
      _span.text_danger "ERROR: The path #{path} is not a recognized command for this tool, sorry! "
    }
  ) do
    _a.bold 'ERROR - please try again.', href: '../'
  end
end

# Display our application's data - handles / and project/id|check/id paths
def display_application(path, sites, analysis, checks, tlp = true)
  if path =~ %r{/project/(.+)} # Display a single project
    if sites[$1]
      display_project($1, sites[$1], analysis, checks, tlp)
    else
      display_error(path)
    end
  elsif path =~ %r{/check/(.+)} # Display a single check
    if checks[$1]
      display_check($1, sites, analysis, checks, tlp)
    else
      display_error(path)
    end
  else
    display_overview(sites, analysis, checks, tlp)
  end
end
