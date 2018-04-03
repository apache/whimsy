require 'set'

# Creates a summary hash of information from an Agenda
class ASF::Board::Agenda
  # Strings or symbols returned from ASF::Board::Agenda.parse
  ATTACH_KEY = :attach
  INDEX_KEY = :index
  APPROVED_KEY = 'approved'
  TITLE_KEY = 'title'
  # Hash keys returned by summarize()
  ERRORS_KEY = 'errors'
  PEOPLE_KEY = 'people'
  OFFICERS_KEY = 'officers'
  PMCS_KEY = 'pmcs'
  ACTIONS_KEY = 'actions'
  STATS_KEY = 'stats'
  COMMENT_LEN = 'cl'
  REPORT_LEN = 'rl'
  APPROVALS_KEY = 'ap'

  INITIALS_IDX = 0
  # Map director ids->names and ids->initials
  # Only filled in since 2007 or so, once the preapp data in meetings is parseable
  DIRECTOR_MAP = {
    'bayard' => ['hy', 'Henri', 'Henri Yandell'],
    'bdelacretaz' => ['bd', 'Bertrand', 'Bertrand Delacretaz'],
    'brett' => ['bp', 'Brett', 'Brett Porter'],
    'brianm' => ['bmc', 'Brian', 'Brian McCallister'],
    'cliffs' => ['cs', 'Cliff', 'Cliff Schmidt'],
    'coar' => ['kc', 'Ken', 'Ken Coar'],
    'curcuru' => ['sc', 'Shane', 'Shane Curcuru'],
    'cutting' => ['dc', 'Doug', 'Doug Cutting'],
    'dirkx' => ['dg', 'Dirk-Willem', 'Dirk-Willem van Gulik'],
    'dkulp' => ['dk', 'Daniel', 'Daniel Kulp'],
    'fielding' => ['rf', 'Roy', 'Roy T. Fielding'],
    'geirm' => ['gmj', 'Geir', 'Geir Magnusson Jr'],
    'gstein' => ['gs', 'Greg', 'Greg Stein'],
    'isabel' => ['idf', 'Isabel', 'Isabel Drost-Fromm'],
    'jerenkrantz' => ['je', 'Justin', 'Justin Erenkrantz'],
    'jim' => ['jj', 'Jim', 'Jim Jagielski'],
    'ke4qqq' => ['dn', 'David', 'David Nalley'],
    'lrosen' => ['lr', 'Larry', 'Lawrence Rosen'],
    'markt' => ['mt', 'Mark', 'Mark Thomas'],
    'marvin' => ['mh', 'Marvin', 'Marvin Humphrey'],
    'mattmann' => ['cm', 'Chris', 'Chris Mattmann'],
    'noirin' => ['np', 'Noirin', 'Noirin Plunkett'],
    'psteitz' => ['ps', 'Phil', 'Phil Steitz'],
    'rbowen' => ['rb', 'Rich', 'Rich Bowen'],
    'rgardler' => ['rg', 'Ross', 'Ross Gardler'],
    'rubys' => ['sr', 'Sam', 'Sam Ruby'],
    'rvs' => ['rs', 'Roman', 'Roman Shaposhnik'],
    'striker' => ['ss', 'Sander', 'Sander Striker'],
    'tdunning' => ['td', 'Ted', 'Ted Dunning']
  }

  SKIP_AGENDAS = {
    'board_agenda_2009_11_01' => 'F2F meeting: ApacheCon, St. Helena, CA',
    'board_agenda_2010_09_11' => 'F2F meeting: Boston, MA',
    'board_agenda_2010_11_02' => 'F2F meeting: ApacheCon, Atlanta, GA',
    'board_agenda_2011_11_07' => 'F2F meeting: ApacheCon, Vancouver, BC',
    'board_agenda_2012_08_28' => 'F2F meeting: Adobe, McLean, VA',
    'board_agenda_2017_06_15' => 'F2F meeting: Capital One, Mclean, VA'
  }

  # Summarize data from these meeting minutes
  # @param fname of agenda file to summarize
  # @return hash of summary statistics from this meeting
  # @note if error, includes details in [ERRORS_KEY] = ['SKIP(meeting): foo', 'ERROR(meeting): bar',...]
  def self.summarize(fname)
    summary = {}
    meeting = File.basename(fname, '.*')
    if SKIP_AGENDAS.has_key?(meeting)
      summary[ERRORS_KEY] = "SKIP(#{meeting}) was: #{SKIP_AGENDAS[meeting]}"
      return summary
    end
    begin
      agenda = ASF::Board::Agenda.parse(File.read(fname.untaint))
    rescue StandardError => e
      summary[ERRORS_KEY] = "ERROR(#{meeting}) Agenda parse error: #{e.message} #{e.backtrace[0]}"
      return summary
    end
    begin
      summary[PEOPLE_KEY] = Hash[agenda[1][PEOPLE_KEY]]
      summary[PEOPLE_KEY].each do |id, data|
        # Note: this adds initials to everyone who was *ever* a director, who was at this meeting
        data['initials'] = DIRECTOR_MAP[id][INITIALS_IDX] if DIRECTOR_MAP[id]
      end
    rescue StandardError => e
      summary[ERRORS_KEY] = "ERROR(#{meeting}) no attendance error: #{e.message} #{e.backtrace[0]}"
      return summary
    end
    begin
      # Gather statistics about reports with preapprovals
      approvals = agenda.select{ |v| v.has_key?(APPROVED_KEY) }
      # PMC report :attach starts with letter; rest are officer or misc reports
      preports, oreports = approvals.partition{ |v| /\A[[:alpha:]]/ =~ v[ATTACH_KEY] }
      summary[OFFICERS_KEY] = Hash.new{|h,k| h[k] = {} }
      oreports.each do |r|
        summary[OFFICERS_KEY][r[TITLE_KEY]]['owner'] = r['owner'] if r.has_key?('owner')
        summary[OFFICERS_KEY][r[TITLE_KEY]][APPROVALS_KEY] =  Array.new(r['approved'])
        summary[OFFICERS_KEY][r[TITLE_KEY]][COMMENT_LEN] = r['comments'].length
        summary[OFFICERS_KEY][r[TITLE_KEY]][REPORT_LEN] = r['report'].length if r['report']
      end
      summary[PMCS_KEY] = Hash.new{|h,k| h[k] = {} }
      preports.each do |r|
        summary[PMCS_KEY][r[TITLE_KEY]]['owner'] = r['owner']
        if r.has_key?('missing')
          summary[PMCS_KEY][r[TITLE_KEY]]['missing'] = true
        else
          summary[PMCS_KEY][r[TITLE_KEY]][APPROVALS_KEY] =  Array.new(r['approved'])
          summary[PMCS_KEY][r[TITLE_KEY]][COMMENT_LEN] = r['comments'].length
          summary[PMCS_KEY][r[TITLE_KEY]][REPORT_LEN] = r['report'].length if r['report']
        end
      end
      actions = agenda.select{ |v| v.has_key?(INDEX_KEY) && v[INDEX_KEY] == "Action Items" }[0][ACTIONS_KEY]
      if actions
        summary[ACTIONS_KEY] = Hash.new{|h,k| h[k] = [] }
        actions.each do |r|
          summary[ACTIONS_KEY][r[:owner]] << r[:pmc]
        end
      end
      # Summarize across this report
      summary[STATS_KEY] = {}
      summary[STATS_KEY]['specialorders'] = agenda.select{ |v| /\A7/ =~ v[ATTACH_KEY] }.length
      summary[STATS_KEY]['discusstextlen'] = agenda.select{ |v| v[INDEX_KEY] == "Discussion Items" }[0]['text'].length
      totapprovals = 0
      totcommentlen = 0
      totreportlen = 0
      totreports = (summary[OFFICERS_KEY].length + summary[PMCS_KEY].length).to_f
      # TODO figure out the ruby way to average these
      summary[OFFICERS_KEY].each do |x, data|
        totapprovals += data[APPROVALS_KEY].length if data[APPROVALS_KEY]
        totcommentlen += data[COMMENT_LEN] if data[COMMENT_LEN]
        totreportlen += data[REPORT_LEN] if data[REPORT_LEN]
      end
      summary[PMCS_KEY].each do |x, data|
        totapprovals += data[APPROVALS_KEY].length if data[APPROVALS_KEY]
        totcommentlen += data[COMMENT_LEN] if data[COMMENT_LEN]
        totreportlen += data[REPORT_LEN] if data[REPORT_LEN]
      end
      summary[STATS_KEY]['avgapprovals'] = (totapprovals / totreports).round(2)
      summary[STATS_KEY]['avgcommentlen'] = (totcommentlen / totreports).round(0)
      summary[STATS_KEY]['avgreportlen'] = (totreportlen / totreports).round(0)
    rescue StandardError => e
      summary[ERRORS_KEY] ||= "ERROR(#{meeting}) process error: #{e.message} #{e.backtrace[0]}"
    end
    return summary
  end
end
