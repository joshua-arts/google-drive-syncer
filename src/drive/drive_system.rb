require 'google/apis/drive_v3'
require 'googleauth'
require 'googleauth/stores/file_token_store'
require 'mimemagic'

require_relative '../logger.rb'
require_relative './drive_file.rb'

# For tracking the Google Drive file system.
class DriveSystem

  attr_accessor :files, :folders

  MIME_MAP = {
    "application/vnd.google-apps.document" => "text/plain"
  }

  OOB_URI = 'urn:ietf:wg:oauth:2.0:oob'
  CREDENTIALS_PATH = File.join(Dir.home, '.credentials', "drive-sync.yaml")
  SCOPE = Google::Apis::DriveV3::AUTH_DRIVE

  DRIVE_FILES_TYPE = "application/vnd.google-apps"
  DRIVE_FOLDER_TYPE = "application/vnd.google-apps.folder"

  def initialize(config = 'client_secret.json')
    # Initialize and authorize the DriveService.
    @service = Google::Apis::DriveV3::DriveService.new
    @service.client_options.application_name = "Google Drive Sync"
    @service.authorization = authorize(config)

    # A map to link a Google Drive folder id to it's name.
    @folders = {}

    # A list of all files in Google Drive.
    @files, @trash = [], []

    # Locks folders and files from double deletion.
    @lock = []

    # Perform the initial update.
    rebuild
  end

  # Updates our Google Drive file system structure.
  def rebuild
    @files, @trash = [], []
    @folders = {}

    # Grab all untrashed, unshared files.
    file_list = @service.list_files(q: "not trashed and 'me' in owners", fields: "files(id, name, mime_type, parents, modifiedTime, createdTime)")

    # Grab the trash.
    @trash = @service.list_files(q: "trashed and 'me' in owners", fields: "files(id, name)").files

    # Sort the objects by file and folder.
    file_list.files.each do |obj|
      if obj.mime_type == DRIVE_FOLDER_TYPE
        # Map folders so we know what files are in them.
        @folders[obj.id] = obj
      else
        # Append to list of files.
        @files << obj
      end
    end

    # Set files local path match.
    @files.each do |file| file.drive_path = google_drive_path(file) end

    @lock = []
  end

  # Download a Google Drive file to the local_path.
  def download(file, local_path)
    #Logger.log("Downloading #{file.name} from Google Drive.")
    puts "Downloading #{file.name} from Google Drive."

    # Build the folders if neccesary.
    FileUtils.mkdir_p((local_path + file.drive_path).gsub(file.name, ''))

    # Download the file.
    if file.mime_type.include?(DRIVE_FILES_TYPE)
      @service.export_file(file.id, convert_type(file.mime_type), download_dest: local_path + file.drive_path)
    else
      @service.get_file(file.id, download_dest: local_path + file.drive_path)
    end
  end

  # Upload a new local file to Google Drive.
  def upload(local_file)
    #Logger.log("Uploading #{File.basename(local_file)} to Google Drive.")
    puts "Uploading #{File.basename(local_file)} to Google Drive."

    # Guess the mime type.
    mime = MimeMagic.by_path(local_file)

    # If we can guess the mime type.
    if mime then
      drive_type = revert_type(mime.type)
      mime_type = mime.type
    else
      # Assume text.
      drive_type = "application/vnd.google-apps.document"
      mime_type = "text/plain"
    end

    # Find the files folder.
    folder = find_folder(local_file.sub_path)

    metadata = {
      name: File.basename(local_file),
      mime_type: drive_type
    }

    metadata[:parents] = [folder] if folder

    # Create the new file in Google Drive.
    @service.create_file(
      metadata,
      fields: 'id',
      upload_source: local_file.path,
      content_type: mime_type
    )
  end

  # Update an existing file in Google Drive to match local.
  def update(local_file)
    #Logger.log("Updating #{File.basename(local_file)} in Google Drive.")
    puts "Updating #{File.basename(local_file)} in Google Drive."

    # Guess the mime type.
    mime_type = MimeMagic.by_path(local_file)
    drive_type = if mime_type
      revert_type(mime_type.type)
    else
      "application/vnd.google-apps.document"
    end

    # Find the id of the file to update.
    id = (@files.find do |file| local_file.sub_path == file.drive_path end).id

    # Update the existing file in Google Drive.
    @service.update_file(
      id,
      {},
      fields: 'id',
      upload_source: local_file.path,
      content_type: drive_type
    )
  end

  # Delete a file in Google Drive.
  def delete(file)
    #Logger.log("Deleting #{file.name} in Google Drive.")
    puts "Deleting #{file.name} in Google Drive."

    unless @lock.include?(file.id)
      @lock << file.id
      @service.delete_file(file.id)
    end
  end

  # Deletes drive folders that no longer exist locally.
  def verify_path(file, local)
    pieces = file.split('/')[0...-1]

    pieces.each do |p|
      # Check if folder exists in drive.
      folder = @folders.values.find do |f| f.name == p end
      next unless folder
  
      local_folder_names = local.get_folders.map do |f|
        f.split('/').last
      end

      unless local_folder_names.include?(folder.name)
        #Logger.log("Deleting folder #{folder.name} in Google Drive.")
        puts "Deleting folder #{folder.name} in Google Drive."
        unless @lock.include?(folder.id)
          @lock << folder.id

          @files.each do |f|
            @lock << f.id if f.parents.include?(folder.id)
          end

          @service.delete_file(folder.id)
        end
      end
    end
  end

  # Determines if a local file match was trashed in Google Drive.
  def is_in_trash?(local_file)
    @trash.each do |file|
      return true if File.basename(local_file) == file.name
    end
    false
  end

  private

  # Authorize access to the Google Drive API.
  def authorize(config)
    FileUtils.mkdir_p(File.dirname(CREDENTIALS_PATH))

    client_id = Google::Auth::ClientId.from_file("client_secret.json")
    token_store = Google::Auth::Stores::FileTokenStore.new(file: CREDENTIALS_PATH)
    authorizer = Google::Auth::UserAuthorizer.new(client_id, SCOPE, token_store)
    credentials = authorizer.get_credentials('default')

    return credentials unless credentials.nil?

    # User needs to authorize the Google Drive API.
    url = authorizer.get_authorization_url(base_url: OOB_URI)
    puts "You need to authorize access to your Google Drive.\nOpen the following URL in the browser and enter the resulting code after authorization.\n#{url}"
    code = gets
    authorizer.get_and_store_credentials_from_code(user_id: 'default', code: code, base_url: OOB_URI)
  end

  # Finds the files path in Google Drive.
  def google_drive_path(file)
    # If the file has no parents, just return the name.
    return file.name if file.parents.nil? || file.parents.length == 0

    # Start building the local path.
    path = [file.name]
    parent_id = file.parents.first

    # While there is a parent to add to the path.
    while !parent_id.nil? do
      # Find the parent folder.
      parent = if @folders[parent_id]
        @folders[parent_id]
      else
        # In this case, it's the 'My Drive' folder, so it wasn't
        # added in our initial search, we need to add it now.
        @folders[parent_id] = @service.get_file(parent_id, fields: "name, parents, id")
      end

      # Add to the front of the path, ignoring root path.
      path.unshift(parent.name) if !parent.parents.nil? && !parent.parents.empty?

      # Find the next parent (if it exists).
      parent_id = parent.parents.nil? ? nil : parent.parents.first
    end

    path.join('/')
  end

  # Finds the folder ID's that a local file belongs to.
  def find_folder(sub_path)
    ensure_path_exists(sub_path)
    f_break = sub_path.split('/')
    return nil if f_break.length == 1
    f_name = f_break[0...-1].last
    f = @folders.values.find do |f| f.name == f_name end
    f.id
  end

  # Creates a folder path in Google Drive.
  def ensure_path_exists(sub_path)
    path_break = sub_path.split('/')[0...-1]
    parent = nil
    path_break.each do |p|
      f = @folders.values.find do |f| f.name == p end
      if f
        parent = f.id
      else
        folder_metadata = {
          name: p,
          mime_type: DRIVE_FOLDER_TYPE
        }

        folder_metadata[:parents] = [parent] if parent

        folder = @service.create_file(
          folder_metadata,
          fields: 'id, mime_type, name, parents'
        )

        @folders[folder.id] = folder
        parent = folder.id
      end
    end
  end

  # Converts Google Drive types to compatible ones.
  def convert_type(type)
    MIME_MAP[type] || type
  end

  # Reverts a mimetype to a Google Drive compatible one.
  def revert_type(type)
    MIME_MAP.key(type) || type
  end
end
