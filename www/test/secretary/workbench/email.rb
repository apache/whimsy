require 'test/unit'

class EmailTest < Test::Unit::TestCase
  WWW_DIR =  File.absolute_path('../../../../www', __FILE__)

  def setup
    unless defined? @@queue
      Dir.chdir File.absolute_path('../../..', __FILE__)
      load '../www/secretary/workbench/file.cgi'
      @@queue = Wunderbar.queue.dup
      Wunderbar.queue.clear
    end

    Dir.chdir "#{WWW_DIR}/secretary/workbench"

    Mail::TestMailer.deliveries.clear
  end

  def teardown
  end

  def make_pending(*requests)
    # convert symbols into strings in each request
    requests.each do |vars|
      vars.each_key {|key| vars[key.to_s] = vars.delete(key) if key.is_a? Symbol}
    end

    # output pending
    File.open(PENDING_YML, 'w') do |file|
      file.write YAML.dump(requests)
    end
  end

  def test_notify_kafka
    make_pending email: 'nobody@apache.org', podling: 'kafka', doctype: 'icla'

    email('nobody@apache.org', 'message body')

    mail = Mail::TestMailer.deliveries.first

    assert_send [mail.cc, :include?, 'kafka-private@incubator.apache.org']
  end

  def test_notify_jcloud
    make_pending email: 'nobody@apache.org', podling: 'jcloud', doctype: 'icla'

    email('nobody@apache.org', 'message body')

    mail = Mail::TestMailer.deliveries.first

    assert_send [mail.cc, :include?, 'private@jcloud.incubator.apache.org']
  end
end
