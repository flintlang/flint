/*
 * Copyright (c) Kiad Studios, LLC. All rights reserved.
 * Licensed under the MIT License. See License in the project root for license information.
 */

#if os(macOS)
import Darwin
import os.log
private var logs: [String: OSLog] = [:]

let subsystem = "com.kiadstudios.swift-langsrv"

internal func log(_ message: StaticString, category: String, _ args: Any...) {
    if #available(macOS 10.12, *) {
        let log: OSLog = logs[category] ?? OSLog(subsystem: subsystem, category: category)
        logs[category] = log

        os_log(message, log: log, type: .default, args)
    } else {
        // Implementation Note: This method is currently a big hack to just to get
        // any sort of logging output. This needs to get revamped and put into a 
        // file or something. Also, **VERY IMPORTANT**: the protocol talks over
        // stdout, so don't output anything there.

        let escaped = message.description.replacingOccurrences(of: "%{public}@", with: "%@")
        fputs("category: \(category), message: \(escaped)\n", stderr)
    }
}

#endif
