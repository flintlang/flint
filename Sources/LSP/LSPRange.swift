public struct LSPRange : Codable {
    private struct Position : Codable
    {
        private var Line : Int
        private var Character : Int
        
        init(lineNum: Int, columnNum: Int) {
            Line = lineNum
            Character = columnNum
        }
    }
    
    private var Start : Position
    private var End : Position
    
    init(startLineNum: Int, startColumNum: Int, endLineNum: Int, endColumnNum: Int) {
        Start = Position(lineNum: startLineNum, columnNum: startColumNum)
        End = Position(lineNum: endLineNum, columnNum: endColumnNum)
    }
}
