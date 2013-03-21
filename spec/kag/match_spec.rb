require 'spec_helper'
require 'kag/config'
require 'kag/server'
require 'kag/match'

##
# Testing for the server functions
#
describe KAG::Server do
  subject do
    ks = KAG::Config.instance[:servers].keys
    server = KAG::Server.new(KAG::Config.instance[:servers][ks.first])
    match = KAG::Match.new(SymbolTable.new({
        :server => server,
        :players => %w(player1 player2 player3 player4 player5 player6 player7 player8 player9 player10)
    }))
    KAG::Config.instance[:match_size] = 10
    match
  end

  it "ensure setup_teams() works" do
    teams = subject.setup_teams
    teams.should_not eq(false)
  end

  it "ensure text_for_match_start works" do
    subject.setup_teams
    msg = subject.text_for_match_start
    puts msg
    msg.should_not eq(false)
  end
end