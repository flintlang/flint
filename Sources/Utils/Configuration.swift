//
//  Config.swift
//  Utils
//
//  Created on 02/09/2019.
//

import Foundation

private struct ConfigurationFile: Codable {
  let nodePath: String
  let monoPath: String
  let solcPath: String
  let boogiePath: String
  let symbooglixPath: String
  let ethereumAddress: String
}

public class Configuration {
  // Singleton configuration instance
  private static var configuration: Configuration = Configuration()
  private var configurationFile: ConfigurationFile

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

  private static func generateDefaultConfigurationFile(file: URL) {
    #if os(macOS)
    let nodePath = "/usr/local/bin/node"
    let monoPath = "/Library/Frameworks/Mono.framework/Versions/Current/Commands/mono"
    let solcPath = "/usr/local/bin/solc"
    #else
    let nodePath = "/usr/bin/node"
    let monoPath = "/usr/bin/mono"
    let solcPath = "/usr/bin/solc"
    #endif
    let boogiePath = Path.getFullUrl(path: "boogie/Binaries/Boogie.exe").path
    let symbooglixPath = Path.getFullUrl(path: "symbooglix/src/SymbooglixDriver/bin/Release/sbx.exe").path
    let ethereumAddress = "ADDRESS_NOT_SET"
    let defaultConfigurationFile = ConfigurationFile(nodePath: nodePath,
                                                     monoPath: monoPath,
                                                     solcPath: solcPath,
                                                     boogiePath: boogiePath,
                                                     symbooglixPath: symbooglixPath,
                                                     ethereumAddress: ethereumAddress)
    let encoder = JSONEncoder()
    encoder.outputFormatting = .prettyPrinted
    let jsonConfigurationData: Data = try! encoder.encode(defaultConfigurationFile)
    let jsonText = String(data: jsonConfigurationData, encoding: .utf8)!
      .replacingOccurrences(of: "\\/", with: "/") // Remove escaping backslashes in the config file...not very elegant
      .appending("\n")
    try! jsonText.write(to: file, atomically: true, encoding: .utf8)
  }

  /// Read json configuration file specifying the paths of flint's dependencies, use defaults if they are empty.
  private init(file: URL = Path.getFullUrl(path: "flint_config.json")) {
    if !FileManager.default.fileExists(atPath: file.path) {
      print("Warning: configuration file not found, generating default config file at \(file.path)")
      Configuration.generateDefaultConfigurationFile(file: file)
    }
    guard let configurationFile = try? JSONDecoder().decode(ConfigurationFile.self, from: Data(contentsOf: file)) else {
      print("""
        Error: failed to parse \(file.path)
        Are you missing some options in your configuration file?
        """)
      exit(EXIT_FAILURE)
    }
    self.configurationFile = configurationFile
  }
}
