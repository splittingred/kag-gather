require 'kag/bot/bot'

module KAG
  class << self
    attr_accessor :bot,:gather
  end
end
KAG.bot = KAG::Bot::Bot.new

