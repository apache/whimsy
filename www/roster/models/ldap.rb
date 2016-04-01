#
# Implement an _ldap command for json actions.
#
# Once tested, this code could migrate into whimsy/asf, and be available
# for all Rack application (e.g., secmail, board/agenda, roster)
#

# provide methods to encapsulate updates update LDAP
module ASF
  module LDAP
    class JsonBuilder
      def initialize(env)
        @env = env
      end

      def update(&block)
        ASF::LDAP.bind(@env.user, @env.password, &block)
      end
    end
  end
end

# provide _ldap command which forwards requests to the ASF::LDAP::JsonBuilder
module Wunderbar
  class JsonBuilder
    def _ldap
      ASF::LDAP::JsonBuilder.new(env)
    end
  end
end
