require 'cinch'
require 'kag/common'

module KAG
  module IRC
    class Plugin
      include Cinch::Plugin
      include KAG::Common

      match /hostname (.+)/,:method => :hostname
      def hostname(m,nick)
        if is_admin(m.user)
          user = User(nick)
          if user and !user.unknown
            reply m,"Hostname for #{nick} is #{user.host}"
          else
            reply m,"Could not find user #{nick}"
          end
        end
      end

      match /authname (.+)/,:method => :authname
      def authname(m,nick)
        if is_admin(m.user)
          user = User(nick)
          if user and !user.unknown
            reply m,"Authname for #{nick} is #{user.authname}"
          else
            reply m,"Could not find user #{nick}"
          end
        end
      end

      match /idle (.+)/,:method => :idle
      def idle(m,nick)
        if is_admin(m.user)
          user = User(nick)
          if user and !user.unknown
            s = user.idle.to_i / 60
            reply m,"#{nick} has been idle #{s} minutes"
          else
            reply m,"Could not find user #{nick}"
          end
        end
      end

      match /op (.+)/,:method => :evt_op
      def evt_op(m,nick)
        if is_admin(m.user)
          m.channel.op(nick)
        end
      end

      match /deop (.+)/,:method => :evt_deop
      def evt_deop(m,nick)
        if is_admin(m.user)
          m.channel.deop(nick)
        end
      end

      match /voice (.+)/,:method => :evt_voice
      def evt_voice(m,nick)
        if is_admin(m.user)
          m.channel.voice(nick)
        end
      end

      match /devoice (.+)/,:method => :evt_devoice
      def evt_devoice(m,nick,reason)
        if is_admin(m.user)
          m.channel.devoice(nick)
        end
      end

      match /kick (.+) (.+)/,:method => :evt_kick
      def evt_kick(m,nick,reason)
        if is_admin(m.user)
          m.channel.kick(nick,reason)
        end
      end
    end
  end
end