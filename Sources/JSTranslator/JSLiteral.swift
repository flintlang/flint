public enum JSLiteral : CustomStringConvertible {
   case Integer(Int)
    
    public var description: String {
        switch (self) {
        case .Integer(let i):
            return i.description
        }
    }
}
