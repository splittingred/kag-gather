require 'kag/models/model'
require 'kag/server/listener'
require 'symboltable'

class Server < KAG::Model
  has_many :matches
  has_one :match, :primary_key => 'in_use'

  attr_accessor :match_in_progress
  attr_accessor :listener,:match_data

  def self.find_unused(queue = nil)
    if queue
      votes = {}
      queue.gather_queue_players.each do |p|
        if p.server_preference
          votes[p.server_preference] = 0 unless votes[p.server_preference]
          votes[p.server_preference] += 1 if p.server_preference
        end
      end

      s = nil
      if votes.count > 0
        h = votes.max_by{|k,v| v}
        if h[0]
          region = h[0].to_s
          s = Server.where(:in_use => false,:status => 'active',:region => region).order('RAND()').first
        end
      end

      unless s
        s = Server.where(:in_use => false,:status => 'active').order('RAND()').first
      end
      s
    else
      Server.where(:in_use => false,:status => 'active').order('RAND()').first
    end
  end


  def start(mt)
    self.in_use = mt.id
    if self.save
      self.match_in_progress = mt
      self.match_data = SymbolTable.new

      puts 'setting up listener'

      self.listener = KAG::Server::Listener.new(self)
      KAG::Listener[self.name.to_sym] = self.listener

      self.listener.async.start_listening
    end
  end

  def get_match
    if self.in_use > 0
      ::Match.find(self.in_use)
    else
      false
    end
  end

  def stop
    puts 'Attempting to stop'
    unless self.listener
      puts 'attempting celluloid registry lookup'
      self.listener = KAG::Listener[self.name.to_sym]
    end
    if self.listener
      puts 'Found listener, now stopping...'
      begin
        self.listener.async.stop_listening
        puts 'Stopped, terminating thread'
      rescue Exception => e
        puts e.message
        puts e.backtrace.join("\n")
      end
    end

    self.listener = nil
    puts 'Thread terminated'
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
      self.listener.async.send(meth.to_sym,*args,&block)
    end
  end

  def say(msg)
    KAG::Listener[self.name.to_sym].async.msg(msg)
  end

  def sub_in(old_user,new_user,team)
    KAG::Listener[self.name.to_sym].async.sub_in(old_user,new_user,team)
  end
end