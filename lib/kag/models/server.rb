require 'kag/models/model'
require 'kag/server/listener'
require 'symboltable'

class Server < KAG::Model
  has_many :matches

  attr_accessor :match_in_progress
  attr_accessor :listener,:match_data

  def self.find_unused
    Server.where(:in_use => false).order("RAND()").first
  end


  def start(match)
    self.in_use = 1
    if self.save
      self.match_in_progress = match
      self.match_data = SymbolTable.new

      self.listener = KAG::Server::Listener.new(self,self.match_data)
      self.listener.async.start_listening
    end
  end

  def stop
    puts "Attempting to stop"
    begin
      self.listener.stop_listening
    end

    puts "Stopped, terminating thread"
    puts "Thread terminated"
    self.listener = nil
    self.match_in_progress = nil

    self.in_use = 0
    self.save

    self.match_data
  end
end