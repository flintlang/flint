import Diagnostic
import Foundation

public class Diagnostics {
  public static var diagnostics: [Diagnostic] = []
  public static var sourceContext: SourceContext?

  static func add(_ diagnostics: Diagnostic...) {
    self.diagnostics.append(contentsOf: diagnostics)
  }

  public static func display() {
    try! print(DiagnosticsFormatter(diagnostics: diagnostics,
                                    sourceContext: sourceContext!).rendered())
  }

  static func displayAndExit(code: Int32 = 1) -> Never {
    display()
    return exit(code)
  }
}
