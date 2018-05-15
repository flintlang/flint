//
//  SolcCompiler.swift
//  flintc
//
//  Created by Franklin Schrans on 1/8/18.
//

import Foundation

/// The solc compiler, used to compile IULIA IR.
struct SolcCompiler {
  var inputSource: String
  var outputDirectory: URL
  var emitBytecode: Bool

  func compile() {
    let temporaryFile = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent(UUID().uuidString)
    try! inputSource.write(to: temporaryFile, atomically: true, encoding: .utf8)

    let process = Process()

    #if os(Linux)
      process.launchPath = "/usr/bin/solc"
    #else
      process.launchPath = "/usr/local/bin/solc"
    #endif

    verifySolc(launchPath: process.launchPath!)
    process.standardError = Pipe()
    process.arguments = [temporaryFile.path, "--bin"] + (emitBytecode ? ["--opcodes"] : []) + ["-o", outputDirectory.path]

    process.launch()
    process.waitUntilExit()
  }

  private func verifySolc(launchPath: String) {
    guard FileManager.default.isExecutableFile(atPath: launchPath) else {
      exitWithSolcNotInstalledDiagnostic()
    }
  }
}
