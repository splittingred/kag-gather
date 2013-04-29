require 'support/loader'

##
# Testing for the Clan functions
#
describe ::Clan do

  subject do
    clan = ::Clan.new
    clan.name = 'Test'
    clan.save
    clan
  end

  it 'test add_member with valid user' do
    u = ::User.new
    u.kag_user = 'add_member_test'
    u.authname = 'add_member_test'
    u.save
    subject.add_member(u).should eq(true)
  end

  it 'test add_member with fake member' do
    subject.add_member('faker').should eq(false)
  end
end
