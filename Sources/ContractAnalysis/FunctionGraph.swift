public class FunctionGraph {
  var edges: [FunctionEdge] = []

  public init() {}

  public func addEdge(edge: FunctionEdge) {
    edges.append(edge)
  }

  public func produce_dot_graph() -> String {
    var dot_file = "digraph G { \n    node [shape=box] \n"

    for e in edges {
      dot_file += "     " + produceEdge(edge: e) + "\n"
    }

    dot_file += "}"
    return dot_file
  }

  private func produceEdge(edge: FunctionEdge) -> String {
    if edge.Payable && edge.SendMoney {
      return "\(edge.Name) [color=yellow, style=\"striped, bold\", fillcolor=\"red:green\"]"
    } else if edge.Payable {
      return "\(edge.Name) [color=yellow, style=\"filled, bold\", fillcolor=green]"
    } else if edge.SendMoney {
      return "\(edge.Name) [color=yellow, style=\"filled, bold\", fillcolor=red]"
    } else if edge.IsMutating {
      return "\(edge.Name) [color=yellow, style=bold]"
    } else {
      return "\(edge.Name) [color=blue, style=bold]"
    }
  }
}
