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

#
# Batch apply offline updates

Pending.update(env.user, @agenda) do |pending|
  agenda = Agenda.parse @agenda, :full
  @initials ||= pending['initials']

  approved = pending['approved']
  unapproved = pending['unapproved']
  flagged = pending['flagged']
  unflagged = pending['unflagged']
  comments = pending['comments']

  if @pending['approve']
    @pending['approve'].each do |attach, request|
      if request == 'approve'
        unapproved.delete attach
        approved << attach unless approved.include? attach or
          agenda.find {|item| item[:attach] == attach and
            item['approved'].include? @initials}
      else
        approved.delete attach
        unapproved << attach unless unapproved.include? attach or
          not agenda.find {|item| item[:attach] == attach and
            item['approved'].include? @initials}
      end
    end
  end

  if @pending['flag']
    @pending['flag'].each do |attach, request|
      if request == 'flag'
        unflagged.delete attach
        flagged << attach unless flagged.include? attach or
          agenda.find {|item| item[:attach] == attach and
            Array(item['flagged_by']).include? @initials}
      else
        flagged.delete attach
        unflagged << attach unless unflagged.include? attach or
          not agenda.find {|item| item[:attach] == attach and
            Array(item['flagged_by']).include? @initials}
      end
    end
  end

  if @pending['comment']
    @pending['comment'].each do |attach, comment|
      if comment.empty? 
        comments.delete attach
      else
        comments[attach] = comment
      end
    end
  end
end
