# frozen_string_literal: true

module FFXIVVenues

class Honeypot
  HONEYPOT_CHANNELS_FILE_NAME = 'honeypot.channels'
  HONEYPOT_LOG_CHANNELS_FILE_NAME = 'honeypot.log_channels'

  def initialize(bot, storage)
    Discordrb::LOGGER.info "Initializing command 'honeypot'"

    @bot = bot
    @storage = storage

    @honeypot_channels = @storage.read(HONEYPOT_CHANNELS_FILE_NAME) || {}
    @log_channels = @storage.read(HONEYPOT_LOG_CHANNELS_FILE_NAME) || {}

    @bot.register_application_command :honeypot, "Toggle honeypot on this channel - any message sent here will result in a ban.", default_permission: false
    @bot.register_application_command :honeypot_log, "Toggle honeypot log reporting to this channel.", default_permission: false

    @bot.application_command :honeypot, &method(:on_honeypot_command)
    @bot.application_command :honeypot_log, &method(:on_honeypot_log_command)
    @bot.message &method(:on_message)
  end

  def on_honeypot_command(event)
    Discordrb::LOGGER.info "Executing application command 'honeypot'"

    guild_id = event.server_id
    channel_id = event.channel_id
    key = "#{guild_id}:#{channel_id}"

    if @honeypot_channels.key?(key)
      @honeypot_channels.delete(key)
      save
      event.respond content: "Honeypot deactivated for this channel.", ephemeral: true
    else
      @honeypot_channels[key] = true
      save
      event.respond content: "Honeypot activated for this channel. Any message sent here will result in a ban.", ephemeral: true
      event.channel.send_embed do |embed|
        embed.thumbnail = Discordrb::Webhooks::EmbedThumbnail.new(url: "https://github.com/FFXIVVenues/ffxiv-venues-ruby/blob/main/assets/honeypot.png?raw=true")
        embed.title = "DO NOT POST HERE"
        embed.description = "This channel is a honeypot. Any message sent here will result in an **immediate ban** from this server."
        embed.color = 0xFF0000
      end
    end
  end

  def on_honeypot_log_command(event)
    Discordrb::LOGGER.info "Executing application command 'honeypot_log'"

    guild_id = event.server_id
    channel_id = event.channel_id

    log_channels_for_guild = @log_channels[guild_id] ||= []

    if log_channels_for_guild.include?(channel_id)
      log_channels_for_guild.delete(channel_id)
      @log_channels[guild_id] = log_channels_for_guild
      save
      event.respond content: "This channel will no longer receive honeypot logs.", ephemeral: true
    else
      log_channels_for_guild << channel_id
      @log_channels[guild_id] = log_channels_for_guild
      save
      event.respond content: "This channel will now receive honeypot logs for this server.", ephemeral: true
    end
  end

  def on_message(event)
    return if event.user.id == @bot.profile.id

    guild_id = event.server&.id
    channel_id = event.channel.id
    return unless guild_id

    key = "#{guild_id}:#{channel_id}"
    return unless @honeypot_channels.key?(key)

    user = event.user
    server = event.server
    Discordrb::LOGGER.info "Honeypot triggered in channel #{channel_id} by user #{user.id}"

    begin
      server.ban(user, 1, reason: "Honeypot channel triggered.")
      server.unban(user)
      send_log(guild_id, channel_id, user, :banned)
    rescue Discordrb::Errors::NoPermission => e
      Discordrb::LOGGER.warn "Honeypot: failed to ban user #{user.id} in guild #{guild_id} - #{e.message}"
      send_log(guild_id, channel_id, user, :failed)
    end
  end

  private

  def send_log(guild_id, channel_id, user, action)
    log_channel_ids = @log_channels[guild_id]
    return if log_channel_ids.nil? || log_channel_ids.empty?

    message = case action
              when :banned
                "**Honeypot triggered** in <##{channel_id}>: <@#{user.id}> (`#{user.distinct}`) was soft banned."
              when :failed
                "**Honeypot triggered** in <##{channel_id}>: <@#{user.id}> (`#{user.distinct}`) could not be banned (likely the server owner or has higher permissions)."
              end

    log_channel_ids.each do |log_channel_id|
      begin
        @bot.channel(log_channel_id)&.send_message(message)
      rescue => e
        Discordrb::LOGGER.warn "Honeypot: failed to send log to channel #{log_channel_id} - #{e.message}"
      end
    end
  end

  def save
    @storage.write HONEYPOT_CHANNELS_FILE_NAME, @honeypot_channels
    @storage.write HONEYPOT_LOG_CHANNELS_FILE_NAME, @log_channels
  end

end

end
