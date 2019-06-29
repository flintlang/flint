public enum JSLiteral : CustomStringConvertible {
   case Integer(Int)
   case String(String)
    
    public var description: String {
        switch (self) {
        case .Integer(let i):
            return i.description
        case .String(let s):
            return "\"" + s + "\""
        }
    }
}
