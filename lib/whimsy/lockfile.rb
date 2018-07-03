#!/usr/bin/env ruby

#
# File locking support
#

module LockFile

  # create a new file and return an error if it already exists
  def self.create_ex(filename, verbose=false)
    err = nil
    begin
      File.open(filename, File::WRONLY|File::CREAT|File::EXCL) do |file|
        yield file
      end
    rescue => e
      err = e
    end
    return verbose ?  [err==nil, err] :  err==nil
  end

  # lock a file and ensure it gets unlocked
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

end




if __FILE__ == $0
  test = ARGV.shift || 'lockw'
  name = ARGV.shift || '/tmp/lockfile1'
  text = "#{Time.now}\n"
  puts "#{Time.now} #{test} using #{name}"
  case test
  when 'create'
    ret = LockFile.create_ex(name) {|f| f << text}
  when 'createShow'
    ret = LockFile.create_ex(name, true) {|f| f << text}
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
  puts ret.inspect
  puts File.read(name)
end
