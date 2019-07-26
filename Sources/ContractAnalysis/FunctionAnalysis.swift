import AST

public class FunctionAnalysis {

  public init() {}

  public func analyse(ev: Environment) -> [FunctionGraph] {

    var graphs: [FunctionGraph] = []
    for c in ev.declaredContracts {
      let name = c.name

      let funcs = ev.types[name]!.functions

      let graph: FunctionGraph = FunctionGraph()

      for (funcName, symtab) in funcs {
        let funcInfo = symtab[0]
        let isPayble = funcInfo.declaration.isPayable
        let isMutating = funcInfo.declaration.isMutating
        let funcBody = funcInfo.declaration.body
        var sendMoney: Bool = false

        for s in funcBody {
          switch s {
          case .expression(let ex):
            switch ex {
            case .functionCall(let fc):
              let fName = fc.identifier.name
              if fName == "send" {
                sendMoney = true
              }
            default:
              continue
            }
          default:
            continue
          }
        }

        let edge: FunctionEdge = FunctionEdge(name: funcName, payable: isPayble, sendMoney: sendMoney,
                                              isMutating: isMutating)
        graph.addEdge(edge: edge)
      }

      graphs.append(graph)

    }
    return graphs

  }
}
