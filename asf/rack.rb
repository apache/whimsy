require '/var/tools/asf'
require 'rack'

require 'etc'

module ASF
  module Auth
    DIRECTORS = {
      'curcuru'     => 'sc',
      'cutting'     => 'dc',
      'bdelacretaz' => 'bd',
      'fielding'    => 'rf',
      'jim'         => 'jj',
      'mattmann'    => 'cm',
      'brett'       => 'bp',
      'rubys'       => 'sr',
      'gstein'      => 'gs'
    }

    class MembersAndOfficers < Rack::Auth::Basic
      def initialize(app)
        super(app, "ASF Members and Officers", &proc {})
      end

      def call(env)
        authorized = false

        $USER = ENV['REMOTE_USER'] ||= ENV['USER'] || Etc.getpwuid.name

        authorized ||= DIRECTORS[$USER]
        authorized ||= ASF::Person.new($USER).asf_member?
        authorized ||= ASF.pmc_chairs.include? $USER
        authorized ||= ($USER == 'ea')

        if authorized
          @app.call(env)
        else
          unauthorized
        end
      end
    end
  end
end
