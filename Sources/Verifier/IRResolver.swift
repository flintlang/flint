protocol IRResolver {
  associatedtype InputType
  associatedtype ResultType
  func resolve(ir: InputType) -> ResultType
}
