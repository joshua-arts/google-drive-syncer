require 'trollop'

require_relative 'src/sync.rb'
require_relative 'src/drive/drive_system.rb'
require_relative 'src/local/local_system.rb'

# Prompt helper.
def prompt(*args)
  print(*args)
  gets
end

# Handle command line options.
opts = Trollop::options do
  opt :path, "Path to folder to sync.", type: :string
  opt :sync_delay, "Seconds between each sync.", default: 20
end

# Path validation.
if opts[:path]
  if File.directory?(opts[:path])
    ans = prompt("The directory #{opts[:path]} already exists, are you okay with overwriting its contents? (Y / N): ")
    abort unless ans[0].upcase == "Y"
  end
else
  abort("You must provide a path to the local folder to sync using --path.")
end

# Initialize the drive file system.
drive = DriveSystem.new

# Initialize the local file system.
local = LocalSystem.new(opts[:path])

# Do an initial sync to bring local up to speed with Google Drive.
DriveSync.pull_drive(drive, local.local_path)

# Start syncing process.
DriveSync.sync_loop(drive, local, opts[:sync_delay])
