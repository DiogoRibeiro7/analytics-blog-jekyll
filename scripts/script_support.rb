#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"
require "time"

module ScriptSupport
  class ProgressBar
    DEFAULT_WIDTH = 30

    def initialize(total:, label: "Progress", width: DEFAULT_WIDTH)
      raise ArgumentError, "total must be positive" unless total&.positive?

      @total = total
      @label = label
      @width = width
      @current = 0
      @start_time = Time.now
      render
    end

    def advance(step = 1, message: nil)
      @current += step
      @current = @total if @current > @total
      render(message: message)
      complete if finished?
    end

    private

    def finished?
      @current >= @total
    end

    def percentage
      ((@current.to_f / @total) * 100).clamp(0, 100)
    end

    def render(message: nil)
      filled_length = (percentage / 100 * @width).round
      bar = ("#" * filled_length) + ("-" * (@width - filled_length))
      elapsed = Time.now - @start_time
      eta = if @current.zero?
              "eta --"
            else
              remaining = elapsed / @current * (@total - @current)
              format("eta %<time>.1fs", time: remaining)
            end
      output = format("\r%-20s [%s] %5.1f%% (%d/%d) %s",
                      @label,
                      bar,
                      percentage,
                      @current,
                      @total,
                      eta)
      output = format("%s %s", output, message) if message
      print output
      $stdout.flush
    end

    def complete
      puts
    end
  end

  module_function

  def ensure_path(path)
    FileUtils.mkdir_p(File.dirname(path))
  end

  def write_file(path, content)
    ensure_path(path)
    File.write(path, content)
  end

  def sanitize_filename(filename)
    filename.to_s
            .downcase
            .gsub(/[^a-z0-9-]+/, "-").gsub(/-+/, "-").gsub(/^-|-$/, "")
  end

  def command_available?(cmd)
    system("command -v #{cmd} > /dev/null 2>&1")
  end

  def run_command(command, error_message: nil)
    success = system(command)
    return if success

    raise(error_message || "Command failed: #{command}")
  end

  def handle_errors
    yield
  rescue Interrupt
    warn '\nOperation cancelled by user.'
    exit 1
  rescue StandardError => e
    warn "\nError: #{e.message}"
    warn e.backtrace.join("\n") if ENV["DEBUG"]
    exit 1
  end
end
