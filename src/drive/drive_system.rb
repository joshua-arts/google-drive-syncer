require 'google/apis/drive_v3'
require 'googleauth'
require 'googleauth/stores/file_token_store'

# Include the extensions to Google::Apis::DriveV3::File.
require_relative './drive_file'

# For tracking the Google Drive file system.
class DriveSystem

  attr_accessor :files

  OOB_URI = 'urn:ietf:wg:oauth:2.0:oob'
  APPLICATION_NAME = '3000GoogleDrive'
  CREDENTIALS_PATH = File.join(Dir.home, '.credentials', "drive-ruby-quickstart.yaml")
  SCOPE = Google::Apis::DriveV3::AUTH_DRIVE

  DRIVE_FILES_TYPE = "application/vnd.google-apps"
  DRIVE_FOLDER_TYPE = "application/vnd.google-apps.folder"

  def initialize(config = 'client_secret.json')
    @service = Google::Apis::DriveV3::DriveService.new
    @service.client_options.application_name = "Drive Sync"
    @service.authorization = authorize(config)

    # A map to link a Google Drive folder id to it's name.
    @folders = {}

    # A list of all files in Google Drive.
    @files = []

    # Perform the initial update.
    update
  end

  # Updates our Google Drive file system structure.
  def update
    @files = []

    # Grab all untrashed files.
    response = @service.list_files(q: 'not trashed', fields: "files(id, name, mime_type, parents, modifiedTime, createdTime)")

    # Sort the objects by file and folder.
    response.files.each do |obj|
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
  end

  # Download a Drive file to the local_path.
  def download(file, local_path)
    # Build the folders if neccesary.
    FileUtils.mkdir_p((local_path + file.drive_path).gsub(file.name, ''))
    puts convert_type(file.mime_type)

    # Download the file.
    if file.mime_type.include?(DRIVE_FILES_TYPE)
      @service.export_file(file.id, convert_type(file.mime_type), download_dest: local_path + file.drive_path)
    else
      @service.get_file(file.id, download_dest: local_path + file.drive_path)
    end
  end

  private

  # Authorize access to the Google Drive API.
  def authorize(config)
    FileUtils.mkdir_p(File.dirname(CREDENTIALS_PATH))
    client_id = Google::Auth::ClientId.from_file("client_secret.json")
    token_store = Google::Auth::Stores::FileTokenStore.new(file: CREDENTIALS_PATH)
    authorizer = Google::Auth::UserAuthorizer.new(client_id, SCOPE, token_store)
    user_id = 'default'
    credentials = authorizer.get_credentials(user_id)
    if credentials.nil?
      url = authorizer.get_authorization_url(base_url: OOB_URI)
      puts "Open the following URL in the browser and enter the " + "resulting code after authorization"
      puts url
      code = gets
      credentials = authorizer.get_and_store_credentials_from_code(user_id: user_id, code: code, base_url: OOB_URI)
    end
    credentials
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

  # Converts Google Drive types to compatible ones.
  def convert_type(type)
    if type == 'application/vnd.google-apps.document'
      'text/plain'
    else
      type
    end
  end
end
