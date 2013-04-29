require 'commands/command'
require 'kag/common'

module Cinch
  module Commands

    def self.included(base)
      base.extend ClassMethods
    end

    module ClassMethods
      #
      # All registered commands.
      #
      # @return [Array<Command>]
      #   The registered commands.
      #
      # @api semipublic
      #
      def commands
        @commands ||= []
      end

      protected

      #
      # Registers a command.
      #
      # @param [Symbol] name
      #
      # @param [Hash{Symbol => Symbol,Regexp}] arguments
      #
      # @param [Hash] options
      #   Additional options.
      #
      # @option options [String] :summary
      #   The short summary for the command.
      #
      # @option options [String] :description
      #   The long description for the command.
      #
      # @return [Command]
      #   The new command.
      #
      # @example
      #   command :grant, {name: :string, :level: :integer},
      #                   summary: "Grants access",
      #                   description: %{
      #                     Grants a certain level of access to the user
      #                   }
      #
      def command(name,arguments={},options={})
        new_command = Command.new(name,arguments,options)

        m = options.key?(:method) ? options[:method] : name
        r = new_command.custom_regexp.nil? ? new_command.regexp : new_command.custom_regexp
        match(r, method: m)

        commands << new_command
        new_command
      end
    end

  end
end