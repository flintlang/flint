import Foundation
import Diagnostic

public func exitWithFileNotFoundDiagnostic(file: URL) -> Never {
  let diagnostic = Diagnostic(severity: .error, sourceLocation: nil, message: "Invalid file: '\(file.path)'.")
  // swiftlint:disable force_try
  print(try! DiagnosticsFormatter(diagnostics: [diagnostic], sourceContext: nil).rendered())
  // swiftlint:enable force_try
  exit(1)
}

public func exitWithDirectoryNotCreatedDiagnostic(outputDirectory: URL) -> Never {
  let diagnostic = Diagnostic(severity: .error,
                              sourceLocation: nil,
                              message: "Could not create output directory: '\(outputDirectory.path)'.")
  // swiftlint:disable force_try
  print(try! DiagnosticsFormatter(diagnostics: [diagnostic], sourceContext: nil).rendered())
  // swiftlint:enable force_try
  exit(1)
}

public func exitWithUnableToWriteIRFile(irFileURL: URL) {
  let diagnostic = Diagnostic(severity: .error,
                              sourceLocation: nil,
                              message: "Could not write IR file: '\(irFileURL.path)'.")
  // swiftlint:disable force_try
  print(try! DiagnosticsFormatter(diagnostics: [diagnostic], sourceContext: nil).rendered())
  // swiftlint:enable force_try
  exit(1)
}

public func exitWithSolcNotInstalledDiagnostic() -> Never {
  let diagnostic = Diagnostic(
    severity: .error,
    sourceLocation: nil,
    message: "Missing dependency: solc",
    notes: [
      Diagnostic(
        severity: .note,
        sourceLocation: nil,
        message: "Refer to http://solidity.readthedocs.io/en/develop/installing-solidity.html " +
        "for installation instructions.")
    ]
  )
  // swiftlint:disable force_try
  print(try! DiagnosticsFormatter(diagnostics: [diagnostic], sourceContext: nil).rendered())
  // swiftlint:enable force_try
  exit(1)
}
