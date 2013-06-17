require 'support/loader'
require 'support/team_balance_setup'

##
# Testing for team balance
#
describe 'Team Balance' do
  subject do
    ms = KAG::Test::TeamBalanceSetup.new
    ms.start_match
  end

  it 'ensure balance works' do
    puts subject.info_text
  end
end