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

class InsiderSecrets < Vue
  def render
    _p %q(
      Following are some of the less frequently used features that aren't
      prominently highlighted by the UI, but you might find useful.
    )

    _ul do
      _li { _p %q(
        Want to reflow only part of a report so as to not mess with the
        formatting of a table or other pre-formatted text?  Select the
        lines you want to adjust using your mouse before pressing the
        reflow button.
      ) }

      _li { _p %q(
        Want to not use your email client for whatever reason?  Press
        shift before you click a 'send email' button and a form will
        drop down that you can use instead.
      ) }

      _li { _p %q(
        Action items have both a status (which is either shown with a red
        background if no update has been made or a white background if
        a status has been provided), and a PMC name.  The background of the
        later is either grey if this PMC is not reporting this month, or
        a link to the report itself, and the color of the link is the color
        associated with the report (green if preapproved, red if flagged,
        etc.).  So generally if you see an action item to "pursue a report
        for..." and the link is green, you can confidently mark that action as
        complete.
      ) }
    end
  end

  _Link text: 'Back to the agenda', href: '.'
end
