require 'logger'
require 'date'

class Logger
  # Allow for setting a different log file.
  attr_accessor :log_file

  @@log_file = './drive-sync.log'

  class << self
    def log(msg)
      # Write to log.
      File.open(@@log_file, 'w') do |log|
        log.write("#{DateTime.now} - #{msg}\n")
      end
    end
  end
end
