#!/usr/bin/env ruby

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
    if ret.is_a? Errno::EEXIST
      puts "Already exists!"
    else
      puts "Some other error"
    end
  end
  puts File.read(name) unless ret
end
