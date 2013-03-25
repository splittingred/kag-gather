require 'cinch'
require 'kag/common'
require 'commands/help'

module KAG
  module IRC
    class Plugin
      include Cinch::Plugin
      include Cinch::Commands
      include KAG::Common

      command :hostname,{nick: :string},
        summary: "Get the hostname for a user",
        admin: true
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

      command :authed,{},
        summary: "Tell if you are authed"
      def authed(m)
        if m.user.authed?
          reply m,"#{m.user.nick} is authed."
        else
          reply m,"#{m.user.nick} is not yet authed. Please type !help to get help with authenticating."
        end
      end

      command :authname,{nick: :string},
        summary: "Get the AUTH name of a user",
        admin: true
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

      command :idle,{nick: :string},
        summary: "Return how long a user has been idle",
        admin: true
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

      command :op,{nick: :string},
        summary: "Op a user",
        admin: true
      def op(m,nick)
        if is_admin(m.user)
          m.channel.op(nick)
        end
      end

      command :deop,{nick: :string},
        summary: "Deop a user",
        admin: true
      def deop(m,nick)
        if is_admin(m.user)
          m.channel.deop(nick)
        end
      end

      command :voice,{nick: :string},
        summary: "Voice a user",
        admin: true
      def voice(m,nick)
        if is_admin(m.user)
          m.channel.voice(nick)
        end
      end

      command :devoice,{nick: :string,reason: :string},
        summary: "Devoice a user",
        admin: true
      def devoice(m,nick,reason = '')
        if is_admin(m.user)
          m.channel.devoice(nick)
        end
      end

      command :kick,{nick: :string,reason: :string},
        summary: "Kick a user",
        admin: true
      def kick(m,nick,reason)
        if is_admin(m.user)
          m.channel.kick(nick,reason)
        end
      end
    end
  end
end