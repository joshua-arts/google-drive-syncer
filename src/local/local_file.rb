class File
  # A files subpath is it's file path with the defined local_path removed.
  attr_accessor :sub_path

  # Checks if a local file has a match in Google Drive.
  def has_drive_match?(files)
    files.each do |file|
      return true if self.sub_path == file.drive_path
    end
    false
  end
end
