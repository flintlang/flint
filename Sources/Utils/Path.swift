import Foundation
import Symbolic

public class Path {
    // Get absolute URL path from a path relative to the flint folder location
    public static func getFullUrl(path: String) -> URL { 
    
        guard var url: URL = SymbolInfo(address: #dsohandle)?.filename else {
        fatalError("Unable to get SymbolInfo for \(#dsohandle)")
        }
        url.deleteLastPathComponent()
        url.deleteLastPathComponent()
        url.deleteLastPathComponent()
        url.deleteLastPathComponent()

        //var url: URL = URL(fileURLWithPath: "/home/matteo/Documents/flint_build_attempt2/flint")
        url.appendPathComponent(path)
        guard FileManager.default.fileExists(atPath: url.path) else {
            fatalError("Unable to find stdlib.")
        }
        
        return url
    }
}