require 'spec_helper'
require 'kag/gather/match'
require 'kag/server/instance'
##
# Testing for the server functions
#
describe KAG::Server::Instance do
  subject do
    ks = KAG::Config.instance[:servers].keys
    server = KAG::Config.instance[:servers][ks.first]
    KAG::Server::Listener.new(server,server.data)
  end

  it "test players" do
    #match = KAG::Gather::Match.new
    #subject.start(match)
    subject.players
    subject.terminate
    #sleep 0.5
    #server.stop_listening
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