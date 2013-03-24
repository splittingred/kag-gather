require 'patches'
require 'cinch'
require 'kag/config'
require 'kag/data'
require 'kag/gather/plugin'
require 'kag/bans/plugin'
require 'kag/irc/plugin'
require 'kag/bot/plugin'

module KAG
  module Bot
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
            c.server_queue_size = 1
            c.plugins.plugins = [KAG::Bot::Plugin,KAG::Gather::Plugin,KAG::Bans::Plugin,KAG::IRC::Plugin]
            if config[:sasl]
              c.sasl.username = config[:sasl][:username]
              c.sasl.password = config[:sasl][:password]
            end
          end
        end

        bot.start
      end

      def config
        KAG::Config.instance
      end
    end
  end
end