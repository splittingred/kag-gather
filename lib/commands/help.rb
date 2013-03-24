require 'lib/commands/commands'
require 'cinch/plugin'

module Cinch
  module Commands
    #
    # Generic `!help` command that lists all commands.
    #
    class Help
      include Cinch::Plugin
      include Cinch::Commands
      set :prefix, lambda{ |m| Regexp.new("^" + Regexp.escape(m.bot.nick + ": " ))}

      command :help, {command: :string},
        summary:     %{Displays help information for the COMMAND},
        description: %{Finds the COMMAND and prints the usage and description for the COMMAND.}

      command :help, {},
        summary: "Lists available commands",
        description: %{If no COMMAND argument is given, then all commands will be listed.}

      #
      # Displays a list of commands or the help information for a specific
      # command.
      #
      # @param [Cinch::Message]
      #   The message that invoked `!help`.
      #
      # @param [String] command
      #   The specific command to list help information for.
      #
      def help(m,command=nil)
        if command
          found = commands_named(command)

          if found.empty?
            m.reply "help: Unknown command #{command.dump}"
          else
            msg = []
            # print all usages
            found.each { |cmd| msg << cmd.usage }
            # print the description of the first command
            msg = "\x0302#{msg.join(", ")}\x0314 - "+found.first.description
            m.reply msg
          end
        else
          msg = []
          each_command do |cmd|
            msg << "\x0302#{cmd.usage}\x0314: #{cmd.summary}"
          end
          m.reply msg.join " | "
        end
      end

      protected

      #
      # Enumerates over every command.
      #
      # @yield [command]
      #   The given block will be passed every command.
      #
      # @yieldparam [Command] command
      #   A command.
      #
      # @return [Enumerator]
      #   If no block is given, an Enumerator will be returned.
      #
      def each_command(&block)
        return enum_for(__method__) unless block_given?

        bot.config.plugins.plugins.each do |plugin|
          if plugin < Cinch::Commands
            plugin.commands.each(&block)
          end
        end
      end

      #
      # Finds all commands with a similar name.
      #
      # @param [String] name
      #   The name to search for.
      #
      # @return [Array<Command>]
      #   The commands with the matching name.
      #
      def commands_named(name)
        each_command.select { |command| command.name == name }
      end

    end
  end
end