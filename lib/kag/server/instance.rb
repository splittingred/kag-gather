require 'cinch'
require 'symboltable'
require 'json'
require 'kagerator'
require 'kag/config'
require 'kag/server/listener'
require 'socket'
require 'celluloid'

module KAG
  module Server
    class Instance
      attr_accessor :parser,:listener,:bot,:match,:data
      attr_accessor :key,:ip,:port,:password,:rcon_password

      def initialize(bot,key,config)
        self.bot = bot
        self.key = key
        self.ip = config[:ip]
        self.port = config[:port]
        self.password = config[:password]
        self.rcon_password = config[:rcon_password]
      end

      def self.fetch_all(bot)
        servers = {}
        KAG::Config.instance[:servers].each do |k,s|
          servers[k] = KAG::Server::Instance.new(bot,k,s)
        end
        servers
      end

      def start(match)
        self.match = match
        self.data = SymbolTable.new
        self.listener = KAG::Server::Listener.new(self,self.data)
        self.listener.async.start_listening
      end

      def stop
        puts "Attempting to stop"
        puts self.listener.tasks.inspect
        begin
          v = self.listener.future.stop_listening
          #puts data.inspect
        rescue Exception => e
          puts e.message
          puts e.backtrace.join("\n")
        end
        puts "get future"
        self.data = v.value

        puts "Stopped, terminating thread"
        #self.listener.socket.close
        self.listener.terminate
        puts "Thread terminated"
        self.listener = nil
        puts "Listener nilled"
        self.match = nil
        puts "Match nilled, now returning"
        self.data
      end

      def method_missing(meth, *args, &block)
        if self.listener and self.listener.respond_to?(meth.to_sym)
        self.listener.async.send(:meth,*args,&block)
        end
      end

      def info
        Kagerator.server(self.ip,self.port)
      end

      def in_use?
        !self.match.nil?
      end

      def has_rcon?
        self.rcon_password and !self.rcon_password.empty?
      end


      def text_join
        "Join \x0305#{self.key} - #{self.ip}:#{self.port} \x0306password #{self.password}\x0301 | Visit kag://#{self.ip}/#{self.password}"
      end


    end
  end
end