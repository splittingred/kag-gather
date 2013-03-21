require 'cinch'
require 'cinch/user'
require 'symboltable'
require 'kag/config'

module KAG
  class Team < SymbolTable

    def setup
      setup_classes
      puts self[:players].inspect
      self
    end

    def setup_classes
      classes = KAG::Config.instance[:classes].clone
      classes.shuffle!
      players = self[:players].clone
      self[:players] = {}
      players.each do |p|
        self[:players][p.to_sym] = classes.shift
      end
    end

    def notify_of_match_start
      server = self.match.server
      msg = "Join \x0305#{server[:key]} - #{server[:ip]}:#{server[:port]} \x0306password #{server[:password]}\x0301 | Visit kag://#{server[:ip]}/#{server[:password]} | "
      msg = msg + " \x0303Class: " if KAG::Config.instance[:pick_classes]

      messages = {}
      self[:players].each do |nick,cls|
        player_msg = msg.clone
        player_msg = player_msg+cls if KAG::Config.instance[:pick_classes] and cls and !cls.empty?
        player_msg = player_msg+" \x0312Blue Team with: #{self[:players].keys.join(", ")}"
        messages[nick] = player_msg
      end
      messages
    end

    def text_for_match_start
      "#{self[:color]}#{self[:players].keys.join(", ")} (#{self[:name]})"
    end

    def has_player?(nick)
      self[:players].keys.include?(nick.to_sym)
    end

    def rename_player(last_nick,new_nick)
      if has_player?(nick)
        cls = self[:players][last_nick.to_sym]
        self[:players].delete(last_nick.to_sym)
        self[:players][new_nick.to_sym] = cls
      end
    end

    def kick_all
      self[:players].each do |nick,cls|
        self.match.server.kick(nick.to_s)
      end
    end
  end
end