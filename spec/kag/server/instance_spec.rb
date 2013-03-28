require 'spec_helper'
require 'kag/gather/match'
require 'kag/server/instance'
##
# Testing for the server functions
#
describe KAG::Server::Instance do
  subject do
    ks = KAG::Config.instance[:servers].keys
    KAG::Server::Instance.new({},"test",KAG::Config.instance[:servers][ks.first])
  end

  it "test match start" do
    match = KAG::Gather::Match.new
    subject.start(match)
    sleep 2
    data = subject.stop
    puts data.inspect
  end

  #it "test kick()" do
    #subject.connect.should eq(true)
    #subject.kick("splittingred")
    #subject.disconnect
  #end

  #it "test kick_all()" do
  #  subject.connect.should eq(true)
  #  subject.kick_all
  #  subject.disconnect
  #end
end