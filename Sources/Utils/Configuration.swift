//
//  Config.swift
//  Utils
//
//  Created on 02/09/2019.
//

import Foundation

private struct ConfigurationFile {
  #if os(macOS)
  var nodePath = "/usr/local/bin/node"
  var monoPath = "/Library/Frameworks/Mono.framework/Versions/Current/Commands/mono"
  var solcPath = "/usr/local/bin/solc"
  #else
  var nodePath = "/usr/bin/node"
  var monoPath = "/usr/bin/mono"
  var solcPath = "/usr/bin/solc"
  #endif
  var boogiePath = Path.getFullUrl(path: "boogie/Binaries/Boogie.exe").path
  var symbooglixPath = Path.getFullUrl(path: "symbooglix/src/SymbooglixDriver/bin/Release/sbx.exe").path
  var ethereumAddress = "ADDRESS_NOT_SET"
}

public class Configuration {
  // Singleton configuration instance
  private static var configuration: Configuration = Configuration()
  private var configurationFile: ConfigurationFile = ConfigurationFile()

  public static var nodeLocation: URL {
    return URL(fileURLWithPath: configuration.configurationFile.nodePath)
  }

  public static var monoLocation: URL {
    return URL(fileURLWithPath: configuration.configurationFile.monoPath)
  }

  public static var boogieLocation: URL {
    return URL(fileURLWithPath: configuration.configurationFile.boogiePath)
  }

  public static var symbooglixLocation: URL {
    return URL(fileURLWithPath: configuration.configurationFile.symbooglixPath)
  }

  public static var solcLocation: URL {
    return URL(fileURLWithPath: configuration.configurationFile.solcPath)
  }

  public static var ethereumAddress: String {
    return configuration.configurationFile.ethereumAddress
  }

  /// Read json configuration file specifying the paths of flint's dependencies, use defaults if they are empty.
  public init(file: URL = Path.getFullUrl(path: "flint_config.json")) {
    guard FileManager.default.fileExists(atPath: file.path) else {
      print("Warning: config file not found, using default paths for flint's dependencies")
      return
    }

    guard
      let fileData = try? Data(contentsOf: file),
      let json =  try? JSONSerialization.jsonObject(with: fileData, options: []) as? [String: String],
      let nodePath = json["node"],
      let monoPath = json["mono"],
      let boogiePath = json["boogie"],
      let symbooglixPath = json["symbooglix"],
      let solcPath = json["solc"],
      let ethereumAddress = json["ethereumAddress"] else {
        print("Error: failed to parse config file \(file.path)")
        print("Are you missing some options in your config file?")
        exit(EXIT_FAILURE)
    }

    configurationFile.nodePath = nodePath.isEmpty ? configurationFile.nodePath : nodePath
    configurationFile.monoPath = monoPath.isEmpty ? configurationFile.monoPath : monoPath
    configurationFile.boogiePath = boogiePath.isEmpty ? configurationFile.boogiePath : boogiePath
    configurationFile.symbooglixPath = symbooglixPath.isEmpty ? configurationFile.symbooglixPath : symbooglixPath
    configurationFile.solcPath = solcPath.isEmpty ? configurationFile.solcPath : solcPath
    configurationFile.ethereumAddress = ethereumAddress.isEmpty ? configurationFile.ethereumAddress : ethereumAddress
  }
}
