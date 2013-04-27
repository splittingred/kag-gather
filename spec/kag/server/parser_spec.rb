require 'support/loader'

##
# Testing for the server functions
#
describe KAG::Server::Parser do

  subject do
    ms = KAG::Test::MatchSetup.new
    ms.start_match
  end

  it "test say" do
    subject.parse("[00:00:00] <[Newb] Geti> @this is a message").should eq(:say)
  end

  it "test restart map" do
    subject.parse("[00:00:00] *Restarting Map*").should eq(:map_restart)
  end
  it "test match started" do
    subject.live = true
    subject.parse("[00:00:00] *Match Started*").should eq(:round_start)
  end
  it "test match ended" do
    subject.live = true
    subject.parse("[00:00:00] *Match Ended*").should eq(:round_end)
  end
  it "test match win" do
    subject.live = true
    subject.parse("[00:00:00] Red Team wins the game!").should eq(:match_win)
    subject.live = true
    subject.parse("[00:00:00] Blue Team wins the game!").should eq(:match_win)
  end
  it "test units depleted" do
    subject.live = true
    subject.parse("[00:00:00] Can't spawn units depleted").should eq(:units_depleted)
  end
  it "test player join then rename" do
    subject.parse("[00:00:00] Unnamed player is now known as Geti").should eq(:player_joined_renamed)
  end
  it "test player renamed" do
    subject.parse("[00:00:00] Geti is now known as [Newb] Geti").should eq(:player_renamed)
    subject.parse("[00:00:00] [Newb] Geti is now known as [Dev] Geti").should eq(:player_renamed)
  end

  it 'test player ready' do
    subject.live = false
    subject.parse('[00:00:00] <[Newb] Geti> !ready Archer').should eq(:ready)
    subject.live = false
    subject.parse('[00:00:00] <[Pk#] master4523> !ready Knight').should eq(:ready)
    subject.live = false
    subject.parse('[00:00:00] <[Pk#] Ardi_vaba> !ready Knight').should eq(:ready)
    subject.live = false
    subject.parse('[00:00:00] <[Pk#] killa.tron> !ready Builder').should eq(:ready)
    subject.live = false
    subject.parse('[00:00:00] <[Pk#] boo> !r Builder').should eq(:ready)
  end

  it 'prevent multiple ready calls' do
    subject.live = false
    subject.parse('[00:00:00] <[=] Vidar> !ready Knight').should eq(:ready)
    subject.parse('[00:00:00] <[=] Vidar> !ready Knight').should eq(nil)
  end

  it "test player veto" do
    subject.live = false
    subject.parse("[00:00:00] <[Newb] Geti> !veto").should eq(:veto)
    subject.parse("[00:00:00] <[Pk#] master4523> !veto").should eq(:veto)
    subject.parse("[00:00:00] <[Pk#] name_with_underscore> !veto").should eq(:veto)
    subject.parse("[00:00:00] <[Pk#] dot.me.up> !veto").should eq(:veto)
  end

  it "test player left" do
    subject.live = true
    subject.parse("[00:00:00] Player [Newb] Geti left the game (players left 0)")

  end

  # kill tests

  it "test slew" do
    subject.live = true
    subject.parse("[00:00:00] Vidar slew Geti with his sword").should eq(:slew)
    subject.data.players['Vidar'][:kill].should eq(1)
    subject.data.players['Geti'][:death].should eq(1)
    subject.parse("[00:00:00] Vidar slew Geti with her sword").should eq(:slew)
    subject.data.players['Vidar'][:kill].should eq(2)
    subject.data.players['Geti'][:death].should eq(2)
  end
  it "test gibbed" do
    subject.live = true
    subject.parse("[00:00:00] Vidar gibbed Geti into pieces").should eq(:gibbed)
    subject.data.players['Vidar'][:kill].should eq(1)
    subject.data.players['Geti'][:death].should eq(1)
  end
  it "test shot" do
    subject.live = true
    subject.parse("[00:00:00] Vidar shot Geti with his arrow").should eq(:shot)
    subject.data.players['Vidar'][:kill].should eq(1)
    subject.data.players['Geti'][:death].should eq(1)
    subject.parse("[00:00:00] Vidar shot Geti with her arrow").should eq(:shot)
    subject.data.players['Vidar'][:kill].should eq(2)
    subject.data.players['Geti'][:death].should eq(2)
  end
  it "test hammered" do
    subject.live = true
    subject.parse("[00:00:00] Vidar hammered Geti to death").should eq(:hammered)
    subject.data.players['Vidar'][:kill].should eq(1)
    subject.data.players['Geti'][:death].should eq(1)
  end
  it "test pushed" do
    subject.live = true
    subject.parse("[00:00:00] Vidar pushed Geti to his death").should eq(:pushed)
    subject.data.players['Vidar'][:kill].should eq(1)
    subject.data.players['Geti'][:death].should eq(1)
    subject.parse("[00:00:00] Vidar pushed Geti on a spike trap").should eq(:pushed)
    subject.data.players['Vidar'][:kill].should eq(2)
    subject.data.players['Geti'][:death].should eq(2)
  end
  it "test assisted" do
    subject.live = true
    subject.parse("[00:00:00] Vidar assisted in squashing Geti under falling rocks").should eq(:assisted)
    subject.data.players['Vidar'][:kill].should eq(1)
    subject.data.players['Geti'][:death].should eq(1)
    subject.parse("[00:00:00] Vidar assisted in Geti dying under a collapse").should eq(:assisted)
    subject.data.players['Vidar'][:kill].should eq(2)
    subject.data.players['Geti'][:death].should eq(2)
  end
  it "test squashed" do
    subject.live = true
    subject.parse("[00:00:00] Geti was squashed under a collapse").should eq(:squashed)
    subject.data.players['Geti'][:death].should eq(1)
  end
  it "test fell" do
    subject.live = true
    subject.parse("[00:00:00] Geti fell to his death").should eq(:fell)
    subject.data.players['Geti'][:death].should eq(1)
    subject.parse("[00:00:00] Geti fell on a spike trap").should eq(:fell)
    subject.data.players['Geti'][:death].should eq(2)
    subject.parse("[00:00:00] Geti fell to her death").should eq(:fell)
    subject.data.players['Geti'][:death].should eq(3)
  end
  it "test cyanide" do
    subject.live = true
    subject.parse("[00:00:00] Geti took some cyanide").should eq(:cyanide)
    subject.data.players['Geti'][:death].should eq(1)
  end
  it "test died" do
    subject.live = true
    subject.parse("[00:00:00] Geti died under falling rocks").should eq(:died)
    subject.data.players['Geti'][:death].should eq(1)
  end

  it "test ready threshold calculations" do
    subject._get_ready_threshold(10).should eq(10)
    subject._get_ready_threshold(2).should eq(1)
    subject._get_ready_threshold(6).should eq(6)
  end

  it "test !ready and !unready" do
    subject.live = false
    subject.parse("[00:00:00] <Geti> !ready Archer").should eq(:ready)
    subject.ready.length.should eq(1)
    subject.parse("[00:00:00] <Geti> !unready").should eq(:unready)
    subject.ready.length.should eq(0)
  end

  it "test !score" do
    subject.parse("[00:00:00] <[Newb] Geti> !score").should eq(:score)
    subject.live = true
    subject.parse("[00:00:00] Red Team wins the game!").should eq(:match_win)
    subject.live = false
    subject.parse("[00:00:00] <[Newb] Geti> !score").should eq(:score)
  end

  it "test archive" do
    subject.live = true
    subject.parse("[00:00:00] Vidar gibbed Geti into pieces")
    subject.parse("[00:00:00] Vidar slew Geti with his sword")
    subject.archive
    u = User.fetch("Geti")
    u.stat(:deaths).should eq(2)
    u.stat("deaths.gibbed").should eq(1)

    u = User.fetch("Vidar")
    u.stat(:kills).should eq(2)
    u.stat("kills.gibbed").should eq(1)
  end
end