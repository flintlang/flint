import Diagnostic
import Foundation

class Diagnostics {
  public static var diagnostics: [Diagnostic] = []
  public static var sourceContext: SourceContext? = nil

  static func add(_ diagnostics: Diagnostic...) {
    self.diagnostics.append(contentsOf: diagnostics)
  }

  static func display() {
    try! print(DiagnosticsFormatter(diagnostics: diagnostics,
                                    sourceContext: sourceContext!).rendered())
  }

  static func displayAndExit(code: Int32 = 1) -> Never {
    display()
    return exit(code)
  }
}
