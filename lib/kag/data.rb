require 'singleton'
require 'symboltable'
require 'json'

module KAG
  class Data < Hash
    def initialize(hash=nil)
      super
      self.merge!(self._load)
    end

    def _load
      unless File.exists?("config/data.json")
        File.open("config/data.json","w") {|f| f.write("{}") }
      end
      f = ::IO.read("config/data.json")
      if f and !f.empty?
        SymbolTable.new(JSON.parse(f))
      else
        SymbolTable.new
      end
    end

    def reload
      puts "Reloading data file..."
      self.merge!(self._load)
    end

    # Sets the value of the given +key+ to +val+.
    def store(key, val)
      super(key,val)
      self.save
    end

    def save
      File.open("config/data.json","w") do |f|
        f.write(self.to_json)
      end
    end
  end
end