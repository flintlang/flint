import Foundation
import Symbolic

public class Path {
  public static var nodeLocation: URL {
    #if os(macOS)
    let nodeLocation = "/usr/local/bin/node"
    #else
    let nodeLocation = "/usr/bin/node"
    #endif
    return URL(fileURLWithPath: nodeLocation)
  }
  
  public static var monoLocation: URL {
    #if os(macOS)
    let monoLocation = "/Library/Frameworks/Mono.framework/Versions/Current/Commands/mono"
    #else
    let monoLocation = "/usr/bin/mono"
    #endif
    return URL(fileURLWithPath: monoLocation)
  }
  
  public static var boogieLocation: URL {
    return Path.getFullUrl(path: "boogie/Binaries/Boogie.exe")
  }
  
  public static var symbooglixLocation: URL {
    return Path.getFullUrl(path: "symbooglix/src/SymbooglixDriver/bin/Release/sbx.exe")
  }
  
  // Get absolute URL path from a path relative to the flint folder location
  public static func getFullUrl(path: String) -> URL {
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
