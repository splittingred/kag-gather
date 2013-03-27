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

  # kill tests

  it "test slew" do
    subject.parse("Vidar slew Geti with his sword").should eq(:slew)
    subject.data.players[:Vidar][:kill].should eq(1)
    subject.data.players[:Geti][:death].should eq(1)
    subject.parse("Vidar slew Geti with her sword").should eq(:slew)
    subject.data.players[:Vidar][:kill].should eq(2)
    subject.data.players[:Geti][:death].should eq(2)
  end
  it "test gibbed" do
    subject.parse("Vidar gibbed Geti into pieces").should eq(:gibbed)
    subject.data.players[:Vidar][:kill].should eq(1)
    subject.data.players[:Geti][:death].should eq(1)
  end
  it "test shot" do
    subject.parse("Vidar shot Geti with his arrow").should eq(:shot)
    subject.data.players[:Vidar][:kill].should eq(1)
    subject.data.players[:Geti][:death].should eq(1)
    subject.parse("Vidar shot Geti with her arrow").should eq(:shot)
    subject.data.players[:Vidar][:kill].should eq(2)
    subject.data.players[:Geti][:death].should eq(2)
  end
  it "test hammered" do
    subject.parse("Vidar hammered Geti to death").should eq(:hammered)
    subject.data.players[:Vidar][:kill].should eq(1)
    subject.data.players[:Geti][:death].should eq(1)
  end
  it "test pushed" do
    subject.parse("Vidar pushed Geti to his death").should eq(:pushed)
    subject.data.players[:Vidar][:kill].should eq(1)
    subject.data.players[:Geti][:death].should eq(1)
    subject.parse("Vidar pushed Geti on a spike trap").should eq(:pushed)
    subject.data.players[:Vidar][:kill].should eq(2)
    subject.data.players[:Geti][:death].should eq(2)
  end
  it "test assisted" do
    subject.parse("Vidar assisted in squashing Geti under falling rocks").should eq(:assisted)
    subject.data.players[:Vidar][:kill].should eq(1)
    subject.data.players[:Geti][:death].should eq(1)
    subject.parse("Vidar assisted in Geti dying under a collapse").should eq(:assisted)
    subject.data.players[:Vidar][:kill].should eq(2)
    subject.data.players[:Geti][:death].should eq(2)
  end
  it "test squashed" do
    subject.parse("Geti was squashed under a collapse").should eq(:squashed)
    subject.data.players[:Geti][:death].should eq(1)
  end
  it "test fell" do
    subject.parse("Geti fell to his death").should eq(:fell)
    subject.data.players[:Geti][:death].should eq(1)
    subject.parse("Geti fell on a spike trap").should eq(:fell)
    subject.data.players[:Geti][:death].should eq(2)
    subject.parse("Geti fell to her death").should eq(:fell)
    subject.data.players[:Geti][:death].should eq(3)
  end
  it "test cyanide" do
    subject.parse("Geti took some cyanide").should eq(:cyanide)
    subject.data.players[:Geti][:death].should eq(1)
  end
  it "test died" do
    subject.parse("Geti died under falling rocks").should eq(:died)
    subject.data.players[:Geti][:death].should eq(1)
  end
end