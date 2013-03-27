require 'spec_helper'
require 'kag/server/instance'
##
# Testing for the server functions
#
describe KAG::Server::Parser do
  subject do
    ks = KAG::Config.instance[:servers].keys
    KAG::Server::Parser.new KAG::Config.instance[:servers][ks.first]
  end

  it "test restart map" do
    subject.parse("[00:00:00] *Restarting Map*").should eq(:map_restart)
  end
  it "test match started" do
    subject.parse("[00:00:00] *Match Started*").should eq(:match_start)
  end
  it "test match ended" do
    subject.parse("[00:00:00] *Match Ended*").should eq(:match_end)
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

  it "test player ready" do
    subject.live = false
    subject.parse("[00:00:00] <[Newb] Geti> !ready").should eq(:ready)
    subject.live = false
    subject.parse("[00:00:00] <[Pk#] master4523> !ready").should eq(:ready)
    subject.live = false
    subject.parse("[00:00:00] <[Pk#] name_with_underscore> !ready").should eq(:ready)
    subject.live = false
    subject.parse("[00:00:00] <[Pk#] dot.me.up> !ready").should eq(:ready)
  end

  it "prevent multiple ready calls" do
    subject.live = false
    subject.parse("[00:00:00] <[Newb] Geti> !ready").should eq(:ready)
    subject.parse("[00:00:00] <[Newb] Geti> !ready").should eq(nil)
  end

  it "test player veto" do
    subject.live = false
    subject.parse("[00:00:00] <[Newb] Geti> !veto").should eq(:veto)
    subject.parse("[00:00:00] <[Pk#] master4523> !veto").should eq(:veto)
    subject.parse("[00:00:00] <[Pk#] name_with_underscore> !veto").should eq(:veto)
    subject.parse("[00:00:00] <[Pk#] dot.me.up> !veto").should eq(:veto)
  end

  # kill tests

  it "test slew" do
    subject.live = true
    subject.parse("[00:00:00] Vidar slew Geti with his sword").should eq(:slew)
    subject.data.players[:Vidar][:kill].should eq(1)
    subject.data.players[:Geti][:death].should eq(1)
    subject.parse("[00:00:00] Vidar slew Geti with her sword").should eq(:slew)
    subject.data.players[:Vidar][:kill].should eq(2)
    subject.data.players[:Geti][:death].should eq(2)
  end
  it "test gibbed" do
    subject.live = true
    subject.parse("[00:00:00] Vidar gibbed Geti into pieces").should eq(:gibbed)
    subject.data.players[:Vidar][:kill].should eq(1)
    subject.data.players[:Geti][:death].should eq(1)
  end
  it "test shot" do
    subject.live = true
    subject.parse("[00:00:00] Vidar shot Geti with his arrow").should eq(:shot)
    subject.data.players[:Vidar][:kill].should eq(1)
    subject.data.players[:Geti][:death].should eq(1)
    subject.parse("[00:00:00] Vidar shot Geti with her arrow").should eq(:shot)
    subject.data.players[:Vidar][:kill].should eq(2)
    subject.data.players[:Geti][:death].should eq(2)
  end
  it "test hammered" do
    subject.live = true
    subject.parse("[00:00:00] Vidar hammered Geti to death").should eq(:hammered)
    subject.data.players[:Vidar][:kill].should eq(1)
    subject.data.players[:Geti][:death].should eq(1)
  end
  it "test pushed" do
    subject.live = true
    subject.parse("[00:00:00] Vidar pushed Geti to his death").should eq(:pushed)
    subject.data.players[:Vidar][:kill].should eq(1)
    subject.data.players[:Geti][:death].should eq(1)
    subject.parse("[00:00:00] Vidar pushed Geti on a spike trap").should eq(:pushed)
    subject.data.players[:Vidar][:kill].should eq(2)
    subject.data.players[:Geti][:death].should eq(2)
  end
  it "test assisted" do
    subject.live = true
    subject.parse("[00:00:00] Vidar assisted in squashing Geti under falling rocks").should eq(:assisted)
    subject.data.players[:Vidar][:kill].should eq(1)
    subject.data.players[:Geti][:death].should eq(1)
    subject.parse("[00:00:00] Vidar assisted in Geti dying under a collapse").should eq(:assisted)
    subject.data.players[:Vidar][:kill].should eq(2)
    subject.data.players[:Geti][:death].should eq(2)
  end
  it "test squashed" do
    subject.live = true
    subject.parse("[00:00:00] Geti was squashed under a collapse").should eq(:squashed)
    subject.data.players[:Geti][:death].should eq(1)
  end
  it "test fell" do
    subject.live = true
    subject.parse("[00:00:00] Geti fell to his death").should eq(:fell)
    subject.data.players[:Geti][:death].should eq(1)
    subject.parse("[00:00:00] Geti fell on a spike trap").should eq(:fell)
    subject.data.players[:Geti][:death].should eq(2)
    subject.parse("[00:00:00] Geti fell to her death").should eq(:fell)
    subject.data.players[:Geti][:death].should eq(3)
  end
  it "test cyanide" do
    subject.live = true
    subject.parse("[00:00:00] Geti took some cyanide").should eq(:cyanide)
    subject.data.players[:Geti][:death].should eq(1)
  end
  it "test died" do
    subject.live = true
    subject.parse("[00:00:00] Geti died under falling rocks").should eq(:died)
    subject.data.players[:Geti][:death].should eq(1)
  end
end