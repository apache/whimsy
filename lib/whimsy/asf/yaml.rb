#!/usr/bin/env ruby

require 'yaml'

#
# YAML file support
#

module YamlFile

  #
  # encapsulate updates to a YAML file
  # opens the file for exclusive access with an exclusive lock,
  # creating the file if necessary
  # Yields the parsed YAML to the block, and writes the return
  # data to the file; if the block returns nil, the file will not be updated
  # The args are passed to YAML.safe_load, and default to permitted_classes: [Symbol]
  def self.update(yaml_file, *args)
    File.open(yaml_file, File::RDWR|File::CREAT, 0o644) do |file|
      file.flock(File::LOCK_EX)
      if args.empty?
        yaml = YAML.safe_load(file.read, permitted_classes: [Symbol]) || {}
      else
        yaml = YAML.safe_load(file.read, *args) || {}
      end
      output = yield yaml
      unless output.nil?
        file.rewind
        file.write YAML.dump(output)
        file.truncate(file.pos)
      end
    end
  end

  # replace a section of YAML text whilst preserving surrounding data including comments.
  # The args are passed to YAML.safe_load, and default to permitted_classes: [Symbol]
  # The caller must provide a block, which is passed two JSON parameters:
  # - the section related to the key
  # - the entire file (this is for validation purposes)
  # Returns the updated text. If the block returns nil, returns nil so the
  # caller can skip the file update
  def self.replace_section(content, key, *args)
    raise ArgumentError, 'block is required' unless block_given?

    if args.empty?
      yaml = YAML.safe_load(content, permitted_classes: [Symbol])
    else
      yaml = YAML.safe_load(content, *args)
    end

    section = yaml[key]
    unless section
      raise ArgumentError, "Could not find section #{key.inspect}"
    end

    res = yield(section, yaml) # get the updated JSON

    return nil if res.nil? # i.e. don't update text

    output = content.dup # don't mutate caller data

    # Create the updated section with the correct indentation
    # Use YAML dump to ensure correct syntax; drop the YAML header
    new_section = YAML.dump({key => res}).sub(/\A---\n/, '')

    # replace the old section with the new one
    # assume it is delimited by the key and '...' or another key.
    # Keys may be symbols. Only handles top-level key matching.
    range = %r{^#{Regexp.escape(key.inspect)}:\s*$.*?(?=^(:?\w+:|\.\.\.)$)}m
    output[range] = new_section

    output
  end

  # encapsulate updates to a section of a YAML file whilst
  # preserving surrounding data including comments.
  # opens the file for exclusive access
  # Yields the parsed YAML to the block, and writes the updated
  # data to the file
  # The args are passed to YAML.safe_load, and default to permitted_classes: [Symbol]
  # [originally designed for updating committee-info.yaml]
  def self.update_section(yaml_file, key, *args, &block)
    raise ArgumentError, 'block is required' unless block_given?

    File.open(yaml_file, File::RDWR) do |file|
      file.flock(File::LOCK_EX)

      content = replace_section(file.read, key, *args, &block)

      unless content.nil?
        # rewrite the file
        file.rewind
        file.write content
        file.truncate(file.pos)
      end
    end
  end

  #
  # encapsulate reading a YAML file
  # Opens the file read-only, with a shared lock, and parses the YAML
  # This is yielded to the block (if provided), whilst holding the lock
  # Otherwise the YAML is returned to the caller, and the lock is released
  # The args are passed to YAML.safe_load, and default to permitted_classes: [Symbol]
  def self.read(yaml_file, *args)
    File.open(yaml_file, File::RDONLY) do |file|
      file.flock(File::LOCK_SH)
      if args.empty?
        yaml = YAML.safe_load(file.read, permitted_classes: [Symbol])
      else
        yaml = YAML.safe_load(file.read, *args)
      end
      if block_given?
        yield yaml
      else
        return yaml
      end
    end
  end
end
