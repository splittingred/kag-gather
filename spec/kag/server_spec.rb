require 'spec_helper'
require 'kag/server'
##
# Testing for the server functions
#
describe KAG::Server do
  subject do
    ks = KAG::Config.instance[:servers].keys
    KAG::Server.new(KAG::Config.instance[:servers][ks.first])
  end

  it "ensure info() works" do
    subject.connect.should eq(true)
    i = subject.info
    i.should_not eq(false)
    subject.disconnect
  end

  it "test players()" do
    subject.connect.should eq(true)
    i = subject.players
    puts i.inspect
    #i.should_not eq("")
    subject.disconnect
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