require 'support/loader'

##
# Testing for the server functions
#
describe Server do
  subject do
    server = Server.new
    KAG::Server::Listener.new(server)
  end
  # commented out for now to prevent automation issues
  #it "test players" do
    #match = KAG::Gather::Match.new
    #subject.start(match)
    #subject.players
    #subject.terminate
    #sleep 0.5
    #server.stop_listening
  #end

  #it "test kick()" do
    #subject.connect.should eq(true)
    #subject.kick("splittingred")
    #subject.disconnect
  #end

  #it "test kick_all()" do
  #  subject.connect.should eq(true)
  #  subject.kick_all
  #  subject.disconnect
  #end
end