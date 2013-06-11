require 'support/loader'

##
# Testing for the IRC !end function
#
describe "IRC !end" do

  subject do
    ms = KAG::Test::MatchSetup.new
    ms.start_match(false)
  end

  it '!end' do
    user = ::User.new
    user.authname = 'test234'
    user.kag_user = 'test234'

    match = ::Match.player_in(user)
    match.should eq(nil)
  end

end