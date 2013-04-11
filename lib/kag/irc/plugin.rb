require 'cinch'
require 'kag/common'
require 'commands/help'

module KAG
  module IRC
    class Plugin
      include Cinch::Plugin
      include Cinch::Commands
      include KAG::Common
      hook :pre,method: :auth

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

      command :refresh,{},
        summary: "Refresh your AUTH status",
        method: :refresh,
        admin: true
      def refresh(m)
        m.user.refresh
        m.reply "#{m.user.nick} refreshed as #{m.user.authname}."
      end

      command :refresh,{nick: :string},
        summary: "Refresh the status of a user",
        method: :refresh_specific,
        admin: true
      def refresh_specific(m,nick)
        if is_admin(m.user)
          u = User(nick)
          if u
            u.refresh
            m.reply "#{u.nick} refreshed as #{u.authname}."
          end
        end
      end

      command :authed,{},
        summary: "Tell if you are authed"
      def authed(m)
        m.user.refresh
        if m.user.authed?
          reply m,"#{m.user.nick} is authed."
        else
          reply m,"#{m.user.nick} is not yet authed. Please type !help to get help with authenticating."
        end
      end

      command :authname,
        summary: "Get the your authname"
      def authname(m)
        if is_admin(m.user)
          m.user.refresh
          reply m,"Authname for #{m.user.nick} is #{m.user.authname}"
        end
      end

      command :authname,{nick: :string},
        summary: "Get the AUTH name of a user",
        admin: true,
        method: :authname_specific
      def authname_specific(m,nick)
        if is_admin(m.user)
          user = User(nick)
          user.refresh
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
          user.refresh
          if user and !user.unknown
            s = user.idle.to_i / 60
            reply m,"#{nick} has been idle #{s} minutes"
          else
            reply m,"Could not find user #{nick}"
          end
        end
      end

      command :op,{nick: :string,channel: :string},
        summary: "Op a user",
        admin: true
      def op(m,nick,channel = nil)
        if is_admin(m.user)
          if channel
            c = Channel(channel)
            c.op(nick) if c
          else
            m.channel.op(nick)
          end
        end
      end

      command :deop,{nick: :string,channel: :string},
        summary: "Deop a user",
        admin: true
      def deop(m,nick,channel = nil)
        if is_admin(m.user)
          if channel
            c = Channel(channel)
            c.deop(nick) if c
          else
            m.channel.deop(nick)
          end
        end
      end

      command :voice,{nick: :string,channel: :string},
        summary: "Voice a user",
        admin: true
      def voice(m,nick,channel = nil)
        if is_admin(m.user)
          if channel
            c = Channel(channel)
            c.voice(nick) if c
          else
            m.channel.voice(nick)
          end
        end
      end

      command :devoice,{nick: :string,channel: :string},
        summary: "Devoice a user",
        admin: true
      def devoice(m,nick,channel = nil)
        if is_admin(m.user)
          if channel
            c = Channel(channel)
            c.devoice(nick) if c
          else
            m.channel.devoice(nick)
          end
        end
      end

      command :kick,{nick: :string,reason: :string,channel: :string},
        summary: "Kick a user",
        admin: true
      def kick(m,nick,reason = "",channel = nil)
        if is_admin(m.user)
          if channel
            c = Channel(channel)
            c.kick(nick,reason) if c
          else
            m.channel.kick(nick,reason)
          end
        end
      end
    end
  end
end