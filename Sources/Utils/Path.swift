import Foundation
import Symbolic

public class Path {
  // Get absolute URL path from a path relative to flint's folder location
  public static func getFullUrl(path: String) -> URL {
    return FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent(".flint")
      .appendingPathComponent(path)
  }
}
