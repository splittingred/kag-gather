require 'cinch'
require File.dirname(__FILE__)+'/gather/config'

module KAG
  module Gather
    class Bot
      def initialize
        bot = Cinch::Bot.new do
          configure do |c|
            c.server = self.config[:server]
            c.channels = self.config[:channels]
          end

          on :message, "hello" do |m|
            m.reply "Hello, #{m.user.nick}"
          end
        end

        bot.start
      end

      def config
        KAG::Gather::Config.instance
      end
    end
  end
end