enum BoogieError {
  // Failure (line number, error string)

  case assertionFailure(Int, String)
  case preConditionFailure(Int, String)
  case postConditionFailure(Int, String)
}
