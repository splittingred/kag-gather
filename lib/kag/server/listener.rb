require 'symboltable'
require 'json'
require 'kag/config'
require 'socket'

module KAG
  module Server
    class Listener
      attr_accessor :server, :data
      def initialize(server)
        self.server = server
        self.start
      end

      def start
        puts "Hai"
        data[:test] = 1
      end
    end
  end
end