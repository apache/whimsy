require 'bundler'
require 'whimsy/asf/config'

module Bundler
  #
  # modify bundler to be aware of whimsy library overrides
  #
  class Dsl
    bundler_gem = instance_method(:gem)
    libs = ASF::Config.get(:lib)

    define_method :gem do |name, *args|
      pname = name.gsub('-', '/')

      path = nil
      libs.each do |lib|
        if File.exist?(File.join(lib, pname))
          path = lib
        end
      end

      if path
        args.push({}) unless args.last.is_a?(Hash)
        args.last[:path] = File.dirname(path)
      end

      bundler_gem.bind(self).(name, *args)
    end
  end
end

require 'bundler/setup'
