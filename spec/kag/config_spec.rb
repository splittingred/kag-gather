require 'spec_helper'
require 'kag/config'

##
# Testing for the server functions
#
describe KAG::Config do
  subject do
    KAG::Config.data
  end

  it "ensure data works" do
    subject.should_not eq(nil)
  end
end