module KAG
  module Help
    class Book < Hash
      include Singleton

      def initialize(hash=nil)
        super
        self.merge!(self._load)
      end

      def _load
        unless File.exists?("config/help.json")
          File.open("config/help.json","w") {|f| f.write("{}") }
        end
        f = ::IO.read("config/help.json")
        if f and !f.empty?
          SymbolTable.new(JSON.parse(f))
        else
          SymbolTable.new
        end
      end

      def reload
        puts "Reloading help file..."
        self.merge!(self._load)
      end

      # Sets the value of the given +key+ to +val+.
      def store(key, val)
        super(key,val)
        self.save
      end

      def save
        File.open("config/help.json","w") do |f|
          f.write(self.to_json)
        end
      end
    end
  end
end