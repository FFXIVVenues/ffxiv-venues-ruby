# frozen_string_literal: true

require 'discordrb'
require 'dotenv'

Dotenv.load ".env"
Dotenv.overload ".env.local"

@discord_token = ENV['DISCORD_TOKEN']
@discord_client_id = ENV['DISCORD_CLIENT_ID']


bot = Discordrb::Bot.new(
  token: @discord_token,
  client_id: @discord_client_id, fancy_log: true,
  intents: [ :server_messages ])


# AutoThreading
channels_to_thread = {}

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
  new = channels_to_thread[channel_id].nil?
  if new
    channels_to_thread[channel_id] = title
    command.respond content: "I'll start automatically creating threads in this channel. 🥰", ephemeral: true
  else
    channels_to_thread.delete channel_id
    command.respond content: "Okay, I won't create threads here anymore. 🥲", ephemeral: true
  end
end

bot.message do |event|
  channel_id = event.channel.id
  title = channels_to_thread[channel_id]
  return unless title

  event.channel.start_thread title, 10080, message: event.message
end
# End AutoThreading



# Begin Pinning
channels_to_anchor={}
previous_anchors={}

bot.register_application_command :anchor, "Enable anchoring a notice to the bottom of this channel." do
  |interaction|
  interaction.string "anchor_content", "The text content of the anchored message."
end

bot.application_command :anchor do
  Discordrb::LOGGER.info "Executing application command 'anchor' executing"
  channel_id = command.channel_id
  content = command.options["anchor_content"]
  new = channels_to_anchor[channel_id].nil?
  if new
    channels_to_anchor[channel_id] = content
    command.respond content: "Oki, I'll anchor that message here! 🥰", ephemeral: true
  else
    channels_to_anchor.delete channel_id
    command.respond content: "Okay, I won't anchor that message anymore. 🥲", ephemeral: true
  end
end

bot.message do |event|
  channel_id = event.channel.id
  content = channels_to_anchor[channel_id]
  return unless content

  previous_anchor_id = previous_anchors[channel_id]
  unless previous_anchor_id.nil?
    previous_anchor = event.channel.get_message previous_anchor_id
    event.channel.delete_message previous_anchor

  event.channel.send_message "", embed: {}
end
# End Pinning



bot.ready do
  Discordrb::LOGGER.info "Ruby is online!"
end

at_exit { bot.stop }

bot.run


