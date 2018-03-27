require 'date'

class DriveSync

  @@last_sync = DateTime.now

  class << self
    # Sync every t seconds.
    def sync_loop(drive, local, t = 30)
      while sleep t do
        puts 'loop'
        # Update the Google Drive system.
        drive.update

        # Update the local system.
        local.update

        # Sync the two.
        sync(drive, local)
      end
    end

    # Syncs the Google Drive file system to the local file system.
    def sync(drive, local)
      # Handle drive changes.
      drive.files.each do |drive_file|
        # Check for files in Drive that don't exist locally.
        unless drive_file.has_local_match?(local.files)
          # If the drive file was created after the
          # last sync, then it's a newly created file.
          if drive_file.created_time > @@last_sync
            # TODO: handle newly created file
          else
            # TODO: handle local file deletion.
          end
        end

        # Check for Google Drive modifications.
        if drive_file.modified_time > @@last_sync
          # Download the modifications.
          #drive.get_file(file.id, download_dest: local.local_path + file.path)
        end
      end

      # Check for local modifications.
      local.files.each do |local_file|

      end

      # Update the last sync time.
      @@last_sync = DateTime.now
    end

    # Brings the local filesystem up to date with Google Drive.
    def pull_drive(drive, local_path)
      drive.files.each do |drive_file|
        drive.download(drive_file, local_path)
      end
    end
  end

end
