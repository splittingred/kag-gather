require 'kag/models/model'
require 'kag/server/listener'
require 'symboltable'

class Server < KAG::Model
  has_many :matches

  attr_accessor :match_in_progress
  attr_accessor :listener,:match_data,:bot,:gather

  def self.find_unused
    Server.where(:in_use => false).order("RAND()").first
  end


  def start(gather,match)
    self.gather = gather
    self.in_use = match.id
    if self.save
      self.match_in_progress = match
      self.match_data = SymbolTable.new

      puts "setting up listener"

      self.listener = KAG::Server::Listener.new(self)
      KAG::Listener[self.name.to_sym] = self

      self.listener.async.start_listening
    end
  end

  def match
    if self.in_use > 0
      ::Match.find(self.in_use)
    else
      false
    end
  end

  def stop
    puts "Attempting to stop"
    unless self.listener
      puts "attempting celluloid registry lookup"
      self.listener = KAG::Listener[self.name.to_sym]
    end
    if self.listener
      begin
        self.listener.stop_listening
      rescue Exception => e
        puts e.message
        puts e.backtrace.join("\n")
      end
    end

    puts "Stopped, terminating thread"
    puts "Thread terminated"
    self.listener = nil
    self.match_in_progress = nil

    self.in_use = 0
    self.save

    self.match_data
  end

  def text_join
    "Join \x0305#{self.name} - #{self.ip}:#{self.port} \x0306password #{self.password}\x0301 | Visit kag://#{self.ip}/#{self.password}"
  end

  def has_rcon?
    self.rcon_password and !self.rcon_password.empty?
  end

  def method_missing(meth, *args, &block)
    if self.listener and self.listener.respond_to?(meth.to_sym)
    self.listener.async.send(:meth,*args,&block)
    end
  end
end