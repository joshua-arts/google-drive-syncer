require_relative 'src/sync.rb'
require_relative 'src/drive/drive_system.rb'
require_relative 'src/local/local_system.rb'

# Initialize the drive file system.
drive = DriveSystem.new

# Initialize the local file system.
local = LocalSystem.new

# Do an initial sync to bring local up to speed with Google Drive.
DriveSync.pull_drive(drive, local.local_path)

# Start syncing process.
DriveSync.sync_loop(drive, local, 10)
