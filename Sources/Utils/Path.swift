import Foundation
import Symbolic

public class Path {
  // Get absolute URL path from a path relative to the flint folder location
  public static func getFullUrl(path: String) -> URL {

    /*
    guard var url: URL = SymbolInfo(address: #dsohandle)?.filename else {
    fatalError("Unable to get SymbolInfo for \(#dsohandle)")
    }
    url.deleteLastPathComponent()
    url.deleteLastPathComponent()
    url.deleteLastPathComponent()
    url.deleteLastPathComponent()*/

    //var url: URL = URL(fileURLWithPath: "/Users/matteo/Documents/flint")

    guard let flintPath: String = ProcessInfo.processInfo.environment["FLINTPATH"] else {
      fatalError("No FLINTPATH environment variable set")
    }
    var url: URL = URL(fileURLWithPath: flintPath)
    url.appendPathComponent(path)
    //guard FileManager.default.fileExists(atPath: url.path) else {
    //  fatalError("Unable to find \(url.absoluteString)")
    //}

    return url
  }
}
