#
# Implement an _svn command for json actions.
#
# Once tested, this code could migrate into whimsy/asf, and be available
# for all Rack application (e.g., secmail, board/agenda, roster)
#

# provide methods to encapsulate LDAP update
module ASF
  class SVN
    class JsonBuilder
      def initialize(env, builder, dryrun)
        @env = env
        @builder = builder
        @dryrun = dryrun
      end

      def update(name, options, &block)
        ASF::SVN.update(name, options[:message], @env, @builder,
          dryrun: @dryrun, &block)
      end
    end
  end
end

# provide _svn command which forwards requests to the ASF::SVN::JsonBuilder
module Wunderbar
  class JsonBuilder
    def _svn
      ASF::SVN::JsonBuilder.new(env, self, params['dryrun'])
    end
  end
end
