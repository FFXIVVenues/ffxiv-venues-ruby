# frozen_string_literal: true

class AutoThreading
  attr_accessor :channels_to_thread

  CHANNELS_TO_THREAD_FILE_NAME = 'autothreading.channels_to_thread'

  def initialize(bot, storage)
    @bot = bot
    @storage = storage
    @channels_to_thread = @storage.read CHANNELS_TO_THREAD_FILE_NAME

    @bot.register_application_command(:autothread, "Enable creating a thread on each message posted in this channel.") do | interaction|
      interaction.string "thread_name", "The name to use for all automatically created threads.", required: true
    end

    @bot.application_command(:autothread, &method(:on_command))
    @bot.message(&method(:on_message))
  end

  def on_command(command)
    Discordrb::LOGGER.info "Executing application command 'autothread'"
    channel_id = command.channel_id
    title = command.options["thread_name"]

    new_entry = @channels_to_thread[channel_id].nil?
    if new_entry
      @channels_to_thread[channel_id] = title
      command.respond content: "I'll start automatically creating threads in this channel. 🥰", ephemeral: true
    else
      @channels_to_thread.delete channel_id
      command.respond content: "Okay, I won't create threads here anymore. 🥲", ephemeral: true
    end
    save
  end

  def on_message(event)
    channel_id = event.channel.id
    title = @channels_to_thread[channel_id]
    return unless title

    event.channel.start_thread(title, 10080, message: event.message)
  end

  private

  def save
    @storage.write CHANNELS_TO_THREAD_FILE_NAME, @channels_to_thread
  end
end