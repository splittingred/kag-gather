require 'spec_helper'
require 'kag/gather/match'
##
# Testing for the server functions
#
describe Server do
  subject do
    ks = KAG::Config.instance[:servers].keys
    KAG::Config.instance[:servers][ks.first]
  end

=begin
  it "test match start" do
    server = KAG::Server::Instance.new({},"test",subject)

    player_list = %w(Geti splittingred Vidar Ardivaba killatron Verra Cpa3y Kalikst Ezreli Furai)
    players = {}
    player_list.each do |p|
      players[p.to_sym] = {:authname => p,:nick => p}
    end

    match = KAG::Gather::Match.new(SymbolTable.new({
        :server => server,
        :players => players
    }))
    match.setup_teams

    server.start(match)
    sleep 2
    #server.listener.puts "<[Newb] Geti> !ready"
    #sleep 2
    server.stop
  end
=end

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