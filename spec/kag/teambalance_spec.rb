require 'support/loader'
require 'support/team_balance_setup'

##
# Testing for team balance
#
describe 'Team Balance' do
  subject do
    KAG::Test::TeamBalanceSetup.new
  end

  it 'ensure balance works with close teams' do
    ms = subject.start_match({
        :killatron => 1460.22,
        :warrfork => 1000.82,
        :magnum357 => 797.32,
        :cpa3y => 894.9,
        :RaMmStEiN_2012 => 777.64,
        :SpideY => 757.17,
        :CrystalClear => 715.23,
        :splittingred => 665.11,
        :Urkeuse => 646.26,
        :Black0ut => 512.85,
    })
    puts ms.info_text(true)
  end

  it 'ensure balance works with teams with 0 scores' do
    ms = subject.start_match({
        :killatron => 1460.22,
        :warrfork => 1000.82,
        :magnum357 => 200.01,
        :cpa3y => 394.9,
        :RaMmStEiN_2012 => 777.64,
        :SpideY => 0,
        :CrystalClear => 0,
        :splittingred => 1965.11,
        :Urkeuse => 0,
        :Black0ut => 0,
    })
    puts ms.info_text(true)
  end


  it 'ensure balance works with teams with 0 scores' do
    ms = subject.start_match({
        :killatron => 1,
        :warrfork => 2,
        :magnum357 => 3,
        :cpa3y => 4,
        :RaMmStEiN_2012 => 5,
        :SpideY => 5,
        :CrystalClear => 5,
        :splittingred => 5,
        :Urkeuse => 3,
        :Black0ut => 0,
    })
    puts ms.info_text(true)
  end
end