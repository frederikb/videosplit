# videosplit

`videosplit` is a command line application for splitting video files based on timestamps.

It uses `ffmpeg` to perform the actual video splitting / extraction.

## Installation

If you are running Windows, download the latest release and add the binary in to your PATH. Alternatively you can build it yourself via `nimble install` (requires a [Nim installation](https://github.com/dom96/choosenim)).

Make sure you have a recent version of `ffmpeg` installed as well.

## Usage

Use the `help` option in order to discover all possible commands and parameters.

```bash
videosplit --help
```

Output:

```
Usage:
  videosplit [required&optional-params]
Split video based on a set of timestamps passed in via a CSV file
Options:
  -h, --help                           print this cligen-erated help
  --help-syntax                        advanced: prepend,plurals,..
  -f=, --file=       string  REQUIRED  path to input video
  -c=, --csv=        string  REQUIRED  path to CSV containing split instructions
  -o=, --outputDir=  string  REQUIRED  path to directory where videos will be written to
  -v, --verbose      bool    false     show more information
  -s, --script       bool    false     print ffmpeg commands instead of immediate execution
```

### Split using CSV

Split the given video based on a set of timestamps passed in via a CSV

```bash
videosplit \
     -f 'longvideo.webm' \  # video file
     -t 'timestamps.csv' \  # csv with timestamps/names
     -o 'out/'              # directory in which to place the videos
```

Given the following `timestamps.csv`:

```csv
0:00:00.0,Introduction
0:01:30.0,Topic 1
0:11:07.500,Topic 2
```

Executing the command above will result in the following, whereas each file contains the video from its start to the next timestamp (or end of file if no follow-up exists).

```
$ ls out/
$ out/001_Introduction.webm
$ out/002_Topic 1.webm
$ out/003_Topic 2.webm
```

Alternatively you can specify two timestamps in order to explictly cut out individual parts of a video:

```csv
0:01:30.0,0:07:31,Topic 1
```

### Script output

If you want to generate a list of `ffmpeg` commands for further use in scripts you can simply append the `--script` parameter. In this case no actual video splitting will take place.

```bash
videosplit \
     -f 'longvideo.webm' \  # video file
     -t 'timestamps.csv' \  # csv with timestamps/names
     -o 'out/'              # directory in which to place the videos
     --script               # activcate script mode
```

## Alternatives

This application basically just a simple wrapper for `ffmpeg`. You could could alternatively write a shell script to perform the necessary commands yourself.

Example command:
```bash
ffmpeg -i "longvideo.webm" -ss 9:28:52 -y -c copy -t 77 "out\002_Topic 1.webm"
```

## Contributing

Fixes and new features are welcome. For major changes, please talk to the current maintainer first to discuss what you would like to change.

Please make sure to update tests as appropriate.

## Contributors

Frederik Bülthoff (frederik@buelthoff.name) - Creator

## License

MIT
