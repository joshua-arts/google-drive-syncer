# This file is used for testing the applications core functionality.

require 'trollop'

require_relative 'src/sync.rb'
require_relative 'src/drive/drive_system.rb'
require_relative 'src/local/local_system.rb'

opts = Trollop::options do
  opt :path, "Path to folder to sync.", type: :string
end

abort("Must supply path when testing.") unless opts[:path]

drive = DriveSystem.new

local = LocalSystem.new(opts[:path])
DriveSync.pull_drive(drive, local.local_path)

DriveSync.sync_loop(drive, local, 10)
