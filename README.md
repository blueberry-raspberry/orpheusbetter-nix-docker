# orpheusbetter-nix-docker

This is a docker image that is automatically built using Nix. You can download the latest version [here](https://github.com/blueberry-raspberry/orpheusbetter-nix-docker/releases/download/refs%2Fheads%2Fmaster/image.tar.gz) When you've grabbed the latest release, you can add it to docker using `docker load`:

```sh
$ docker load < image.tar.gz
411b6ed7d9f2: Loading layer  291.8MB/291.8MB
Loaded image: orpheus-better-SOME_GIBBERISH_REPLACE_THIS
```

Then, you can run it as follows (replacing with appropriate values):

```sh
docker run \
  --mount "type=bind,source=/your/torrent/client/import/dir,target=/torrents"
  --mount "type=bind,source=/your/download/folder,target=/downloads"
  --mount "type=bind,source=/path/to/your/config.conf,target=/config" \
  orpheus-better-unstable-SOME_GIBBERISH_REPLACE_THIS
```

The only set path is `/config`, this is where we will look for the config, any other path can be set in the config.
A good start would be the following:

```conf
[orpheus]
username = JohnSmith
password = CorrectHorseBatteryStaple
data_dir = /downloads
output_dir =
torrent_dir = /torrents
formats = flac, v0, 320
media = cd, vinyl, web
24bit_behaviour = 0
tracker = https://home.opsfet.ch/
api = https://orpheus.network
mode = both
source = OPS
```
