require 'fileutils'

require_relative '../logger.rb'
require_relative './local_file.rb'

# For tracking the local file system.
class LocalSystem

  attr_accessor :files, :local_path

  def initialize(local_path)
    @local_path = local_path
    @local_path += '/' if @local_path[-1] != '/'

    # A list of all locally tracked files.
    @files = []

    # Create local path if it doesn't exist.
    FileUtils.mkdir_p(@local_path)

    # Perform the initial update.
    rebuild
  end

  # Updates our local file system structure.
  def rebuild
    @files = []

    Dir["#{@local_path}**/*"].each do |f|
      if File.file?(f)
        f = File.new(f)
        f.sub_path = f.path.gsub(@local_path, '')
        @files << f
      end
    end
  end

  # Gets all local folders.
  def get_folders
    Dir.glob("#{@local_path}**/*").select do |f|
      File.directory?(f)
    end
  end

  # Deletes local folders that no longer exist in Drive.
  def verify_path(file, drive)
    pieces = file.split('/')[0...-1]

    while !pieces.empty?
      f = pieces.pop
      folder = drive.folders.values.find do |df|
        df.name == f
      end

      if folder.nil?
        #Logger.log("Deleting #{f_name} folder locally.")
        puts "Deleting #{f} folder locally."
        fp = "#{@local_path}#{pieces.join('/')}/#{f}"
        FileUtils.rmdir(fp) if File.directory?(fp)
      else
        break
      end
    end
  end

  # Delete a file locally.
  def delete(file)
    #Logger.log("Deleting #{File.basename(file)} locally.")
    puts "Deleting #{File.basename(file)} locally."

    FileUtils.rm(file.path)
  end
end
