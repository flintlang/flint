public enum PrePostCondition: Equatable {
  case pre(Expression)
  case post(Expression)

  private func lift() -> Expression {
    switch self {
    case .pre(let e):
      return e
    case .post(let e):
      return e
    }
  }

  func replace(e: Expression) -> PrePostCondition {
    switch self {
    case .pre:
      return .pre(e)
    case .post:
      return .post(e)
    }
  }

  public func isPre() -> Bool {
    switch self {
    case .pre: return true
    default: return false
    }
  }

  public func isPost() -> Bool {
    return self.isPre()
  }

  // MARK: - Equatable
  public static func == (lhs: PrePostCondition, rhs: PrePostCondition) -> Bool {
    switch lhs {
    case .pre(let e1):
      switch rhs {
      case .pre(let e2):
        return e1 == e2
      default: break
      }

    case .post(let e1):
      switch rhs {
      case .post(let e2):
        return e1 == e2
      default: break
      }
    }
    return false
  }
}
