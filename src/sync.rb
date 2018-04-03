require 'date'

# TODO:
# renaming in drive causes duplicate.

class DriveSync

  @@last_sync = DateTime.now

  class << self
    # Sync every t seconds.
    def sync_loop(drive, local, t = 10)
      # Add (1.5 * t) seconds to @@last_sync so we don't fire
      # uploads on files pulled from the initial sync.
      @@last_sync += Rational(1.5 * t, 86400)

      while sleep t do
        # Update the Google Drive system.
        drive.rebuild

        # Update the local system.
        local.rebuild

        # Sync the file systems.
        sync(drive, local)

        # Update the last sync time.
        @@last_sync = DateTime.now
      end
    end

    # Syncs the Google Drive file system to the local file system.
    def sync(drive, local)
      # Files that have just been downloaded.
      freeze = []

      # Handle Google Drive changes.
      drive.files.each do |drive_file|
        # Check for Google Drive modifications.
        if drive_file.modified_time > @@last_sync
          # Download the new file.
          drive.download(drive_file, local.local_path)
          freeze << drive_file.drive_path          
        end

        # Check for files in Google Drive that don't exist locally.
        unless drive_file.has_local_match?(local.files)
          # If the Google Drive file hasn't been modified.
          if drive_file.modified_time < @@last_sync
            # Delete the file in drive.
            verify = drive_file.drive_path
            drive.delete(drive_file)

            # Check that the path is still intact locally.
            drive.verify_path(verify, local)
          end
        end
      end

      # Handle local changes.
      local.files.each do |local_file|
        # If a file exists locally but not in Google Drive.
        unless local_file.has_drive_match?(drive.files)
          # If the file is in the Google Drive trash, then it was deleted.
          # Otherwise, a new file was created locally.
          if drive.is_in_trash?(local_file)
            # Delete the file locally.
            verify = local_file.sub_path
            local.delete(local_file)

            # Check that the path is still intact in drive.
            local.verify_path(verify, drive)
          else
            # Upload changes to Google Drive.
            drive.upload(local_file)
          end
        else
          if time_to_datetime(local_file.mtime) > @@last_sync
            # A local file has been modified, update.
            drive.update(local_file) unless freeze.include?(local_file.sub_path)
          end
        end
      end
    end

    # Brings the local filesystem up to date with Google Drive.
    def pull_drive(drive, local_path)
      drive.files.each do |drive_file|
        drive.download(drive_file, local_path)
      end
    end

    private

    def time_to_datetime(t)
      seconds = t.sec + Rational(t.usec, 10**6)
      offset = Rational(t.utc_offset, 60 * 60 * 24)
      DateTime.new(t.year, t.month, t.day, t.hour, t.min, seconds, offset)
    end
  end
end
