//
// Created by matthewross on 15/08/19.
//

import Foundation

extension FileHandle : TextOutputStream {
  public func write(_ string: String) {
    guard let data = string.data(using: .utf8) else {
      return
    }
    self.write(data)
  }
}

public func debug(_ content: Any..., separator: String = " ", file: String = #file, line: Int = #line) {
  var standardError: FileHandle = FileHandle.standardError
  let strings = content.map { String(describing: $0) }
  print("\(file):\(line)", strings.joined(separator: separator), to:&standardError)
}
