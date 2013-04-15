require 'support/loader'

##
# Testing for the server functions
#
describe KAG::Server::Parser do

  subject do
    ms = KAG::Test::MatchSetup.new
    ms.start_match(false)
  end

  it "test archive" do
    subject.live = true
    subject.parse("[00:00:00] Vidar gibbed Geti into pieces")
    subject.parse("[00:00:00] Vidar slew Geti with his sword")
    subject.parse("[00:00:00] Red Team wins the game!").should eq(:match_win)
    subject.live = true
    subject.parse("[00:00:00] Vidar gibbed Geti into pieces")
    subject.parse("[00:00:00] Vidar slew Geti with his sword")
    subject.parse("[00:00:00] Red Team wins the game!").should eq(:match_win)
    subject.archive

    u = ::User.fetch("Geti")
    u.stat(:deaths).should eq(4)
    u.stat("deaths.gibbed").should eq(2)
    u.stat("deaths.slew").should eq(2)

    u = ::User.fetch("Vidar")
    u.stat(:kills).should eq(4)
    u.stat("kills.gibbed").should eq(2)
    u.stat("kills.slew").should eq(2)
    u.stat(:wins).should eq(1)
  end

end