require 'symboltable'
require 'kag/config'

module KAG
  class Match < SymbolTable

    def self.type_as_string
      ms = KAG::Config.instance[:match_size].to_i
      ts = (ms / 2).ceil
      "#{ts.to_s}v#{ts.to_s} #{KAG::Config.instance[:match_type]}"
    end

    def initialize(hash = nil)
      self[:end_votes] = 0 unless hash[:end_votes]
      super(hash)
    end

    def add_end_vote
      self[:end_votes] = 0 unless self[:end_votes] > 0
      self[:end_votes] = self[:end_votes] + 1
    end

    def voted_to_end?
      evt = KAG::Config.instance[:end_vote_threshold].to_i
      evt = 3 if evt < 1
      self[:end_votes] >= evt
    end

    def get_needed_end_votes_left
      evt = KAG::Config.instance[:end_vote_threshold].to_i
      evt - self[:end_votes]
    end

    def has_player?(nick)
      if self[:team1] and self[:team1].include?(nick)
        true
      elsif self[:team2] and self[:team2].include?(nick)
        true
      else
        false
      end
    end

    def cease
      if self.server
        if self.server.has_rcon?
          begin
            self[:team1].each do |p|
              self.server.kick(p)
            end
            self[:team2].each do |p|
              self.server.kick(p)
            end
          rescue Exception => e
            debug e.message
            debug e.backtrace.join("\n")
          end
        else
          debug "NO RCON, so could not kick!"
        end
        self.server.disconnect
        self.server.delete(:match)
        true
      else
        debug "No server for match defined!"
        false
      end
    end

    def restart_map
      if self.server.has_rcon?
        self.server.restart_map
      else
        debug "Cannot restart map, no RCON defined"
      end
    end

    def remove_player
      if match.server
        match.server.kick(nick)
      end
    end

    def rename_player(last_nick,new_nick)
      i = self[:team1].index(last_nick)
      if i != nil
        self[:team1].delete_at(i)
        self[:team1] << new_nick
      end
      i = self[:team2].index(last_nick)
      if i != nil
        self[:team2].delete_at(i)
        self[:team2] << new_nick
      end
    end

    def debug(msg)
      if KAG::Config.instance[:debug]
        puts msg
      end
    end
  end
end