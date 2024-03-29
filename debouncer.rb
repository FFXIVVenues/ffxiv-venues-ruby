class Debouncer
  def initialize
    @threads = Hash.new
  end

  def debounce(key, debounce_time, &block)
    @threads[key]&.exit
    @threads[key] = Thread.new do
      Thread.current[:discordrb_name] = "debounced_#{key}"
      sleep(debounce_time)
      block.call
    end
  end
end
