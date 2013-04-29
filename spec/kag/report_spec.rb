require 'support/loader'

##
# Testing for the server functions
#
describe ::IgnoreReport do
  subject do

  end

  it 'ensure regexp works' do
    /report ((?:\w+\S){2})(.*)/i.match('!report dudeman he\'s being a jerk as usual').should_not eq(nil)
  end
end