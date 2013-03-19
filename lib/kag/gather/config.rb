require 'singleton'
require 'symboltable'

module KAG
  module Gather
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
    end
  end
end