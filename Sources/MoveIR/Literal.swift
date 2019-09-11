//
//  Literal.swift
//  YUL
//
//

public enum Literal: CustomStringConvertible {
  case num(Int)
  case string(String)
  case bool(Bool)
  case decimal(Int, Int)
  case hex(String)

  public var description: String {
    switch self {
    case .num(let i):
      return String(i)
    case .string(let s):
      return "\"\(s)\""
    case .bool(let b):
      return String(b)
    case .decimal(let (n1, n2)):
      return "\(n1).\(n2)"
    case .hex(let h):
      return h
    }
  }
}
