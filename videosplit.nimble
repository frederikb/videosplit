# Package

version       = "0.1.0"
author        = "Frederik Bülthoff"
description   = "Split videos files by timestamp(s)"
license       = "MIT"
srcDir        = "src"
bin           = @["videosplit"]
binDir        = "bin"
skipExt       = @["nim"]

# Dependencies

requires "nim >= 1.0.4"
requires "cligen >= 0.9.43"
requires "einheit >= 0.2.0"
requires "regex >= 0.13.1"
requires "unpack >= 0.4.0"
