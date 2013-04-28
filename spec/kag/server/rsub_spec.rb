require 'support/loader'

##
# Testing for the server functions
#
describe 'Parser !rsub' do

  subject do
    ms = KAG::Test::MatchSetup.new
    parser = ms.start_match(false)
    if parser
      parser
    else
      raise 'Failed to setup match data'
    end
  end

  it 'test !rsub 1' do
    subject.parse('[00:00:00] <[Newb] Cpa3y> !rsub Kalikst').should eq(:request_sub) # should work
    subject.parse('[00:00:00] <Vidar> !rsub Geti').should eq(:request_sub)
    subject.parse('[00:00:00] <Cpa3y> !rsub Cpa3y').should eq(:request_sub)

    #subject.parse('[00:00:00] <[Newb] Cpa3y> !rsub Geti').should_not eq(:request_sub) # should fail
    #subject.parse('[00:00:00] <splittingred> !rsub Furai').should_not eq(:request_sub)
  end

  it 'test !teams' do
    subject.parse('[00:00:00] <[Newb] Geti> !teams').should eq(:teams)
  end

  it 'test rsub on non-existent player' do
    subject.parse('[00:00:00] <Cpa3y> !rsub MM').should_not eq(:request_sub)
    subject.parse('[00:00:00] <MOLE killatron> !rsub killatron').should_not eq(:request_sub)
  end

  it 'test rsub succeeding' do
    subject.live = false
    subject.parse('[00:00:00] <[Newb] Geti> !rsub Vidar').should eq(:request_sub)
    subject.sub_requests.key?('Vidar').should eq(true)
    subject.sub_requests['Vidar'].length.should eq(1)
    subject.parse('[00:00:00] <[Newb] Ardivaba> !rsub Vidar').should eq(:request_sub)
    subject.parse('[00:00:00] <[Newb] Kalikst> !rsub Vidar').should eq(:request_sub)
    subject.sub_requests['Vidar'].length.should eq(3)
  end

end