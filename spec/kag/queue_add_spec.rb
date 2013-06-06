require 'support/loader'

##
# Testing for the server functions
#
describe 'Queue Adding' do
  subject do
    queue = GatherQueue.new
    queue.save
    queue
  end

  it 'ensure server preference' do
    p = GatherQueuePlayer.new
    p.gather_queue_id = subject.id
    p.user_id = 1
    p.server_preference = 'EU'
    p.save
    p.server_preference.should eq('EU')

    p = GatherQueuePlayer.new
    p.gather_queue_id = subject.id
    p.user_id = 2
    p.server_preference = 'EU'
    p.save
    p.server_preference.should eq('EU')

    p = GatherQueuePlayer.new
    p.gather_queue_id = subject.id
    p.user_id = 3
    p.server_preference = 'US'
    p.save
    p.server_preference.should eq('US')

    p = GatherQueuePlayer.new
    p.gather_queue_id = subject.id
    p.user_id = 4
    p.save
    p.server_preference.should eq(nil)

    server = ::Server.find_unused(subject)
    server.region.should eq('EU')
  end


  it 'ensure server preference alternate' do
    p = GatherQueuePlayer.new
    p.gather_queue_id = subject.id
    p.user_id = 1
    p.server_preference = 'US'
    p.save
    p.server_preference.should eq('US')

    p = GatherQueuePlayer.new
    p.gather_queue_id = subject.id
    p.user_id = 2
    p.server_preference = 'US'
    p.save
    p.server_preference.should eq('US')

    p = GatherQueuePlayer.new
    p.gather_queue_id = subject.id
    p.user_id = 3
    p.server_preference = 'AUS'
    p.save
    p.server_preference.should eq('AUS')

    p = GatherQueuePlayer.new
    p.gather_queue_id = subject.id
    p.user_id = 4
    p.save
    p.server_preference.should eq(nil)

    p = GatherQueuePlayer.new
    p.gather_queue_id = subject.id
    p.user_id = 5
    p.server_preference = 'EU'
    p.save
    p.server_preference.should eq('EU')

    server = ::Server.find_unused(subject)
    server.region.should eq('US')
  end



  it 'ensure server preference none specified' do
    p = GatherQueuePlayer.new
    p.gather_queue_id = subject.id
    p.user_id = 1
    p.save
    p.server_preference.should eq(nil)

    p = GatherQueuePlayer.new
    p.gather_queue_id = subject.id
    p.user_id = 2
    p.save
    p.server_preference.should eq(nil)

    p = GatherQueuePlayer.new
    p.gather_queue_id = subject.id
    p.user_id = 3
    p.save
    p.server_preference.should eq(nil)

    p = GatherQueuePlayer.new
    p.gather_queue_id = subject.id
    p.user_id = 4
    p.save
    p.server_preference.should eq(nil)

    p = GatherQueuePlayer.new
    p.gather_queue_id = subject.id
    p.user_id = 5
    p.save
    p.server_preference.should eq(nil)

    server = ::Server.find_unused(subject)
    server.should_not eq(nil)
  end
end