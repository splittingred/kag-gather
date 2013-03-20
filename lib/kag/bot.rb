require 'cinch'
require 'kag/config'
require 'kag/gather'

module KAG
  class Bot
    def initialize
      config = self.config
      bot = Cinch::Bot.new do
        configure do |c|
          c.server = config[:server]
          c.channels = config[:channels]
          c.port = config[:port].to_i > 0 ? config[:port] : 6667
          #c.ssl = config[:ssl]
          c.nick = config[:nick].to_s != "" ? config[:nick] : "KAGatherer"
          c.realname = config[:realname].to_s != "" ? config[:realname] : "KAG Gatherer"
          c.messages_per_second = 1
          c.plugins.plugins = [KAG::Gather]
        end
      end

      bot.start
    end

    def config
      KAG::Config.instance
    end
  end
end