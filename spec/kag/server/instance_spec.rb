require 'spec_helper'
require 'kag/gather/match'
require 'kag/server/instance'
##
# Testing for the server functions
#
describe KAG::Server::Instance do
  subject do
    ks = KAG::Config.instance[:servers].keys
    KAG::Config.instance[:servers][ks.first]
  end

  it "test match start" do
    server = KAG::Server::Instance.new({},"test",subject)
    match = KAG::Gather::Match.new
    server.start(match)
    sleep 2
    data = server.stop
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