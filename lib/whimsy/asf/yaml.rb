#!/usr/bin/env ruby

require 'yaml'

#
# YAML file support
#

module YamlFile

  #
  # encapsulate updates to a YAML file
  # opens the file for exclusive access with an exclusive lock
  # Yields the parsed YAML to the block, and writes the updated
  # data to the file
  def self.update(yaml_file)
    File.open(yaml_file, File::RDWR|File::CREAT, 0644) do |file| 
      file.flock(File::LOCK_EX)
      yaml = YAML.safe_load(file.read) || {} rescue {}
      yield yaml
      file.rewind
      file.write YAML.dump(yaml)
      file.truncate(file.pos)
    end    
  end

  #
  # encapsulate reading a YAML file
  # Opens the file read-only, with a shared lock, and parses the YAML
  # This is yielded to the block (if provided), whilst holding the lock
  # Otherwise the YAML is returned to the caller, and the lock is released
  def self.read(yaml_file)
    File.open(yaml_file, File::RDONLY) do |file|
      file.flock(File::LOCK_SH)
      yaml = YAML.safe_load(file.read) || {} rescue {}
      if block_given?
        yield yaml
      else
        return yaml
      end
    end
  end
end

if __FILE__ == $0
  file = "/tmp/test.yaml"
  YamlFile.update(file) do |yaml|
    yaml['y'] = {ac: 'c'}
  end
  YamlFile.read(file) do |yaml|
    p yaml
  end
  p YamlFile.read(file)
end