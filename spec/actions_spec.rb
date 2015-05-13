#
# This specifies server actions which generally are performed in response
# to a form action.
#

require_relative 'spec_helper'
require_relative '../models/pending'
require 'shellwords'

feature 'server actions' do
  before :each do
    @test_data = File.read('test/work/data/test.yml')
    @transcript = ''
    @cleanup = []
  end

  #
  # Index
  #
  describe 'index' do
    it "should post new special orders" do
      @agenda = 'board_agenda_2015_02_18.txt'
      @attach = '7?'
      @title = 'Establish Test Project'
      @report = 'WHEREAS, RESOLVED, and other official words'

      eval(File.read('views/actions/post.json.rb'))

      resolution = @agenda.find {|item| item[:attach] == '7G'}
      expect(resolution['title']).to eq('Establish Test')
      expect(resolution['text']).
        to eq('WHEREAS, RESOLVED, and other official words')
    end
  end

  #
  # Roll Call
  #
  describe 'roll call' do
    it "should support adding a guest" do
      @agenda = 'board_agenda_2015_01_21.txt'
      @action = 'attend'
      @name = 'N. E. Member'

      eval(File.read('views/actions/attend.json.rb'))
      rollcall = @agenda.find {|item| item['title'] == 'Roll Call'}
      expect(rollcall['text']).to match /Guests.*N\. E\. Member/m
    end

    it "should support a director's regrets" do
      @agenda = 'board_agenda_2015_01_21.txt'
      @action = 'regrets'
      @name = 'Sam Ruby'

      eval(File.read('views/actions/attend.json.rb'))
      rollcall = @agenda.find {|item| item['title'] == 'Roll Call'}
      expect(rollcall['text']).to match /Directors .* Absent:\s+Sam Ruby/
    end

    it "should support moving a director back to attending" do
      @agenda = 'board_agenda_2015_02_18.txt'
      @action = 'attend'
      @name = 'Greg Stein'

      eval(File.read('views/actions/attend.json.rb'))
      rollcall = @agenda.find {|item| item['title'] == 'Roll Call'}
      expect(rollcall['text']).to match /Greg Stein\s+Directors .* Absent:/
    end

    it "should support a officer's regrets" do
      @agenda = 'board_agenda_2015_01_21.txt'
      @action = 'regrets'
      @name = 'Craig L Russell'

      eval(File.read('views/actions/attend.json.rb'))
      rollcall = @agenda.find {|item| item['title'] == 'Roll Call'}
      expect(rollcall['text']).to match /Officers .* Absent:\s+Craig L Russell/
    end
  end

  #
  # PMC Report
  #
  describe 'pmc report' do
    it "should post a comment" do
      @initials = 'xx'
      @agenda = 'board_agenda_2015_01_21.txt'
      @attach = 'Z'
      @comment = 'testing'

      eval(File.read('views/actions/comment.json.rb'))
      expect(Pending.get('test')['comments']['Z']).to eq('testing')
      expect(Pending.get('test')['initials']).to eq('xx')
    end

    it "should remove a comment" do
      expect(Pending.get('test')['comments']['I']).to eq('Nice report!')

      @initials = 'xx'
      @agenda = 'board_agenda_2015_01_21.txt'
      @attach = 'I'
      @comment = nil

      eval(File.read('views/actions/comment.json.rb'))
      expect(Pending.get('test')['comments']).not_to include('I')
    end

    it "should reset comments when the agenda changes" do
      expect(Pending.get('test')['comments']['I']).to eq('Nice report!')

      @initials = 'xx'
      @agenda = 'board_agenda_2015_02_18.txt'
      @attach = 'Z'
      @comment = nil

      eval(File.read('views/actions/comment.json.rb'))
      expect(Pending.get('test')['comments']).not_to include('I')
    end

    it "should approve a report" do
      @agenda = 'board_agenda_2015_01_21.txt'
      @initials = 'jt'
      @attach = 'C'
      @request = 'approve'

      eval(File.read('views/actions/approve.json.rb'))
      expect(Pending.get('test')['approved']).to include('C')
    end

    it "should unapprove a report which is pending approval" do
      expect(Pending.get('test')['approved']).to include('7')

      @agenda = 'board_agenda_2015_01_21.txt'
      @initials = 'jt'
      @attach = '7'
      @request = 'unapprove'

      eval(File.read('views/actions/approve.json.rb'))
      expect(Pending.get('test')['approved']).not_to include('7')
    end

    it "should unapprove a previously approved report" do
      expect(Pending.get('test')['unapproved']).not_to include('BM')

      @agenda = 'board_agenda_2015_01_21.txt'
      @initials = 'jt'
      @attach = 'BM'
      @request = 'unapprove'

      eval(File.read('views/actions/approve.json.rb'))
      expect(Pending.get('test')['unapproved']).to include('BM')
    end

    it "should flag a report" do
      expect(Pending.get('test')['flagged']).not_to include('J')

      @agenda = 'board_agenda_2015_01_21.txt'
      @initials = 'jt'
      @attach = 'J'
      @request = 'flag'

      eval(File.read('views/actions/approve.json.rb'))
      expect(Pending.get('test')['flagged']).to include('J')
    end

    it "should unflag a report" do
      expect(Pending.get('test')['unflagged']).not_to include('AS')

      @agenda = 'board_agenda_2015_02_18.txt'
      @initials = 'jt'
      @attach = 'AS'
      @request = 'unflag'

      eval(File.read('views/actions/approve.json.rb'))
      expect(Pending.get('test')['unflagged']).to include('AS')
    end

    it "should unflag a report which is pending being flagged" do
      expect(Pending.get('test')['flagged']).to include('H')

      @agenda = 'board_agenda_2015_01_21.txt'
      @initials = 'jt'
      @attach = 'H'
      @request = 'unflag'

      eval(File.read('views/actions/approve.json.rb'))
      expect(Pending.get('test')['flagged']).not_to include('H')
    end

    it "should post/edit a report" do
      @agenda = 'board_agenda_2015_02_18.txt'
      @parsed = Agenda.parse @agenda, :quick
      poi = @parsed.find {|item| item['title'] == 'POI'}
      @attach = poi[:attach]
      @digest = poi['digest']
      @message = 'Dummy report for POI'
      @report = 'Nothing to see here.  Move along.'

      eval(File.read('views/actions/post.json.rb'))

      poi = @agenda.find {|item| item['title'] == 'POI'}
      expect(poi['report']).to eq('Nothing to see here.  Move along.')
    end
  end

  #
  # Queue / Pending
  #
  describe 'pending queue' do
    it "should commit pending comments and approvals" do
      @pending = Pending.get('test')
      @parsed = Agenda.parse 'board_agenda_2015_01_21.txt', :quick
      expect(@pending['approved']).to include('7')
      expect(@pending['comments']['I']).to eq('Nice report!')

      security = @parsed.find {|item| item[:attach] == '9'}
      expect(security['approved']).to include('jt')

      w3c = @parsed.find {|item| item[:attach] == '7'}
      expect(w3c['approved']).not_to include('jt')

      avro = @parsed.find {|item| item[:attach] == 'I'}
      expect(avro['comments']).not_to include('jt: Nice report!')

      actions = @parsed.find {|item| item['title'] == 'Action Items'}
      expect(actions['text']).not_to \
        include("Clarification provided in this month's report.")

      @message = "Approve W3C Relations\nComment on BookKeeper\nUpdate 1 AI"
      @initials = 'jt'

      eval(File.read('views/actions/commit.json.rb'))

      expect(@pending['approved']).not_to include('7')
      expect(@pending['comments']).not_to include('I')

      security = @agenda.find {|item| item[:attach] == '9'}
      expect(security['approved']).not_to include('jt')

      w3c = @agenda.find {|item| item[:attach] == '7'}
      expect(w3c['approved']).to include('jt')

      avro = @agenda.find {|item| item[:attach] == 'I'}
      expect(avro['comments']).to include('jt: Nice report!')

      actions = @agenda.find {|item| item['title'] == 'Action Items'}
      expect(actions['text']).to \
        include("Clarification provided in this month's report.")
    end
  end

  ##########################################################################
  #
  # cleanup
  #
  after :each do
    File.write('test/work/data/test.yml', @test_data)

    @cleanup.each do |file| 
      Agenda[File.basename(file)].replace :mtime=>0
    end
  end

  # 
  # administrivia
  #

  # wunderbar environment
  def _
    self
  end

  # sinatra environment
  def env
    Struct.new(:user, :password).new('test', nil)
  end

  # capture wunderbar 'json' output methods
  def method_missing(method, *args, &block)
    if method =~ /^_(\w+)$/ and args.length == 1
      instance_variable_set "@#$1", args.first
    else
      super
    end
  end

  # run system commands, appending output to transcript.
  # intercept commits, adding the files to the cleanup list
  def system(*args)
    args.flatten!
    if args[1] == 'commit'
      @cleanup <<= args[2]
    else
      @transcript += `#{Shellwords.join(args)}`
    end
  end
end
