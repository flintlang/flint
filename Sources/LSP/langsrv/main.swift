/*
 * Copyright (c) Kiad Studios, LLC. All rights reserved.
 * Licensed under the MIT License. See License in the project root for license information.
 */

import langsrvlib
import LanguageServerProtocol
import JsonRpcProtocol

if CommandLine.arguments.contains("-v") || CommandLine.arguments.contains("--version") {
    print("Swift Language Server v\(0.001)")
} else {
    let inputBuffer = StandardInputOutputBuffer()
    let jsonrpc = JsonRpcProtocol()
    let langsrv = SwiftLanguageServer(transport: jsonrpc)
    langsrv.run(source: inputBuffer)
}
