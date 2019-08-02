import Foundation

struct Boogie {
  static func verifyBoogie(boogie: String, monoLocation: String, boogieLocation: String,
                           printVerificationOutput: Bool) -> [BoogieError] {
    let tempBoogieFile = Boogie.writeToTempFile(data: boogie)
    let (uncheckedOutput, terminationStatus) =
        Boogie.executeTask(executable: monoLocation,
                           arguments: [boogieLocation,
                                       tempBoogieFile.path,
                                       "/inline:spec", // Boogie procedure inlining
                                       //"/inline:none", // No Boogie procedure inlining
                                       "/loopUnroll:5"
                           ],
                           captureOutput: true)
    guard let output = uncheckedOutput else {
      print("Error during verification, could not decode verifier output")
      fatalError()
    }

    if printVerificationOutput {
      print(output)
    }

    if terminationStatus != 0 {
      print("Error during verification, verifier terminated with non-zero exit code")
      print(output)
      fatalError()
    }

    return Boogie.extractBoogieErrors(rawBoogieOutput: output)
  }

  private static func extractBoogieErrors(rawBoogieOutput: String) -> [BoogieError] {
    // Example Boogie output
    /*
    Boogie program verifier version 2.3.0.61016, Copyright (c) 2003-2014, Microsoft.
    test.bpl(472,3): Error BP5002: A precondition for this call might not hold.
    test.bpl(461,3): Related location: This is the precondition that might not hold.
    Execution trace:
        test.bpl(472,3): anon0
    test.bpl(482,1): Error BP5003: A postcondition might not hold on this return path.
    test.bpl(477,3): Related location: This is the postcondition that might not hold.
    Execution trace:
        test.bpl(481,5): anon0
    test.bpl(492,1): Error BP5003: A postcondition might not hold on this return path.
    test.bpl(487,3): Related location: This is the postcondition that might not hold.
    Execution trace:
        test.bpl(491,5): anon0
    test.bpl(498,3): Error BP5001: This assertion might not hold.
    Execution trace:
        test.bpl(498,3): anon0
    test.bpl(508,3): Error BP5002: A precondition for this call might not hold.
    test.bpl(461,3): Related location: This is the precondition that might not hold.
    Execution trace:
        test.bpl(507,5): anon0

    test.bpl(364,1): Error BP5004: This loop invariant might not hold on entry.
    Execution trace:
        test.bpl(313,23): anon0
        test.bpl(329,30): anon15_Then
        test.bpl(334,19): anon3
        test.bpl(344,30): anon16_Then
        test.bpl(349,22): anon6
        test.bpl(351,1): anon17_LoopHead
        test.bpl(357,22): anon17_LoopBody

    Boogie program verifier finished with 13 verified, 5 errors


    935-ADAC-1E81E2A8A081.bpl(209,0): Error: \
        command assigns to a global variable that is not in the enclosing procedure's modifies clause: nextInstance_Wei

    Boogie program verifier finished with 10 verified, 1 error


    */
    var rawLines = rawBoogieOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        .components(separatedBy: "\n")
    rawLines.removeFirst() // Discard first line - contains Boogie version info

    // Check if output contains non-verification errors (syntax ...)

    var nonVerificationErrors = [BoogieError]()
    for line in rawLines {
      let matches = line.groups(for: "\\([0-9]+,[0-9]+\\): [eE]rror:")
      if matches.count > 0 {
        if line.contains("modifies clause") {
          nonVerificationErrors.append(.modifiesFailure(Boogie.parseErrorLineNumber(line: matches[0][0])))
        } else {
          nonVerificationErrors.append(.genericFailure(line,
                                                       Boogie.parseErrorLineNumber(line: matches[0][0])))
        }
      }
    }
    if nonVerificationErrors.count > 0 {
      return nonVerificationErrors
    }

    var groupedErrorLines = [(Int, [String])]() // Error code + trace
    for line in rawLines {
      // Look for tuple followed by "Error BP...."
      let matches = line.groups(for: "\\([0-9]+,[0-9]+\\): Error BP([0-9]+)")
      if matches.count > 0 {
        groupedErrorLines.append((Int(matches[0][1])!, []))
      }

      if groupedErrorLines.count > 0 {
        groupedErrorLines[groupedErrorLines.count - 1].1.append(line)
      }
    }

    return groupedErrorLines.map({ Boogie.parseBoogieError(errorCode: $0.0, errorLines: $0.1) })
  }

  private static func parseBoogieError(errorCode: Int, errorLines: [String]) -> BoogieError {
    switch errorCode {
    case 5001:
      // Assertion failure
      guard let firstLine = errorLines.first else {
        print("Assertion failure should have at least one line")
        fatalError()
      }
      let lineNumber = Boogie.parseErrorLineNumber(line: firstLine)
      return .assertionFailure(lineNumber)

    case 5002:
      // Precondition failure
      let callLocationLine = errorLines[0] // Line of procedure call
      let callLineNumber = Boogie.parseErrorLineNumber(line: callLocationLine)

      let relatedLocationLine = errorLines[1] // Related location line, has the offending pre condition
      let preCondLineNumber = Boogie.parseErrorLineNumber(line: relatedLocationLine)
      return .preConditionFailure(callLineNumber, preCondLineNumber)

    case 5003:
      // PostCondition failure
      let relatedLocationLine = errorLines[1] // Related location line, has the offending post condition
      let postCondLineNumber = Boogie.parseErrorLineNumber(line: relatedLocationLine)

      let procedureResponsibleLine = errorLines[0] // Has the line of the responsible return path of offending procedure
      let procedureResponsibleLineNumber = Boogie.parseErrorLineNumber(line: procedureResponsibleLine)
      return .postConditionFailure(procedureResponsibleLineNumber, postCondLineNumber)

    case 5004:
      let loopInvariantLine = errorLines[0] // Has the line of the responsible return path of offending procedure
      let loopInvariantLineNumber = Boogie.parseErrorLineNumber(line: loopInvariantLine)
      return .loopInvariantEntryFailure(loopInvariantLineNumber)

    default:
      print("Couldn't determine type of verification failure code: \(errorCode)\n\(errorLines)")
      fatalError()
    }
  }

  private static func parseErrorLineNumber(line: String) -> Int {
    // Look for tuple followed by "Error"
    let matches = line.groups(for: "\\(([0-9]+),[0-9]+\\):")
    switch matches.count {
    case 1:
      // Extract line number
      return Int(matches[0][1])!
    default:
      print("Could not parse boogie error line")
      print(matches)
      print(line)
      fatalError()
    }
  }

  static func executeTask(executable: String, arguments: [String], captureOutput: Bool) -> (String?, Int32) {
    // Create a Task instance
    let task = Process()

    // Set the task parameters
    task.executableURL = URL(fileURLWithPath: executable)
    task.arguments = arguments

    // Create a Pipe and make the task
    // put all the output there
    let pipe = Pipe()
    task.standardOutput = captureOutput ? pipe : FileHandle(forWritingAtPath: "/dev/null")!
    task.standardError = captureOutput ? Pipe() : FileHandle(forWritingAtPath: "/dev/null")!
    // Launch the task
    try! task.run()
    task.waitUntilExit()

    var uncheckedOutput: String?
    if captureOutput {
      uncheckedOutput = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: String.Encoding.utf8)
    }
    // Get the data
    return (uncheckedOutput, task.terminationStatus)
  }

  static func writeToTempFile(data: String) -> URL {
    let uniqueFileName = UUID().uuidString + ".bpl"
    let tempFile = URL(fileURLWithPath: NSTemporaryDirectory(),
                       isDirectory: true).appendingPathComponent(uniqueFileName)
    do {
      // Safely force unwrap as Swift uses unicode internally
      try data.data(using: .utf8)!.write(to: tempFile, options: [.atomic])
    } catch {
      print("Error writing boogie to file: \(error)")
      fatalError()
    }
    return tempFile
  }

}
