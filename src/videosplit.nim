import os
import strformat
import strutils
import streams
import parsecsv
import times
import options
import sugar
import osproc
import regex

const
  INVALID_FILENAME_CHARS_REGEX = re"""[<>:"\/\\|?*\x00-\x1F]"""
  RESERVED_WINDOWS_NAMES_REGEX = re"""^(?i)(con|prn|aux|nul|com[0-9]|lpt[0-9])$"""
  CURRENT_OR_TOP_DIR_REGEX = re"""^\.\.?$"""

func isValidFilename*(str: string): bool =
  ## Check whether or not a given string is a valid filename
  ## The check performed here is more restrictive and will only allow a subset which is valid on all platforms
  if str == "" or str.len > 255:
    return false
  var m: RegexMatch
  return not (str.contains(INVALID_FILENAME_CHARS_REGEX) or str.match(
      RESERVED_WINDOWS_NAMES_REGEX, m) or str.match(CURRENT_OR_TOP_DIR_REGEX, m))

type
  SplitInstruction* = object
    ## A split instruction with a start timestamp, optional duration, name and id
    id*: int
    start*: Time
    duration*: Option[Duration]
    name*: string

proc calculateMissingDurations*(instructions: seq[SplitInstruction]): seq[
    SplitInstruction] =
  ## Calculate missing durations using the timestamp of the following split instruction
  ## The last split instruction will have an empty duration which signifies a duration lasting until the end of the video
  for i, current in instructions.pairs:
    let hasNextItem = i < instructions.len - 1
    let next = if hasNextItem: some(instructions[i + 1]) else: none(SplitInstruction)
    let instruction = SplitInstruction(
        id: current.id,
        name: current.name,
        start: current.start,
        duration: if current.duration.isSome: current.duration else: next.map(
            n => n.start - current.start))
    result.add(instruction)

const TIMESTAMP_PATTERN = re"^\d{1,2}:\d{2}:\d{2}$"
proc parseSplitInstruction*(row: CsvRow, counter: int): SplitInstruction =
  ## Read a split instruction from a CSV row
  ## Two possible formats which can be intermixed:
  ## 1. H:mm:ss,Name of Segment
  ## 2. H:mm:ss,H:mm:ss,Name Of Segment
  let id = counter
  let startTime = parse(row[0].strip(), "H:mm:ss").toTime()
  var duration = none(Duration)
  var nameIndex = 1
  var m: RegexMatch
  if row[1].match(TIMESTAMP_PATTERN, m):
    let endTime = parse(row[1].strip(), "H:mm:ss").toTime()
    duration = some(endTime - startTime)
    nameIndex = 2
  let name = row[nameIndex].strip()
  if (not isValidFilename(name)):
    raise newException(IOError, "\"$#\" is not a valid (partial) filename" %
            [name])
  return SplitInstruction(
    id: id,
    start: startTime,
    duration: duration,
    name: name)

proc readSplitInstructions*(file: string): seq[SplitInstruction] =
  ## Read split instructions from CSV file
  let fs = newFileStream(file, fmRead)
  if fs == nil:
    raise newException(IOError, "Cannot open the file {csv}")
  var counter = 1
  var parser: CsvParser
  defer: parser.close()
  open(my = parser, input = fs, filename = file, separator = ',',
        skipInitialSpace = true)
  while readRow(parser):
    let instruction = parseSplitInstruction(parser.row, counter)
    result.add(instruction)
    counter += 1

func generateFilename*(instruction: SplitInstruction): string =
  &"{instruction.id:03d} - {instruction.name}"

proc videosplit(file: string, csv: string, outputDir: string,
    verbose: bool = false, script: bool = false) =
  ## Split video based on a set of timestamps passed in via a CSV file

  proc log(instructions: seq[SplitInstruction]) =
    if not script:
      stdout.writeLine("Found $# split instructions" % [
            $instructions.len])

  proc log(instruction: SplitInstruction) =
    if not script:
      let startTimeStr = $instruction.start.format("H:mm:ss")
      stdout.writeLine("$#. Splitting ($# - $#) as $#" % [
        $instruction.id,
        startTimeStr,
        instruction.duration.map(d => instruction.start + d)
        .map(e => e.format("H:mm:ss")).get("end of file"),
        instruction.name])

  proc splitVideo(instruction: SplitInstruction, ext: string): int =
    let startTimeStr = $instruction.start.format("H:mm:ss")
    let outputPath = outputDir / generateFilename(
            instruction).changeFileExt(ext)

    var args = @[
        "-i", file,        # input
      "-ss", startTimeStr, # start of split
      "-y",                # override existing file
      "-c", "copy"         # copy video (no transcoding, but not as accurate)
    ]
    if instruction.duration.isSome:
      args.add("-t") # add duration in seconds (optional if we want everything until the end of the video)
      args.add($instruction.duration.get().inSeconds)
    args.add(outputPath)

    var opts = {poUsePath}
    if verbose:
      opts.incl(poEchoCmd) # print ffmpeg command used
      opts.incl(poParentStreams) # show ffmpeg output

    if script:
      var argsStr = "-i " & quoteShell(file) & " -ss " & startTimeStr & " -y -c copy"
      if instruction.duration.isSome:
        argsStr.add(" -t ")
        argsStr.add($instruction.duration.get().inSeconds)
      argsStr.add(" " & quoteShell(outputPath))
      stdout.writeLine("ffmpeg " & argsStr)
      return 0
    else:
      var process = startProcess("ffmpeg", "", args, nil, opts)
      defer: process.close()
      return process.waitForExit()

  try:
    if not existsFile(file):
      raise newException(IOError, &"{file} cannot be found")
    if not existsFile(csv):
      raise newException(IOError, &"{csv} cannot be found")
    createDir(outputDir)
    let (_, _, ext) = splitFile(file)
    let splitInstructions = calculateMissingDurations(readSplitInstructions(csv))
    if splitInstructions.len == 0:
      raise newException(IOError, &"{csv} does not contain any split instructions")
    splitInstructions.log()
    var failures = newSeq[int]()
    for instruction in splitInstructions:
      instruction.log()
      let exitStatus = splitVideo(instruction, ext)
      if (exitStatus != 0):
        stderr.writeLine("Split instruction $# failed with exit status $#" %
                [$instruction.id, $exitStatus])
        failures.add(instruction.id)
    if failures.len > 0:
      stderr.writeLine("$# out of $# split instructions failed to complete. Rerun with --verbose for further details." %
          [$failures.len, $splitInstructions.len])
      stderr.writeLine("Failed splits: $#" % failures.join(", "))
      quit(1)
  except:
    stderr.write(getCurrentExceptionMsg())
    quit(1)

when isMainModule:
  import cligen
  dispatch(videosplit, help = {"file": "path to input video",
          "csv": "path to CSV containing split instructions",
          "outputDir": "path to directory where videos will be written to",
          "script": "print ffmpeg commands instead of immediate execution",
          "verbose": "show more information"})
