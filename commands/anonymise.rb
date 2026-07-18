# frozen_string_literal: true

module FFXIVVenues

class Anonymise
  attr_accessor :channels_to_anonymise, :previous_anchors

  CHANNELS_FOR_ANONYMITY_FILE_NAME = 'anonymous.channels_to_anon'
  PREVIOUS_ANCHORS_FILE_NAME = 'anonymous.previous_anchors'
  MESSAGE_LOG_FILE_NAME = 'anonymous.message_log'
  DESCRIPTORS = [
    "Azure", "Golden", "Silver", "Shadow", "Crimson", "Emerald", "Ivory", "Obsidian",
    "Storm", "Frost", "Dusky", "Bright", "Silent", "Wild", "Swift", "Ancient",
    "Royal", "Noble", "Tiny", "Giant", "Spotted", "Striped", "Velvet", "Fluffy", "Violet",
    "Curious", "Sleepy", "Happy", "Mischievous", "Gentle", "Brave"
  ]

  ANIMALS = [
    "Abyssinian Cat", "American Bobtail Cat", "American Curl Cat", "American Shorthair Cat",
    "Balinese Cat", "Bengal Cat", "Birman Cat", "Bombay Cat", "British Shorthair Cat",
    "Burmese Cat", "Chartreux Cat", "Cornish Rex Cat", "Devon Rex Cat", "Egyptian Mau Cat",
    "Exotic Shorthair Cat", "Havana Brown Cat", "Himalayan Cat", "Japanese Bobtail Cat",
    "Korat Cat", "LaPerm Cat", "Lykoi Cat", "Maine Coon Cat", "Manx Cat", "Munchkin Cat",
    "Nebelung Cat", "Norwegian Forest Cat", "Ocicat Cat", "Oriental Cat", "Persian Cat",
    "Pixie-bob Cat", "Ragamuffin Cat", "Ragdoll Cat", "Russian Blue Cat", "Savannah Cat",
    "Scottish Fold Cat", "Selkirk Rex Cat", "Siamese Cat", "Siberian Cat", "Singapura Cat",
    "Snowshoe Cat", "Somali Cat", "Sphynx Cat", "Tonkinese Cat", "Toyger Cat",
    "Turkish Angora Cat", "Turkish Van Cat",

    "Golden Retriever Dog", "Labrador Retriever Dog", "German Shepherd Dog",
    "Border Collie Dog", "Shiba Inu Dog", "Akita Dog", "Corgi Dog", "Dalmatian Dog",
    "Husky Dog", "Samoyed Dog", "Greyhound Dog", "Beagle Dog", "Poodle Dog",
    "Chihuahua Dog", "Doberman Dog", "Boxer Dog", "Rottweiler Dog",

    "Parakeet", "Cockatiel", "Cockatoo", "Macaw", "Canary", "Finch", "Lovebird",
    "African Grey Parrot",

    "Hamster", "Gerbil", "Guinea Pig", "Ferret", "Chinchilla", "Fancy Rat",

    "Ball Python", "Corn Snake", "Leopard Gecko", "Crested Gecko", "Bearded Dragon",
    "Blue Tongue Skink",

    "Goldfish", "Betta Fish", "Guppy Fish", "Angelfish", "Tetra Fish", "Koi Fish"
  ]

  ANONYMOUS_NAMES =
    DESCRIPTORS
      .product(ANIMALS)
      .map { |d, a| "#{d} #{a}" }
      .shuffle
      .first 1000
      .freeze

  def initialize(bot, debouncer, storage)
    Discordrb::LOGGER.info "Initializing command 'anonymise'"

    @bot = bot
    @debouncer = debouncer
    @storage = storage
    @name_seed = rand(0..ANONYMOUS_NAMES.length)

    @channels_to_anonymise = @storage.read CHANNELS_FOR_ANONYMITY_FILE_NAME
    @previous_anchors = @storage.read PREVIOUS_ANCHORS_FILE_NAME

    @bot.register_application_command :anonymise, "Enable anonymous interactions in this channel.", default_permission: false do |interaction|
      interaction.string "anchor_content", "The text content of the anchored message.", required: false
    end
    @bot.register_application_command :ident, "Identify a message sent through anonymous interaction.", default_permission: false do |interaction|
      interaction.string "message_id", "The ID of the anonymous message.", required: true
    end

    @bot.application_command :anonymise, &method(:on_command)
    @bot.application_command :ident, &method(:on_ident_command)
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

  def on_ident_command(event)
    Discordrb::LOGGER.info "Executing application command 'ident'"

    if event.server.nil?
      event.respond content: "This command cannot be used in DMs.", ephemeral: true
      return
    end

    map = @storage.read MESSAGE_LOG_FILE_NAME
    message_id = event.options["message_id"].to_i
    entry = map[message_id]

    if entry.nil?
      event.respond content: "Couldn't find an author for that message id.", ephemeral: true
      return
    end

    if entry[:guild_id] != event.server_id
      event.respond content: "That message was not posted in this server.", ephemeral: true
      return
    end

    event.respond content: "Message was authored by <@#{entry[:user_id]}>.", ephemeral: true
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

    confirm_message = event.respond content: "Your message is being been posted! 🥰", ephemeral: true

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
    save_to_log message.id, user, event.server_id

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
    return if content.nil?

    Discordrb::LOGGER.info "Message received on anonymised channel #{channel_id}"

    @debouncer.debounce("anonymise_" + channel_id.to_s, 60) do
      send_anchor_message(content, event.channel)
    end
  end

  private

  def get_anonymous_name(user_id)
    ANONYMOUS_NAMES[(user_id + @name_seed) % ANONYMOUS_NAMES.length]
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

  def save_to_log(message_id, user_id, guild_id)
    @storage.append MESSAGE_LOG_FILE_NAME, { message_id => { user_id: user_id, guild_id: guild_id } }
  end

end

end
