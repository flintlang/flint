/*
 * Copyright (c) Kiad Studios, LLC. All rights reserved.
 * Licensed under the MIT License. See License in the project root for license information.
 */

#if os(Linux)

import Foundation
import Glibc

internal func log(_ message: StaticString, category: String, _ args: Any...) {
    // Implementation Note: This method is currently a big hack to just to get
    // any sort of logging output. This needs to get revamped and put into a 
    // file or something. Also, **VERY IMPORTANT**: the protocol talks over
    // stdout, so don't output anything there.

    fputs("category: \(category), message: \(message)\n", stderr)
}

#endif