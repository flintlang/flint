public enum JSLiteral: CustomStringConvertible {
  case Integer(Int)
  case String(String)
  case Address(String)
  case Bool(String)

  public var description: String {
    switch self {
    case .Integer(let i):
      return i.description
    case .String(let s):
      return "\"" + s + "\""
    case .Address(let s):
      return "\"" + s + "\""
    case .Bool(let b):
      if b.description == "true" {
        return 1.description
      } else {
        return 0.description
      }
    }
  }

  public func getType() -> String {
    switch self {
    case .Integer:
      return "Int"
    case .String:
      return "String"
    case .Address:
      return "Address"
    case .Bool:
      return "Bool"
    }
  }
}
