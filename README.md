# Google Drive Syncer

`drive-sync` is a simple command line application for syncing a local folder with your Google Drive account. `drive-sync` will pull files from your Google Drive account to a local directory and watch for changes. It currently handles file creation, deletion and modification. If you create/edit/delete a local file in a synced directory, those changes will be pushed to Google Drive. Subsequently, if you do the same in Google Drive, those changes will be pulled to the synced directory.

`drive-sync` attempts to detect local file mime-types and maps them to corresponding Google Drive mime-types so that you can preview most of your documents in Google Drive.

## Installation

1) Clone the repository to your machine.

~~~
git clone https://github.com/joshua-arts/google-drive-syncer
~~~

2) Get credentials for the [Google Drive API](https://developers.google.com/drive/). To do this, go to the [Google Drive API Ruby Quickstart](https://developers.google.com/drive/v3/web/quickstart/ruby) and complete step one, a to h (don't worry about the other steps). Once you've downloaded your `client_secret.json` file, drag it into the `google-drive-syncer` directory you cloned in step one

3) To setup the `drive-sync` command, you need to add it to your path. From inside the `google-drive-syncer` directory, run:

~~~
export PATH=$PATH:$(pwd)
~~~

4) You should now be able to run the command. The first time you run it, you'll have to link it to a specific Google Account. Run `drive-sync --path "/path/to/directory/to/sync"`, copy and paste the generated link into your browser, authenticate a Google Account, and paste the generated token back into the terminal. The token will be saved locally and you won't need to authenticate again.

## Usage

To start syncing a directory with Google Drive, start `drive-sync` like so:

~~~
drive-sync --path "/path/to/directory/to/sync"
~~~

If this directory does not exist, `drive-sync` will automatically create it for you. If it does exist, `drive-sync` will prompt you to confirm that you are okay with it possibly overwriting the content in it.

`drive-sync` runs in a separate background process. To stop syncing, simply run:

~~~
drive-sync --stop
~~~

By default, `drive-sync` checks for changes every ten seconds. In order to sync this, when you start `drive-sync`, you can set the `--sync-delay` option.

~~~
drive-sync --path "/path/to/directory/to/sync" --sync-delay 30
~~~

Lastly, if you don't want to start `drive-sync` in a detached process, you can start it in test mode.

~~~
drive-sync --path "/path/to/directory/to/sync" --test
~~~

## License

`drive-sync` uses the [MIT License](https://github.com/joshua-arts/google-drive-syncer/blob/master/LICENSE.txt).

We are not responsible for any loss of files or data both locally and in Google Drive.
