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


class Wunderbar::JsonBuilder
  def task(title, &block)
    if not @task
      # dry run: collect up a list of tasks
      @_target[:tasklist] ||= []
      @_target[:tasklist] << {title: title, form: []}

      block.call
    elsif @task == title
      # actual run
      block.call
      @task = nil
    end
  end

  def _input *args
    return if @task
    @_target[:tasklist].last[:form] << ['input', '', *args]
  end

  def _textarea *args
    return if @task
    @_target[:tasklist].last[:form] << ['textarea', *args]
  end

  def _message mail
    if @task
      super
    else
      @_target[:tasklist].last[:form] << ['textarea', mail.to_s.strip, rows: 20]
    end
  end

  def form &block
    block.call
  end

  def complete &block
    return unless @task

    if block.arity == 1
      Dir.mktmpdir do |dir|
        block.call dir
      end
    else
      block.call
    end
  end

  def _transcript *args
    return unless @task
    super
  end

  def _backtrace *args
    return unless @task
    super
  end

  def svn *args
    args << svnauth if %(checkout update commit).include? args.first
    _.system! 'svn', *args
  end

  def svnauth
    [
      '--non-interactive', 
      '--no-auth-cache',
      '--username', env.user.untaint,
      '--password', env.password.untaint
    ]
  end

  def template(name)
    path = File.expand_path("../templates/#{name}", __FILE__.untaint)
    ERB.new(File.read(path.untaint).untaint).result(binding)
  end
end
