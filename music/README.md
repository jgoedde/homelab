## Music

_Please don't stop the music 🎵_

TODO: add visualization of how music flow works.

## Contents

<!-- TOC -->
  * [Music](#music)
  * [Contents](#contents)
  * [Setup](#setup)
<!-- TOC -->

## Setup

1. Symlink the MeTube inbox importer script

    ```shell
    ln -sfn /path/to/metube-inbox-importer.sh ~/bin/metube-inbox-importer.sh
    chmod +x ~/bin/metube-inbox-importer.sh
    ```

2. Edit crontab to run every x minutes. (See [`crontab`](https://github.com/jgoedde/homelab/blob/main/music/crontab))

    ```shell
    crontab -e
    ```