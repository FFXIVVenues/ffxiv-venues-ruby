# frozen_string_literal: true

require_relative 'ident'

module FFXIVVenues

  class Ident
    ANONYMOUS_LOG_FILE_NAME = 'message_log'

    def initialize(bot, storage)
      Discordrb::LOGGER.info "Initializing command 'ident'"
      @storage = storage

      bot.register_application_command :ident, "Identify a message sent through anonymous interaction." do |interaction|
        interaction.string "message_id", "The text content of the anchored message.", required: false
      end
      bot.application_command :ident, &method(:on_command)
    end

    def on_command(event)
      map = @storage.read ANONYMOUS_LOG_FILE_NAME
      message_id = event.options["message_id"].to_i
      author_id = map[message_id]
      if author_id.nil?
        event.respond content: "Couldn't find an author for that message id.", ephemeral: true
      else
        event.respond content: "Message was authored by <@#{author_id}>.", ephemeral: true
      end
    end
  end

end