# frozen_string_literal: true
require_relative 'ident'

module FFXIVVenues

class Anonymise
  attr_accessor :channels_to_anonymise, :previous_anchors

  CHANNELS_FOR_ANONYMITY_FILE_NAME = 'anonymous.channels_to_anon'
  PREVIOUS_ANCHORS_FILE_NAME = 'anonymous.previous_anchors'
  ANOMYMOUS_NAMES = [
    "Abyssinian Cat", "American Bobtail Cat", "American Curl Cat", "American Shorthair Cat", "American Wirehair Cat", "Balinese Cat", "Bengal Cat", "Birman Cat", "Bombay Cat", "British Shorthair Cat",
    "Burmese Cat", "Burmilla Cat", "Chartreux Cat", "Chausie Cat", "Cornish Rex Cat", "Cymric Cat", "Devon Rex Cat", "Egyptian Mau Cat", "European Burmese Cat", "Exotic Shorthair Cat",
    "Havana Brown Cat", "Himalayan Cat", "Japanese Bobtail Cat", "Javanese Cat", "Khao Manee Cat", "Korat Cat", "Kurilian Bobtail Cat", "LaPerm Cat", "Lykoi Cat", "Maine Coon Cat",
    "Manx Cat", "Munchkin Cat", "Nebelung Cat", "Norwegian Forest Cat", "Ocicat Cat", "Oriental Cat", "Persian Cat", "Peterbald Cat", "Pixie-bob Cat", "Ragamuffin Cat",
    "Ragdoll Cat", "Russian Blue Cat", "Savannah Cat", "Scottish Fold Cat", "Selkirk Rex Cat", "Siamese Cat", "Siberian Cat", "Singapura Cat", "Snowshoe Cat", "Somali Cat",
    "Sphynx Cat", "Tonkinese Cat", "Toyger Cat", "Turkish Angora Cat", "Turkish Van Cat", "York Chocolate Cat", "Aegean Cat", "Asian Cat", "Australian Mist Cat", "Bambino Cat",
    "Burmilla Cat", "California Spangled Cat", "Chantilly-Tiffany Cat", "Colorpoint Shorthair Cat", "Cheetoh Cat", "Donskoy Cat", "Dragon Li Cat", "Dwelf Cat", "Foldex Cat", "German Rex Cat",
    "Highlander Cat", "Jungle Curl Cat", "Kanaani Cat", "Kinkalow Cat", "Korat Cat", "Lambkin Cat", "Minskin Cat", "Napoleon Cat", "Ojos Azules Cat", "Oriental Bicolor Cat",
    "Oriental Longhair Cat", "Oriental Shorthair Cat", "Raas Cat", "Ragdoll Cat", "Russian White Cat", "Sam Sawet Cat", "Savannah Cat", "Scottish Fold Cat", "Selkirk Rex Cat", "Serengeti Cat",
    "Sokoke Cat", "Suphalak Cat", "Thai Cat", "Thai Lilac Cat", "Tonkinese Cat", "Toyger Cat", "Turkish Angora Cat", "Turkish Van Cat", "Ukrainian Levkoy Cat", "York Chocolate Cat"
  ]

  def initialize(bot, debouncer, storage)
    FFXIVVenues::Ident.new bot, storage

    Discordrb::LOGGER.info "Initializing command 'anonymise'"

    @bot = bot
    @debouncer = debouncer
    @storage = storage
    @name_seed = rand(0..ANOMYMOUS_NAMES.length)

    @channels_to_anonymise = @storage.read CHANNELS_FOR_ANONYMITY_FILE_NAME
    @previous_anchors = @storage.read PREVIOUS_ANCHORS_FILE_NAME

    @bot.register_application_command :anonymise, "Enable anonymous interactions in this channel.", default_permission: false do |interaction|
      interaction.string "anchor_content", "The text content of the anchored message.", required: false
    end

    @bot.application_command :anonymise, &method(:on_command)
    @bot.modal_submit &method(:on_setup_modal_submit)
    @bot.modal_submit &method(:on_message_modal_submit)
    @bot.button &method(:on_anon_message_click)
    @bot.button &method(:on_anon_reply_click)
    @bot.message &method(:on_message)
  end

  def on_command(event)
    Discordrb::LOGGER.info "Executing application command 'anonymise'"

    channel_id = event.channel_id
    is_new_entry = @channels_to_anonymise[channel_id].nil?
    unless is_new_entry
      event.respond content: "Okay, we'll stop anonymous messages here. 🥲", ephemeral: true
      previous_anchor_id = @previous_anchors[channel_id]
      unless previous_anchor_id.nil?
        previous_anchor = event.channel.load_message(previous_anchor_id)
        event.channel.delete_message(previous_anchor) unless previous_anchor.nil?
      end
      @channels_to_anonymise.delete channel_id
      save
      return
    end

    content = event.options["anchor_content"]

    if content.nil? || content.strip.empty?
      event.show_modal title:'Anchored Message',
                         custom_id:'anonymous_setup_modal' do |modal|
        modal.row do |row|
          row.text_input style: :paragraph,
                         custom_id: 'anchor_content',
                         label: 'Anchored Message',
                         value: content,
                         required: true
        end
      end
      return
    end

    @channels_to_anonymise[channel_id] = content
    event.respond content: "Oki, I'll provide anonymity in this channel! 🥰", ephemeral: true
    save

    @debouncer.debounce("anonymise_" + channel_id.to_s, 2) do
      send_anchor_message(content, event.channel)
    end
  end

  def on_setup_modal_submit(event)
    return unless event.custom_id == 'anonymous_setup_modal'

    Discordrb::LOGGER.info "Processing 'anonymise' modal submission"

    channel_id = event.channel_id
    content = event.value 'anchor_content'

    @channels_to_anonymise[channel_id] = content
    event.respond content: "Oki, I'll proide anonymity in this channel! 🥰", ephemeral: true
    save

    @debouncer.debounce("anchor_" + channel_id.to_s, 2) do
      send_anchor_message(content, event.channel)
    end
  end

  def on_message_modal_submit(event)
    return unless event.custom_id.start_with?('anonymous_message_modal')
    reply_message_id = event.custom_id.split(':', 2)[1]
    reply_message = nil
    unless reply_message_id.nil?
      reply_message = @bot.channel(event.channel_id).load_message(reply_message_id)
    end

    channel_id = event.channel_id
    user = event.user.id
    content = @channels_to_anonymise[channel_id]
    return unless content

    Discordrb::LOGGER.info "Processing 'anonymise' modal submission"

    event.respond content: "Your message has been posted! 🥰", ephemeral: true

    message_content = event.value 'message_content'
    message_content = message_content.gsub "@", ""
    full_content = "#{message_content}\n-# Anonymous #{get_anonymous_name(user)}"

    message = event.channel.send_message(
      full_content, false, nil, nil, nil, reply_message,
      Discordrb::Components::View.new do |builder|
        builder.row do |row|
          row.button style: :secondary, emoji: '📧', label: "Reply anonymously", custom_id: 'anonymous_reply_button'
        end
      end
    )
    save_to_log message.id, user

    @debouncer.debounce("anonymise_" + channel_id.to_s, 60) do
      send_anchor_message content, event.channel
    end
  end

  def on_anon_message_click(event)
    return unless event.custom_id == 'anonymous_message_button'

    Discordrb::LOGGER.info "Processing 'anonymous' message button click"

    event.show_modal title: 'Enter Anonymous Message',
                     custom_id: 'anonymous_message_modal' do |modal|
      modal.row do |row|
        row.text_input style: :paragraph,
                       custom_id: 'message_content',
                       label: 'Message Content',
                       required: true,
                       max_length: 1900
      end
    end
  end

  def on_anon_reply_click(event)
    return unless event.custom_id == 'anonymous_reply_button'

    Discordrb::LOGGER.info "Processing 'anonymous' reply button click"

    event.show_modal title: 'Enter Anonymous Reply',
                     custom_id: "anonymous_message_modal:#{event.message.id}" do |modal|
      modal.row do |row|
        row.text_input style: :paragraph,
                       custom_id: 'message_content',
                       label: 'Message Content',
                       required: true,
                       max_length: 1900
      end
    end
  end

  def on_message(event)
    channel_id = event.channel.id
    content = @channels_to_anonymise[channel_id]
    return unless config

    Discordrb::LOGGER.info "Message received on anonymised channel #{channel_id}"

    @debouncer.debounce("anonymise_" + channel_id.to_s, 60) do
      send_anchor_message(content, event.channel)
    end
  end

  private

  def get_anonymous_name(user_id)
    ANOMYMOUS_NAMES[(user_id + @name_seed) % ANOMYMOUS_NAMES.length]
  end

  def send_anchor_message(content, channel)
    Discordrb::LOGGER.info "Anchoring message in channel #{channel.id}"

    previous_anchor_id = @previous_anchors[channel.id]
    unless previous_anchor_id.nil?
      previous_anchor = channel.load_message previous_anchor_id
      channel.delete_message previous_anchor unless previous_anchor.nil?
    end

    message = channel.send_embed do |embed, view|
      embed.description = content
      view.row do |row|
        row.button style: :primary, emoji: '💌', label: "Send anonymous message", custom_id: 'anonymous_message_button'
      end
    end

    @previous_anchors[channel.id] = message.id
    save
  end

  def save
    @storage.write PREVIOUS_ANCHORS_FILE_NAME, @previous_anchors
    @storage.write CHANNELS_FOR_ANONYMITY_FILE_NAME, @channels_to_anonymise
  end

  def save_to_log(message_id, user_id)
    @storage.append Ident::ANONYMOUS_LOG_FILE_NAME, { message_id => user_id }
  end

end

end
