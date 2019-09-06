import AST

public func produceGraphsFromEnvironment(environment: Environment) -> [Graph] {
  var graphs: [Graph] = []
  for contract in environment.declaredContracts {
    let name = contract.name

    var startingState = ""

    let initalizerBody = environment.types[name]!.publicInitializer!.body
    for statement in initalizerBody {
      switch statement {
      case .becomeStatement(let becomeStatement):
        switch becomeStatement.expression {
        case .identifier(let id):
          startingState = id.name
        default:
          break
        }
      default:
        break
      }
    }

    // process the functions to get the state transitions (edges)
    let functions = environment.types[name]!.functions
    var edges: [Edge] = []

    for (functionName, symtab) in functions {
      let functionInformation = symtab[0]
      let functionDeclaration = functionInformation.declaration
      let functionBody = functionDeclaration.body
      let typeStates = functionInformation.typeStates
      var endState = ""

      // go through the function body
      // if there any become statements then process
      for statement in functionBody {
        switch statement {
        case .becomeStatement(let becomeStatement):
          switch becomeStatement.expression {
          case .identifier(let id):
            endState = id.name
          default:
            break
          }
        default: break
        }
      }

      if endState != "" {
        for startingState in typeStates {
          let newEdge = Edge(startVertex: startingState.name, endVertex: endState, label: functionName)
          edges.append(newEdge)
        }
      }

    }

    let tsGraph = Graph(edges: edges, startingState: startingState)
    graphs.append(tsGraph)

  }
  return graphs
}

public func produceDotGraph(graph: Graph) -> String {
  var dotGraph = "digraph { \n graph [pad=\"0.5\", nodesep=\"1\", ranksep=\"2\"]; \n"
  dotGraph += "\(graph.StartingState) [style=bold, color=purple] \n"
  for edge in graph.Edges {
    let newEdge = edge.StartVertex + " -> " + edge.EndVertex + " [label=" + "\"\(edge.Label)\"];\n"
    dotGraph += newEdge
  }
  dotGraph += "}"

  return dotGraph
}
