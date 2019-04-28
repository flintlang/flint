import AST
public func produce_graphs_from_ev(ev : Environment) -> [Graph] {
    var graphs : [Graph] = []
    for c in ev.declaredContracts {
        let name = c.name
        
        // search init function to find starting state
        /*
        let initDecBody = ev.types[name]!.publicInitializer!.body
        for s in initDecBody {
            switch s {
            case .becomeStatement (let bStat):
                switch (bStat.expression)
                {
                case .identifier(let id):
                    startingState = id.name
                default:
                    break
                }
            default:
                break
            }
        }
        */
        
        // process the functions to get the state transitions (edges)
        
        let funcs = ev.types[name]!.functions

	    var edges:[Edge] = []
        
        for (funcName, symtab) in funcs {
            let funcInfo = symtab[0]
	        let funcDec = funcInfo.declaration
	        let funcBody = funcDec.body
	        let typeStates = funcInfo.typeStates
            var endState = ""

	    // go through the function body
	    // if there any become statements then process
            for s in funcBody {
	            switch s {
		        case .becomeStatement (let bStat):
                    switch (bStat.expression) {
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
                    let newEdge = Edge(startVertex: startingState.name, endVertex: endState, label: funcName)
                    edges.append(newEdge)
                }
            }

       }
        
        let tsGraph = Graph(edges: edges)
        graphs.append(tsGraph)
          
    }
    return graphs
}

public func produce_dot_graph(graph: Graph) -> String {
    var dotGraph = "digraph { \n graph [pad=\"0.5\", nodesep=\"1\", ranksep=\"2\"]; \n"
    for edge in graph.Edges {
        // for each of the edges I want to
        let newEdge = edge.StartVertex + " -> " + edge.EndVertex + " [label=" + "\"\(edge.Label)\"];\n"
        dotGraph += newEdge
    }
    dotGraph += "}"
    
    return dotGraph
}
