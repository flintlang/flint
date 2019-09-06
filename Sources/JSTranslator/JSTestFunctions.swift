public class JSTestFunction: CustomStringConvertible {
  private let name: String
  private let statements: [JSNode]

  public init(name: String, statements: [JSNode]) {
    self.name = name
    self.statements = statements
  }

  public func getFuncName() -> String {
    return self.name
  }

  public var description: String {
    let functionSignature = "async function " + name + "(t_contract) { \n"
    var body = ""
    let closeToken = "}"
    body += "   let assertResult012 = {result: true, msg:\"\"} \n"
    body += "   console.log(chalk.yellow(\"Running \(name)\")) \n"
    for stm in statements {
      body += "   " + stm.description + "\n"
    }
    let procR = "   process_test_result(assertResult012, \"" + name + "\"" + ")" + "\n"
    return functionSignature + body + procR + closeToken
  }
}
