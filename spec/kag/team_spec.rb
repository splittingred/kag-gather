require 'spec_helper'
require 'kag/config'
require 'kag/server'
require 'kag/match'

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
        :server => server
    })
    match = KAG::Gather::Team.new(SymbolTable.new({
        :players => %w(player1 player2 player3),
        :match => match,
        :color => "\x0312",
        :name => "Blue"
    }))
    match
  end

  it "ensure setup_classes() works" do
    team = subject.setup_classes
    team[:players].values.uniq.length.should eq(team[:players].values.length)
  end
end