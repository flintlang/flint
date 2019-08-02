import Diagnostic

protocol Verifier {
  func verify() -> (verified: Bool, errors: [Diagnostic])
}
