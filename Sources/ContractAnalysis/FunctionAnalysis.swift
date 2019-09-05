import AST

public class FunctionAnalysis {

  public init() {}

  public func analyse(environment: Environment) -> [FunctionGraph] {

    var graphs: [FunctionGraph] = []
    for contract in environment.declaredContracts {
      let name = contract.name
      let functions = environment.types[name]!.functions
      let graph: FunctionGraph = FunctionGraph()

      for (functionName, symtab) in functions {
        let functionInfo = symtab[0]
        let isPayble = functionInfo.declaration.isPayable
        let isMutating = functionInfo.declaration.isMutating
        let functionBody = functionInfo.declaration.body
        var sendMoney: Bool = false

        for statement in functionBody {
          switch statement {
          case .expression(let ex):
            switch ex {
            case .functionCall(let functionCall):
              let functionName = functionCall.identifier.name
              if functionName == "send" {
                sendMoney = true
              }
            default:
              continue
            }
          default:
            continue
          }
        }

        let edge: FunctionEdge = FunctionEdge(name: functionName,
                                              payable: isPayble,
                                              sendMoney: sendMoney,
                                              isMutating: isMutating)
        graph.addEdge(edge: edge)
      }

      graphs.append(graph)

    }
    return graphs

  }
}
