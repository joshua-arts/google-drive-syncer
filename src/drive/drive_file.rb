class Google::Apis::DriveV3::File
  # Add a drive path attribute.
  attr_accessor :drive_path

  # Checks if a Google Drive file has a local match in the local file system.
  def has_local_match?(files)
    files.each do |file|
      return true if self.drive_path == file.sub_path
    end
    false
  end
end
