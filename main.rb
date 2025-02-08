# frozen_string_literal: true

require 'discordrb'
require 'dotenv'
require_relative 'debouncer'
require_relative 'random'
require_relative 'anchoring'
require_relative 'auto_threading'
require_relative 'storage'
require_relative 'minesweep'

Dotenv.load ".env"

@discord_token = ENV['DISCORD_TOKEN']
@discord_client_id = ENV['DISCORD_CLIENT_ID']
@storage_path = ENV['STORAGE_PATH'] || ".data/"

if @discord_client_id.nil? || @discord_client_id.strip.empty?
  Discordrb::LOGGER.error "No discord client id provided, populate the 'DISCORD_CLIENT_ID' environment variable with a client id."
  exit 1
end

if @discord_token.nil? || @discord_token.strip.empty?
  Discordrb::LOGGER.error "No discord token provided, populate the 'DISCORD_TOKEN' environment variable with a token."
  exit 2
end

bot = Discordrb::Bot.new(
  token: @discord_token,
  client_id: @discord_client_id,
  fancy_log: true,
  intents: [ :server_messages ])
storage = Storage.new @storage_path
debouncer = Debouncer.new

FFXIVVenues::Anchoring.new bot, debouncer, storage
FFXIVVenues::AutoThreading.new bot, storage
FFXIVVenues::Random.new bot
FFXIVVenues::Minesweep.new bot

bot.ready do
  Discordrb::LOGGER.info "Ruby is online!"
end

at_exit { bot.stop }

bot.run