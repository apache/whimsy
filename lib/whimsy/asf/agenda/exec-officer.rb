# Executive Officer Reports

class ASF::Board::Agenda
  parse do
    reports = @file.split(OFFICER_SEPARATOR, 2).last
    a = reports.split(/^ 5. Additional Officer Reports/, 2).first
    b = reports.split(/^ 5. Committee Reports/, 2).first   # Allow parsing of pre-2007 reports
    a.length > b.length ? reports = b : reports = a

    pattern = /
      \s{4}(?<section>[A-Z])\.
      \s(?<title>[^\[]+?)
      \s\[(?<owner>[^\]]+?)\]
      (?<report>.*?)
      (?=\n\s{4}[A-Z]\.\s|\z)
    /mx

    scan reports, pattern do |attrs|
      attrs['section'] = '4' + attrs['section']
      attrs['shepherd'] = attrs['owner'].split('/').last
      attrs['owner'] = attrs['owner'].split('/').first

      attrs['report'].sub! %r{/\A\s*\n}, ''

      attrs['report'].gsub! %r{\n\s*\n\s+\[ comments:(.*)\]\s*$}m do
        attrs['comments'] = $1.sub(/\A\s*\n/, '').sub(/\s+\Z/, '')
        "\n"
      end

      report = attrs['report'].strip
      if report.empty? or report[0..12] == 'Additionally,'
        attrs['missing'] = true
      end

      attrs['digest'] = Digest::MD5.hexdigest(report)
    end
  end
end
