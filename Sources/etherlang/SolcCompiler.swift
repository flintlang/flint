//
//  SolcCompiler.swift
//  etherlang
//
//  Created by Franklin Schrans on 1/8/18.
//

import Foundation

struct SolcCompiler {
  var inputSource: String
  var outputDirectory: URL
  var emitBytecode: Bool

  func compile() {
    let temporaryFile = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent(UUID().uuidString)
    try! inputSource.write(to: temporaryFile, atomically: true, encoding: .utf8)

    let process = Process()
    process.launchPath = "/usr/local/bin/solc"
    process.standardError = nil
    process.arguments = [temporaryFile.path, "--bin", emitBytecode ? "--opcodes" : "", "-o", outputDirectory.path]

    process.launch()
    process.waitUntilExit()
  }
}
