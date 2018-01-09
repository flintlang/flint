//
//  main.swift
//  file-check
//
//  Created by Franklin Schrans on 1/8/18.
//

import FileCheck
import Commander
import Foundation

command(
  Argument<String>("input file"),
  VariadicOption<String>("prefix")
) { inputFile, prefixes  in
  let matchedAll = fileCheckOutput(of: .stdout, withPrefixes: prefixes, checkNot: [], against: .filePath(inputFile)) {
    FileHandle.standardOutput.write(FileHandle.standardInput.readDataToEndOfFile())
  }

  matchedAll ? exit(EXIT_SUCCESS) : exit(EXIT_FAILURE)
  }.run()
