#
# This specifies server actions which generally are performed in response
# to a form action.
#

require_relative 'spec_helper'
require_relative '../models/pending'

feature 'server actions' do
  before :each do
    @pending = File.read('test/work/data/test.yml')
  end

  def env
    Struct.new(:user).new('test')
  end

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

  after :each do
    File.write('test/work/data/test.yml', @pending)
  end
end
