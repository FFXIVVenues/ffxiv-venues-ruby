# frozen_string_literal: true

class Anchoring
  attr_accessor :channels_to_anchor, :previous_anchors

  CHANNELS_TO_ANCHOR_FILE_NAME = 'anchoring.channels_to_anchor'
  PREVIOUS_ANCHORS_FILE_NAME = 'anchoring.previous_anchors'

  def initialize(bot, debouncer, storage)
    @bot = bot
    @debouncer = debouncer
    @storage = storage

    @channels_to_anchor = @storage.read CHANNELS_TO_ANCHOR_FILE_NAME
    @previous_anchors = @storage.read PREVIOUS_ANCHORS_FILE_NAME

    @bot.register_application_command :anchor, "Enable anchoring a notice to the bottom of this channel.", default_permission: false do |interaction|
      interaction.string "anchor_content", "The text content of the anchored message.", required: false
    end

    @bot.application_command :anchor, &method(:on_command)
    @bot.modal_submit &method(:on_modal_submit)
    @bot.message &method(:on_message)
  end

  def on_command(event)
    Discordrb::LOGGER.info "Executing application command 'anchor'"

    channel_id = event.channel_id
    is_new_entry = @channels_to_anchor[channel_id].nil?
    unless is_new_entry
      @channels_to_anchor.delete channel_id
      event.respond content: "Okay, I won't anchor that message anymore. 🥲", ephemeral: true
      save
      return
    end

    content = event.options["anchor_content"]

    if content.nil? || content.strip.empty?
      event.show_modal title:'Enter Anchored Message',
                         custom_id:'anchor_modal' do |modal|
        modal.row do |row|
          row.text_input style: :paragraph,
                         custom_id: 'anchor_content',
                         label: 'Anchored Message',
                         required: true
        end
      end
      return
    end

    @channels_to_anchor[channel_id] = content
    event.respond content: "Oki, I'll anchor that message here! 🥰", ephemeral: true
    save
  end

  def on_modal_submit(event)
    return unless event.custom_id == 'anchor_modal'

    Discordrb::LOGGER.info "Processing anchor modal submission"

    channel_id = event.channel_id
    content = event.value 'anchor_content'

    @channels_to_anchor[channel_id] = content
    event.respond content: "Oki, I'll anchor that message here! 🥰", ephemeral: true
    save
  end

  def on_message(event)
    channel_id = event.channel.id
    content = channels_to_anchor[channel_id]
    return unless content

    Discordrb::LOGGER.info "Message received on anchored channel #{channel_id}"

    @debouncer.debounce("anchor_" + channel_id.to_s, 30) do
      Discordrb::LOGGER.info "Anchoring message in channel #{channel_id}"

      previous_anchor_id = @previous_anchors[channel_id]
      unless previous_anchor_id.nil?
        previous_anchor = event.channel.load_message(previous_anchor_id)
        event.channel.delete_message(previous_anchor) unless previous_anchor.nil?
      end

      message = event.channel.send_embed do |embed|
        embed.description = content
      end
      @previous_anchors[channel_id] = message.id

      save

    end
  end

  private

  def save
    @storage.write PREVIOUS_ANCHORS_FILE_NAME, @previous_anchors
    @storage.write CHANNELS_TO_ANCHOR_FILE_NAME, @channels_to_anchor
  end

end