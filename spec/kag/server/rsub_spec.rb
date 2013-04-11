require 'support/loader'

##
# Testing for the server functions
#
describe "Parser !rsub" do

  subject do
    ms = KAG::Test::MatchSetup.new
    ms.start_match(false)
  end

  it "test !rsub 1" do

    subject.parse("[00:00:00] <[Newb] Geti> !rsub Cpa3y").should_not eq(:request_sub) # should fail
    subject.parse("[00:00:00] <[Newb] Cpa3y> !rsub Kalikst").should eq(:request_sub) # should work
  end

  it "test !teams" do
    subject.parse("[00:00:00] <[Newb] Geti> !teams").should eq(:teams)
  end

end