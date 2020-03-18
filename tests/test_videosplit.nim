import os
import einheit
import videosplit
import times
import unpack
import options
import strutils

proc testResource(path: string): string =
  getCurrentDir() / "tests" / "resources" / path

proc toTime(time: string): Time =
  parse(time, "H:mm:ss").toTime()

testSuite helperSuite:

  proc testIsValidFilename() =
    self.check(isValidFilename("foo-bar") == true)
    self.check(isValidFilename("foo/bar") == false)
    self.check(isValidFilename("foo\\bar") == false)
    self.check(isValidFilename("foo|bar") == false)
    self.check(isValidFilename("") == false);
    self.check(isValidFilename("<foo|bar>") == false)
    self.check(isValidFilename("con") == false)
    self.check(isValidFilename("aux") == false)
    self.check(isValidFilename("com1") == false)
    self.check(isValidFilename("lpt1") == false)
    self.check(isValidFilename("nul1") == true)
    self.check(isValidFilename("aux1") == true)
    self.check(isValidFilename("a".repeat(255)) == true);
    self.check(isValidFilename("a".repeat(256)) == false);
    self.check(isValidFilename(".") == false)
    self.check(isValidFilename("..") == false)
    self.check(isValidFilename("...") == true)

testSuite videoSplitSuite:

  proc testGenerateFilename() =
    let gen1 = generateFilename(SplitInstruction(id: 37,
            name: "VPC - Direct Connect"))
    self.check(gen1 == "037 - VPC - Direct Connect")

  proc testCalculateDurationsWithExistingDurations() =
    let instruction = SplitInstruction(id: 1,
            name: "S3 - S3 CheatSheet",
            start: toTime("0:58:39"),
            duration: some(initDuration(seconds = 407)))
    calculateMissingDurations(@[instruction]).unpackSeq(processedInstruction)
    var receivedDuration = processedInstruction.duration
    var expectedDuration = instruction.duration
    self.check(receivedDuration == expectedDuration)

  proc testCalculateDurationsWithMissingDurations() =
    let instruction1 = SplitInstruction(id: 1,
            name: "Introduction - Why Get the Solutions Architect Associate",
            start: toTime("0:01:12"))
    let instruction2 = SplitInstruction(id: 2,
            name: "Introduction - Exam Guide Overview", start: toTime("0:07:31"))
    let instruction3 = SplitInstruction(id: 3, name: "S3 - Introduction",
            start: toTime("0:14:42"))
    let converted = calculateMissingDurations(@[instruction1, instruction2, instruction3])
    converted.unpackSeq(converted1, converted2, converted3)

    var duration1 = converted1.duration.get
    var expectedDuration1 = initDuration(seconds = 379)
    self.check(duration1 == expectedDuration1)

    var duration2 = converted2.duration.get
    var expectedDuration2 = initDuration(seconds = 431)
    self.check(duration2 == expectedDuration2)

    var duration3 = converted3.duration.isNone
    self.check(duration3 == true)

  proc testParseSplitInstructionWithDuration() =
    # 0:58:39,1:05:26,S3 - S3 CheatSheet
    let instruction = parseSplitInstruction(@["0:58:39", "1:05:26",
            "S3 - S3 CheatSheet"], 1)
    let receivedStart = instruction.start.toUnix()
    let expectedStart = toTime("0:58:39").toUnix()
    self.check(receivedStart == expectedStart)
    self.check(instruction.name == "S3 - S3 CheatSheet")
    let receivedDuration = instruction.duration.get().inSeconds
    self.check(receivedDuration == 407)

  proc testParseSplitInstructionWithPartial() =
    # 10:16:55,Serverless Follow Along - Follow Along - Cleanup
    let instruction = parseSplitInstruction(@["10:16:55",
            "Serverless Follow Along - Follow Along - Cleanup"], 285)
    let receivedStart = instruction.start.toUnix()
    let expectedStart = toTime("10:16:55").toUnix()
    self.check(receivedStart == expectedStart)
    self.check(instruction.name == "Serverless Follow Along - Follow Along - Cleanup")
    let receivedDurationIsNone = instruction.duration.isNone()
    self.check(receivedDurationIsNone == true)

  proc testReadInstructions() =
    let instructions = readSplitInstructions(testResource("split.csv"))

    self.check(instructions.len == 287)

    let instruction1 = instructions[1];
    self.check(instruction1.id == 2)
    let receivedStartOf1 = instruction1.start.toUnix()
    let expectedStartOf1 = toTime("0:01:12").toUnix()
    self.check(receivedStartOf1 == expectedStartOf1)
    self.check(instruction1.name == "Introduction - Why Get the Solutions Architect Associate")

    # 10:16:55,Serverless Follow Along - Follow Along - Cleanup
    let instruction2 = instructions[285];
    self.check(instruction2.id == 286)
    let receivedStartOf2 = instruction2.start.toUnix()
    let expectedStartOf2 = toTime("10:16:55").toUnix()
    self.check(receivedStartOf2 == expectedStartOf2)
    self.check(instruction2.name == "Serverless Follow Along - Follow Along - Cleanup")

when isMainModule:
  runTests()
