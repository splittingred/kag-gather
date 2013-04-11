require 'patches'
require 'cinch'
require 'cinch/plugins/identify'
require 'celluloid'
require 'kag/config'
require 'kag/database'
require 'kag/registry'
require 'kag/models/model'
Dir.glob('lib/kag/models/*.rb').each {|f| load f.to_s }
Dir.glob('lib/kag/plugins/*.rb').each {|f| load f.to_s }
require 'commands/help'

module KAG
  class << self
    attr_accessor :bot,:gather
  end

  module Bot
    class Bot
      attr_accessor :bot

      def initialize
        config = self.config
        self.bot = Cinch::Bot.new do
          configure do |c|
            c.server = config[:server]
            c.channels = config[:channels]
            c.port = config[:port].to_i > 0 ? config[:port] : 6667
            #c.ssl = config[:ssl]
            c.nick = config[:nick].to_s != "" ? config[:nick] : "KAGatherer"
            c.user = config[:user].to_s != "" ? config[:user] : c.nick
            c.realname = config[:realname].to_s != "" ? config[:realname] : "KAG Gatherer"
            c.messages_per_second = (config[:messages_per_second] or 2)
            c.modes = %w(x)
            c.plugins.plugins = [
              Cinch::Commands::Help,
              KAG::Bot::Plugin,
              KAG::Gather::Plugin,
              KAG::Ignore::Plugin,
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
        self.bot.start
      end

      def config
        KAG::Config.instance
      end
    end
  end
end