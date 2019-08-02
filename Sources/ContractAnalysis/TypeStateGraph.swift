public struct Graph {
  let Edges: [Edge]
  let StartingState: String

  init(edges: [Edge], startingState: String) {
    Edges = edges
    StartingState = startingState
  }
}
