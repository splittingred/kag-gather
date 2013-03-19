require 'cinch'
require File.dirname(__FILE__)+'/config'

module KAG
  class Server
    attr_accessor :config
    def initialize(server)
      self.config = server
    end
  end
end