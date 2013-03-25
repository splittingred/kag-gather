require 'spec_helper'
require 'kag/config'
require 'kag/server'
require 'kag/gather/match'
require 'kag/gather/team'

##
# Testing for the server functions
#
describe KAG::Server do
  subject do
    KAG::Config.instance[:match_size] = 6
    KAG::Config.instance[:classes] = %w(Knight Archer Builder)
    ks = KAG::Config.instance[:servers].keys
    server = KAG::Server.new(KAG::Config.instance[:servers][ks.first])
    match = KAG::Gather::Match.new({
        :server => server,
        :subs_needed => []
    })
    player_list = %w(player1 player2 player3)
    players = {}
    player_list.each do |p|
      players[p.to_sym] = {:authname => p,:nick => p}
    end

    team = KAG::Gather::Team.new(SymbolTable.new({
        :players => players,
        :match => match,
        :color => "\x0312",
        :name => "Blue"
    }))
    team
  end

  it "ensure setup_classes() works" do
    team = subject.setup_classes
    puts team.inspect
    team.players.values.uniq.length.should eq(team.players.values.length)
  end

  it "ensure remove_player() works" do
    subject.setup_classes
    user = SymbolTable.new({:authname => "player2",:nick => "player2"})
    subject.remove_player(user).should_not eq(false)
  end
end