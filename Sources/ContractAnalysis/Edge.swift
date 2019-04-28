public struct Edge {
    let StartVertex: String
    let EndVertex: String
    let Label: String

    init(startVertex: String, endVertex: String, label: String) {
        StartVertex = startVertex
	    EndVertex = endVertex
        Label = label
    }
}
