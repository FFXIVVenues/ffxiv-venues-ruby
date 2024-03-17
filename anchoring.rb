# frozen_string_literal: true

class Anchoring
  attr_accessor :channels_to_anchor, :previous_anchors

  def initialize(bot, debouncer)
    @bot = bot
    @debouncer = debouncer
    @channels_to_anchor = {}
    @previous_anchors = {}

    @bot.register_application_command :anchor, "Enable anchoring a notice to the bottom of this channel." do |interaction|
      interaction.string "anchor_content", "The text content of the anchored message.", required: true
    end

    @bot.application_command :anchor, &method(:on_command)
    @bot.message &method(:on_message)
  end

  def on_command(command)
    Discordrb::LOGGER.info "Executing application command 'anchor'"
    channel_id = command.channel_id
    content = command.options["anchor_content"]

    new_entry = @channels_to_anchor[channel_id].nil?
    if new_entry
      @channels_to_anchor[channel_id] = content
      command.respond content: "Oki, I'll anchor that message here! 🥰", ephemeral: true
    else
      @channels_to_anchor.delete channel_id
      command.respond content: "Okay, I won't anchor that message anymore. 🥲", ephemeral: true
    end

  end

  def on_message(event)
    channel_id = event.channel.id
    content = channels_to_anchor[channel_id]
    return unless content

    @debouncer.debounce("anchor_" + channel_id.to_s, 5) do
      previous_anchor_id = @previous_anchors[channel_id]
      unless previous_anchor_id.nil?
        previous_anchor = event.channel.load_message(previous_anchor_id)
        event.channel.delete_message(previous_anchor)
      end

      message = event.channel.send_embed do |embed|
        embed.description = content
      end
      @previous_anchors[channel_id] = message.id
    end
  end

end