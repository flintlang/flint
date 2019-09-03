//
//  Process.swift
//  Utils
//
//  Created by matteo on 03/09/2019.
//

import Foundation

public struct ProcessResult {
  public let standardOutputResult: String?
  public let standardErrorResult: String?
  public let terminationStatus: Int32
}

extension Process {
  @discardableResult
  public static func run(executableURL: URL, arguments: [String], currentDirectoryURL: URL?) -> ProcessResult {
    let process = Process()
    let standardOutputPipe = Pipe()
    let standardErrorPipe = Pipe()
    process.executableURL = executableURL
    process.arguments = arguments
    currentDirectoryURL.map { process.currentDirectoryURL = $0}
    process.standardInput = FileHandle.nullDevice
    process.standardOutput = standardOutputPipe
    process.standardError = standardErrorPipe
    try! process.run()
    let standardOutputData = standardOutputPipe.fileHandleForReading.readDataToEndOfFile()
    let standardErrorData = standardErrorPipe.fileHandleForReading.readDataToEndOfFile()
    let standardOutputText = String(data: standardOutputData, encoding: String.Encoding.utf8)
    let standardErrorText = String(data: standardErrorData, encoding: String.Encoding.utf8)
    process.waitUntilExit()

    return ProcessResult(standardOutputResult: standardOutputText,
                         standardErrorResult: standardErrorText,
                         terminationStatus: process.terminationStatus)
  }
}
