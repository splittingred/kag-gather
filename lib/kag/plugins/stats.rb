require 'cinch'
require 'kag/common'
require 'commands/help'
require 'kag/user/user'
require 'kag/stats/main'

module KAG
  module Stats
    class Plugin
      include Cinch::Plugin
      include Cinch::Commands
      include KAG::Common
      hook :pre,method: :auth

      command :stats,{},
        summary: 'Get the gather-wide stats'
      def stats(m)
        reply m,KAG::Stats::Main.instance.collect { |k,v| "#{k}: #{v}" }.join(", ")
      end

      command :stats,{name: :string},
        summary: 'Get the stats for a user',
        method: :stats_specific
      def stats_specific(m,name)
        unless is_banned?(m.user)
          u = ::User.fetch(name)
          if u
            m.user.send u.stats_text
          else
            reply m,"User #{name} has not played any matches, and therefore is not in the stats table."
          end
        end
      end

      command :win_leaders,{},
        summary: 'Get top 10 winning leaders'
      def win_leaders(m)
        unless is_banned?(m.user)
          users = ::User.select('users.*,user_stats.value AS value').joins(:user_stats).where(:user_stats => {:name => 'wins'}).order('user_stats.value DESC').limit(10)
          list = []
          users.each do |u|
            list << "#{u.name}: #{u.value.to_s}"
          end
          reply m, 'TOP 10 Winners: '+list.join(', ')
        end
      end

      command :rank,{},
        summary: 'Get your rank.'
      def rank(m)
        unless is_banned?(m.user)
          u = ::User.fetch(m.user)
          if u
            m.user.send "#{u.name} is ranked ##{u.rank}"
          end
        end
      end

      command :rank,{name: :string},
        summary: 'Get your rank.',
        method: :rank_specific
      def rank_specific(m,name)
        unless is_banned?(m.user)
          u = ::User.fetch(name)
          if u
            m.user.send "#{u.name} is ranked ##{u.rank}"
          end
        end
      end

      command :top10,{},
        summary: 'Get the top 10'
      def top10(m)
        unless is_banned?(m.user)
          users = ::User.rank_top(10)
          list = []
          idx = 1
          users.each do |u|
            list << "##{idx}: #{u.name} - #{u.score.to_s}"
            idx += 1
          end
          reply m,"TOP 10: #{list.join(', ')}"
        end
      end
    end
  end
end