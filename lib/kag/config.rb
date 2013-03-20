require 'singleton'
require 'symboltable'
require 'json'

module KAG
  class Config < SymbolTable
    include Singleton

    def initialize
      super
      self.merge!(self._get_config)
    end

    def _get_config
      if File.exists?("config/config.json")
        SymbolTable.new(JSON.parse(::IO.read("config/config.json")))
      else
        raise 'Error loading config file from config/config.json'
      end
    end

    def reload
      puts "Reloading configuration file..."
      self.merge!(self._get_config)
    end
  end
end