/*
 * Copyright (c) Kiad Studios, LLC. All rights reserved.
 * Licensed under the MIT License. See License in the project root for license information.
 */

import Foundation

extension Array {
    public func at(_ index: Int) -> Element? {
        return (index < self.count) ? self[index] : nil
    }
}

public func shell(tool toolPath: String, arguments: [String], currentDirectory: String? = nil) -> String {
    let process = Process()
    process.launchPath = toolPath
    process.arguments = arguments

    let output = Pipe()
    process.standardOutput = output
    if let cwd = currentDirectory { process.currentDirectoryPath = cwd }
    process.launch()

    return String(
        data: output.fileHandleForReading.readDataToEndOfFile(),
        encoding: .utf8)!
}
