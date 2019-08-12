//
//  SolcCompiler.swift
//  flintc
//
//  Created by Franklin Schrans on 1/8/18.
//

import Foundation

/// The solc compiler, used to compile YUL IR.
struct SolcCompiler {
  var inputSource: String
  var outputDirectory: URL
  var emitBytecode: Bool

  func compile() throws {
    let temporaryFile = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
      .appendingPathComponent(UUID().uuidString)
    try inputSource.write(to: temporaryFile, atomically: true, encoding: .utf8)

    let process = Process()

    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")

    //verifySolc(launchPath: process.executableURL!.absoluteString)
    process.standardError = Pipe()
    process.arguments = Array([
      [
        "solc",
        temporaryFile.path,
        "--bin"
      ],
      emitBytecode ? ["--opcodes"] : [],
      [
        "-o",
        outputDirectory.path
      ]
    ].joined())

    try! process.run()
    process.waitUntilExit()
  }

  private func verifySolc(launchPath: String) {
    guard FileManager.default.isExecutableFile(atPath: launchPath) else {
      exitWithSolcNotInstalledDiagnostic()
    }
  }
}
