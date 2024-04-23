# frozen_string_literal: true

module FFXIVVenues

class Random
  def initialize(bot)
    @bot = bot

    @bot.register_application_command :random, "Displays a random number between 0 and 999 in the current chat channel.", default_permission: false do |interaction|
      interaction.integer "upper_limit", "Set an upper limit to display a random number between 1 and specified number.", required: false
    end
    @bot.register_application_command :dice, "Displays a random number between 0 and 999 in the current chat channel.", default_permission: false do |interaction|
      interaction.integer "upper_limit", "Set an upper limit to display a random number between 1 and specified number.", required: false
    end
    @bot.application_command :random, &method(:on_command)
    @bot.application_command :dice, &method(:on_command)
  end

  def on_command(event)
    Discordrb::LOGGER.info "Executing application command 'random'"

    max_number = event.options["max_number"]
    max_inputted = !max_number.nil?
    min_number = max_inputted ? 1 : 0
    max_number = 999 unless max_inputted
    if max_number < 2
      event.respond content: "\"#{max_number}\" is not a valid setting.", ephemeral: true
      return
    end

    random_number = rand(min_number..max_number)
    event.respond content: "Random! #{event.user.nickname || event.user.global_name} rolls a 🎲#{random_number} (out of #{max_number})." if (max_inputted)
    event.respond content: "Random! #{event.user.nickname || event.user.global_name} rolls a 🎲#{random_number}." unless (max_inputted)
  end

end

end