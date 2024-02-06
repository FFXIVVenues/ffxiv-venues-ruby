# frozen_string_literal: true

require 'discordrb'
require 'dotenv'

Dotenv.load ".env"
Dotenv.overload ".env.local"

@discord_token = ENV['DISCORD_TOKEN']
@discord_client_id = ENV['DISCORD_CLIENT_ID']

channels = {}

bot = Discordrb::Bot.new(
  token: @discord_token,
  client_id: @discord_client_id, fancy_log: true,
  intents: [ :server_messages ])


# AutoThreading
bot.register_application_command :autothread,
                             "Enabled creating a thread on each message posted in this channel." do
  |interaction|
  interaction.string "thread_name", "The name to use for all automatically created threads.", required: true
end

bot.application_command :autothread do
  |command|
  Discordrb::LOGGER.info "Executing application command 'autothread' executing"
  channel_id = command.channel_id
  title = command.options["thread_name"]
  new = channels[channel_id].nil?
  if new
    channels[channel_id] = title
    command.respond content: "I'll start automatically creating threads in this channel. 🥰", ephemeral: true
  else
    channels.delete channel_id
    command.respond content: "Okay, I won't create threads here anymore. 🥲", ephemeral: true
  end
end

bot.message do |event|
  channel_id = event.channel.id
  title = channels[channel_id]
  return unless title

  event.channel.start_thread title, 10080, message: event.message
end
# End AutoThreading





# Begin Anchoring
bot.register_application_command :anchor, "Enable anchoring a notice to the bottom of this channel." do
  |interaction|
  interaction.string "anchor_content", "The text content of the anchored message."
end

bot.application_command :anchor do
  |command|
  content = command.options["anchor_content"]
  embed = Discordrb::Webhooks::Embed.new(description: content)
  command.respond embed:{ anchored: embed }
end
# End Pinning





bot.ready do
  Discordrb::LOGGER.info "Ruby is online!"
end

at_exit { bot.stop }

bot.run


