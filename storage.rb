# frozen_string_literal: true
require 'yaml'
require 'fileutils'

class Storage
  attr_reader :path

  def initialize(path)
    @path = ensure_trailing_slash(path)
    Discordrb::LOGGER.info "Storage initiated in #{@path}"
    FileUtils.mkdir_p(@path) unless Dir.exist?(@path)
  end

  def write(file_name, data)
    File.open("#{@path}#{file_name}.yaml", 'w') { |file| file.write(data.to_yaml) }
  end

  def read(file_name)
    return {} unless File.exist?("#{@path}#{file_name}.yaml")
    YAML.load_file("#{@path}#{file_name}.yaml")
  end

  private

  def ensure_trailing_slash(path)
    path.end_with?("/") ? path : "#{path}/"
  end
end
