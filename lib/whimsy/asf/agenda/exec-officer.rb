##   Licensed to the Apache Software Foundation (ASF) under one or more
##   contributor license agreements.  See the NOTICE file distributed with
##   this work for additional information regarding copyright ownership.
##   The ASF licenses this file to You under the Apache License, Version 2.0
##   (the "License"); you may not use this file except in compliance with
##   the License.  You may obtain a copy of the License at
## 
##       http://www.apache.org/licenses/LICENSE-2.0
## 
##   Unless required by applicable law or agreed to in writing, software
##   distributed under the License is distributed on an "AS IS" BASIS,
##   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
##   See the License for the specific language governing permissions and
##   limitations under the License.

# Executive Officer Reports

class ASF::Board::Agenda
  parse do
    reports = @file.split(OFFICER_SEPARATOR,2).last
    a = reports.split(/^ 5. Additional Officer Reports/,2).first
    b = reports.split(/^ 5. Committee Reports/,2).first   # Allow parsing of pre-2007 reports
    (a.length > b.length) ? reports = b : reports = a

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

      attrs['report'].sub! /\A\s*\n/, ''

      attrs['report'].gsub! /\n\s*\n\s+\[ comments:(.*)\]\s*$/m do
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
