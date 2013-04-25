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
    subject.parse('[00:00:00] <killatron> !rsub Ardivaba').should eq(:request_sub)

    #subject.parse('[00:00:00] <[Newb] Cpa3y> !rsub Geti').should_not eq(:request_sub) # should fail
    #subject.parse('[00:00:00] <splittingred> !rsub Furai').should_not eq(:request_sub)
  end

  it 'test !teams' do
    subject.parse('[00:00:00] <[Newb] Geti> !teams').should eq(:teams)
  end

end