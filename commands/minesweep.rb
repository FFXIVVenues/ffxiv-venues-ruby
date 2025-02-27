module FFXIVVenues

class Minesweep

  MINES = 18
  RENDER_MAP = {
    -1 => "||:boom:||",
    0 => "||:blue_square:||",
    1 => "||:one:||",
    2 => "||:two:||",
    3 => "||:three:||",
    4 => "||:four:||",
    5 => "||:five:||",
    6 => "||:six:||",
    7 => "||:seven:||",
    8 => "||:eight:||",
    9 => "||:nine:||"
  }

  def initialize(bot)
    Discordrb::LOGGER.info "Initializing command 'minesweep'"

    bot.register_application_command :minesweep, "Play minesweeper in discord!", default_permission: false do |interaction|
      interaction.integer "mines", "Set how many bombs will be planted on the board.", required: false
    end
    bot.application_command :minesweep, &method(:on_command)
  end

  def on_command(event)
    Discordrb::LOGGER.info "Executing application command 'minesweep'"

    board = Array.new(9) { Array.new(9) { 0 } }
    mines_to_do = event.options["mines"] || MINES

    while mines_to_do > 0
      x = rand(9)
      y = rand(9)
      next if board[x][y] == -1
      board[x][y] = -1
      increment_surrounding_plots(board, x, y)
      mines_to_do -= 1
    end

    content = ""
    board.each do |row|
      row.each do |plot|
        content << "#{RENDER_MAP[plot]} "
      end
      content << "\n"
    end

    event.respond \
      content: "Have fun!",
      embeds: [
        Discordrb::Webhooks::Embed.new(description: content)
      ]
  end

  def increment_surrounding_plots(board, x, y)
    increment_plot(board, x-1, y-1)
    increment_plot(board, x-1, y)
    increment_plot(board, x-1, y+1)
    increment_plot(board, x, y-1)
    increment_plot(board, x, y+1)
    increment_plot(board, x+1, y-1)
    increment_plot(board, x+1, y)
    increment_plot(board, x+1, y+1)
  end

  def increment_plot(board, x, y)
    return if x < 0 || x > 8 || y < 0 || y > 8
    return if board[x][y] == -1
    board[x][y] += 1
  end

end

end