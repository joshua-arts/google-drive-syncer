require 'trollop'

require_relative 'src/sync.rb'
require_relative 'src/drive/drive_system.rb'
require_relative 'src/local/local_system.rb'

# Prompt helper.
def prompt(*args)
  print(*args)
  gets
end

# TODO: PDF conversion, test creating folders locally and in drive.

# Handle command line options.
opts = Trollop::options do
  opt :stop, "Stop syncing."
  opt :path, "Path to folder to sync.", type: :string
  opt :sync_delay, "Seconds between each sync.", default: 20
end

if opts[:stop]
  abort("drive-sync is not running, nothing to stop.") unless File.exists?("sync.pid")

  pid = File.read("sync.pid").to_i

  # Stop the existing syncing process.
  Process.kill("TERM", pid)

  # Delete the pid file.
  File.delete("sync.pid")

  abort("drive-sync has been disabled.")
end

# Don't allow for multiple processes.
if File.exists?("sync.pid")
  abort("drive-sync is already running, to stop use 'drive-sync --stop'")
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

puts "Starting syncing process for #{opts[:path]}..."

# Initialize the drive file system.
drive = DriveSystem.new

# Initialize the local file system.
local = LocalSystem.new(opts[:path])

# Do an initial sync to bring local up to speed with Google Drive.
DriveSync.pull_drive(drive, local.local_path)
puts "Finished initial sync."

# Start the sync loop in a seperate process.
pid = fork do
  DriveSync.sync_loop(drive, local, opts[:sync_delay])
end

# Keep track of the pid for stopping.
File.write("sync.pid", pid)

puts "Syncing started, use 'drive-sync --stop' to stop."
