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
