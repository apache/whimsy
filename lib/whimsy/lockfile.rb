#!/usr/bin/env ruby
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
# File locking support
#

module LockFile

  # create a new file and return an error if it already exists, otherwise nil
  def self.create_ex(filename)
    err = nil
    begin
      File.open(filename, File::WRONLY|File::CREAT|File::EXCL) do |file|
        yield file
      end
    rescue => e
      err = e
    end
    err
  end

  # lock an open file and ensure it gets unlocked
  def self.flock(file, mode)
    ok = file.flock(mode)
    if ok
      begin
        yield file
      ensure
        file.flock(File::LOCK_UN)
      end
    end
    ok
  end

  # open a file and lock it
  # filename
  # mode: default 'r'
  # lockmode: default LOCK_SH
  def self.lockfile(filename, mode=nil, lockmode=nil)
    open(filename, mode || 'r') do |f|
      self.flock(f, lockmode || File::LOCK_SH) { |g|
        yield g
      }
    end
  end
end




if __FILE__ == $0
  test = ARGV.shift || 'lockw'
  name = ARGV.shift || '/tmp/lockfile1'
  text = "#{Time.now}\n"
  puts "#{Time.now} #{test} using #{name}"
  ret = nil
  case test
  when 'default'
    puts "#{Time.now} Wait lock"
    ret = LockFile.lockfile(name) do |f|
      puts "#{Time.now} Got lock"
      puts f.read
      puts "#{Time.now} Sleep"
      sleep(5)
    end
  when 'create'
    ret = LockFile.create_ex(name) {|f| f << text}
  when 'opena'
    puts "#{Time.now} Wait lock"
    ret = LockFile.lockfile(name, 'a', File::LOCK_EX) do |f|
      puts "#{Time.now} Got lock"
      f << text
      puts "#{Time.now} Sleep"
      sleep(5)
    end
  when 'locka'
    open(name,'a') do |f|
      puts "#{Time.now} Wait lock"
      ret = LockFile.flock(f,File::LOCK_EX) do |g|
        g << text
        puts "#{Time.now} Sleep"
        sleep(5)
      end
    end
  when 'lockw'
    open(name,'w') do |f|
      puts "#{Time.now} Wait lock"
      ret = LockFile.flock(f,File::LOCK_EX) do |g|
        g << text
        puts "#{Time.now} Sleep"
        sleep(5)
      end
    end
  else
    raise "Unexpected test: #{test}"
  end
  puts ret.class.inspect
  puts ret.inspect
  if ret
    if Errno::EEXIST === ret
      puts "Already exists!"
    else
      puts "Some other error"
    end
  end
  puts File.read(name) unless ret
end
