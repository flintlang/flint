//
//  Tokenizer
//  Parser
//
//  Created by Franklin Schrans on 12/19/17.
//

import Foundation

public struct Tokenizer {
  var inputFile: URL
  
  public init(inputFile: URL) {
    self.inputFile = inputFile
  }
  
  public func tokenize() -> [Token] {
    let code = try! String(contentsOf: inputFile, encoding: .utf8)
    let components = code.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty} 
    
    let tokens = components.flatMap { Token.tokenize(string: $0) }
    return tokens
  }
}
