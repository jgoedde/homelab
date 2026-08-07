## My Homelab setup

My personal Infra hosting some l33t services.

## Contents

<!-- TOC -->
  * [My Homelab setup](#my-homelab-setup)
  * [Contents](#contents)
  * [Services & Technologies used](#services--technologies-used)
  * [Music Management](#music-management)
<!-- TOC -->

## Services & Technologies used

- Docker (compose)
- [Syncthing](https://syncthing.net/), to sync Music, Notes, and stuff
- [Finances](https://github.com/jgoedde/Finances), Personal expense tracker, stored in Browser
- [MeTube](https://github.com/alexta69/metube#%EF%B8%8F-configuring-yt-dlp-options), Remote YouTube Downloader GUI
- [Immich](https://github.com/immich-app/immich), Self-hosted photo and video management application
- [Karakeep](https://github.com/karakeep-app/karakeep), formerly Hoarder. Bookmarking solution with AI tagging
- [Paperless-ngx](https://github.com/paperless-ngx/paperless-ngx), document management solution

## Music Management

Started building my own personal music library, getting off Streaming Services etc.
Built a nice automation (imo) to get YouTube Rips - See [music/README](music/README.md)

Using [beets](https://beets.io/) to manage the library, auto tag, audio fingerprinting and importing said YT rips.
