//
//  SourceFile.swift
//  ParserTests
//
//  Created by Franklin Schrans on 12/20/17.
//

import Foundation

struct SourceFile {
   var contents: String

   func write(to location: URL) {
      try! contents.data(using: .utf8)?.write(to: location)
   }
}
