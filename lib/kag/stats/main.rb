module KAG
  module Stats
    class Main < Hash
      include Singleton

      def initialize(hash=nil)
        super
        self.merge!(self._load)
      end

      def _load
        unless File.exists?("data/index.json")
          return {}
        end
        f = ::IO.read("data/index.json")
        if f and !f.empty?
          SymbolTable.new(JSON.parse(f))
        else
          SymbolTable.new
        end
      end

      def reload
        puts "Reloading stats.main file..."
        self.merge!(self._load)
      end

      # Sets the value of the given +key+ to +val+.
      def store(key, val)
        super(key,val)
        self.save
      end

      def save
        File.open("data/index.json","w") do |f|
          f.write(self.to_json)
        end
      end

      def self.add_stat(stat,increment = 1)
        stat = stat.to_sym
        s = KAG::Stats::Main.instance
        s[stat] = 0 unless s[stat]
        s[stat] = s[stat].to_i + increment.to_i
        s.save
      end

      def self.subtract_stat(stat,decrement = 1)
        stat = stat.to_sym
        s = KAG::Stats::Main.instance
        if s[stat]
          s[stat] = s[stat].to_i - decrement.to_i
        else
          s[stat] = 0
        end
        s.save
      end
    end
  end
end