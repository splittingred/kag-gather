require 'patches'
require 'cinch'
require 'cinch/plugins/identify'
require 'kag/config'
require 'kag/data'
require 'kag/gather/plugin'
require 'kag/bans/plugin'
require 'kag/irc/plugin'
require 'kag/bot/plugin'
require 'kag/user/plugin'
require 'kag/help/plugin'
require 'kag/stats/plugin'
require 'commands/help'

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
            c.user = config[:user].to_s != "" ? config[:user] : c.nick
            c.realname = config[:realname].to_s != "" ? config[:realname] : "KAG Gatherer"
            c.messages_per_second = 2
            c.modes = %w(x)
            c.plugins.plugins = [
              Cinch::Commands::Help,
              KAG::Bot::Plugin,
              KAG::Gather::Plugin,
              KAG::Bans::Plugin,
              KAG::IRC::Plugin,
              KAG::User::Plugin,
              KAG::Help::Plugin,
              KAG::Stats::Plugin
            ]
            if config[:auth] and config[:auth][:password]
              c.plugins.plugins << Cinch::Plugins::Identify
              c.plugins.options[Cinch::Plugins::Identify] = {
                :username => config[:auth][:username],
                :password => config[:auth][:password],
                :type     => :secure_quakenet,
              }
            end
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