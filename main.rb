# frozen_string_literal: true

require 'discordrb'
require 'dotenv'
require 'time'
require_relative 'debouncer'
require_relative 'anchoring'
require_relative 'auto_threading'
require_relative 'storage'

Dotenv.load ".env"
Dotenv.overload ".env.local"

@discord_token = ENV['DISCORD_TOKEN']
@discord_client_id = ENV['DISCORD_CLIENT_ID']
@storage_path = ENV['STORAGE_PATH']

bot = Discordrb::Bot.new(
  token: @discord_token,
  client_id: @discord_client_id, fancy_log: true,
  intents: [ :server_messages ])
storage = Storage.new @storage_path
debouncer = Debouncer.new

Anchoring.new bot, debouncer, storage
AutoThreading.new bot, storage

bot.ready do
  Discordrb::LOGGER.info "Ruby is online!"
end

at_exit { bot.stop }

bot.run


