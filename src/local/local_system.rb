require 'fileutils'

# Include the extensions to File.
require_relative './local_file'

# For tracking the local file system.
class LocalSystem

  attr_accessor :files, :local_path

  def initialize(local_path = "/Users/josh/Desktop/my-drive/")
    @local_path = local_path

    # A list of all locally tracked files.
    @files = []

    # Create local path if it doesn't exist.
    FileUtils.mkdir_p(@local_path)

    # Perform the initial update.
    update
  end

  # Updates our local file system structure.
  def update
    @files = []

    Dir["#{@local_path}**/*"].each do |f|
      if File.file?(f)
        f = File.new(f)
        f.sub_path = f.path.gsub(@local_path, '')
        @files << f
      end
    end
  end

end
