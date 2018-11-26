/*
 * Welcome to the Swift Language Server.
 *
 * Copyright (c) Kiad Studios, LLC. All rights reserved.
 * Licensed under the MIT License. See License in the project root for license information.
 */

import Foundation

import Commander
import JSONLib
import LanguageServerProtocol

import AST
import Compiler
import struct Diagnostic.Diagnostic
import class Diagnostic.DiagnosticPool
import struct Diagnostic.SourceContext

typealias FlintDiagnostic = Diagnostic

let languageServerLogCategory = "FlintLanguageServer"
let languageServerSettingsKey = "flint"

public enum LanguageServerError: Error {
    case toolchainNotFound(path: String)
    case swiftToolNotFound(path: String)
}

public final class SwiftLanguageServer<TransportType: MessageProtocol> {
    private var initialized: Bool = false
    private var canExit: Bool = false
    private var transport: TransportType

    private var lastTimeInterval: TimeInterval = 0

    // cached goodness... maybe abstract this.
    private var openDocuments: [DocumentUri: String] = [:]
    // Settings that are not updated until a workspaceDidChangeConfiguration request comes in.

    /// Initializes a new instance of a `SwiftLanguageServer`.
    public init(transport: TransportType) {
        self.transport = transport
    }

    /// Runs the language server. This waits for input via `source`, parses it, and then triggers
    /// the appropriately registered handler.
    public func run(source: InputOutputBuffer) {
        source.run { message in
            do {
                let command = try self.transport.translate(message: message)

                guard let response = try self.process(command: command) else { return nil }
                return try self.transport.translate(response: response)
            } catch LanguageServerError.toolchainNotFound(let path) {
                let params = ShowMessageParams(type: MessageType.error,
                                               message: "Unable to find the toolchain at: \(path)")
                let response = LanguageServerResponse.windowShowMessage(params: params)

                do {
                    return try self.transport.translate(response: response)
                } catch {
                    log("Error: unable to convert error message: %{public}@",
                        category: languageServerLogCategory, String(describing: error))
                }
            } catch {
                log("Error: unable to convert message into a command: %{public}@",
                    category: languageServerLogCategory, String(describing: error))
            }

            return nil
        }

        RunLoop.current.run()
    }

    public func diagnose(inputFiles: [URL]) throws -> [Diagnostic] {
        return try Compiler.diagnose(config: DiagnoserConfiguration(inputFiles: inputFiles))
    }

    private func process(command: LanguageServerCommand) throws -> LanguageServerResponse? {
        switch command {
        case .initialize(let requestId, let params):
            return try doInitialize(requestId, params)

        case .initialized:
            return try doInitialized()

        case .shutdown(let requestId):
            return try doShutdown(requestId)

        case .exit:
            doExit()

//      case .workspaceDidChangeConfiguration(let params):
//          try doWorkspaceDidChangeConfiguration(params)

        case .textDocumentDidSave(let params):
          return try doDocumentDidSave(params)

        case .textDocumentDidOpen(let params):
            return try doDocumentDidOpen(params)

        case .textDocumentDidChange(let params):
            return try doDocumentDidChange(params)

//        case .textDocumentCompletion(let requestId, let params):
//            return try doCompletion(requestId, params)
//
//        case .textDocumentHover(let requestId, let params):
//            return try doHover(requestId, params)
//
//        case .textDocumentDefinition(let requestId, let params):
//            return try doDefinition(requestId, params)
//
//        case .textDocumentSignatureHelp(let requestId, let params):
//            return try doSignatureHelp(requestId, params)
        default: throw "command is not supported: \(command)"
        }

        return nil
    }

    private func doShutdown(_ requestId: RequestId) throws -> LanguageServerResponse {
        canExit = true
        return .shutdown(requestId: requestId)
    }

    private func doExit() {
        exit(canExit ? 0 : 1)
    }

    private func doDocumentDidOpen(_ params: DidOpenTextDocumentParams) throws -> LanguageServerResponse {
        return doCompile(inputFile: params.textDocument.uri)
    }

    private func doDocumentDidChange(_ params: DidChangeTextDocumentParams) throws -> LanguageServerResponse? {
        // Saving the date of the change in shared state
        let date = Date().timeIntervalSince1970
        lastTimeInterval = date

        // Waiting for other changes to the document to occur, we are in async context here
        sleep(2)

        // Checking if other changes have occured in the meantime
        if lastTimeInterval == date {
            let originalFile = params.textDocument.uri
            let sourceCode = params.contentChanges[0].text
            return doCompile(originalFile: originalFile, sourceCode: sourceCode)
        }

        return nil
    }

    private func doDocumentDidSave(_ params: DidSaveTextDocumentParams) throws -> LanguageServerResponse {
      return doCompile(inputFile: params.textDocument.uri)
    }

    private func doInitialize(_ requestId: RequestId, _ params: InitializeParams) throws -> LanguageServerResponse {
        var capabilities = ServerCapabilities()
        capabilities.textDocumentSync = .kind(.full)
        // TODO(ethan), uncomment the cases once they are implemented
        // capabilities.hoverProvider = true
        // capabilities.completionProvider = CompletionOptions(resolveProvider: nil, triggerCharacters: ["."])
        // capabilities.definitionProvider = true
        // capabilities.signatureHelpProvider = SignatureHelpOptions(triggerCharacters: ["("])
        // capabilities.referencesProvider = true
        // capabilities.documentHighlightProvider = true
        // capabilities.documentSymbolProvider = true
        // capabilities.workspaceSymbolProvider = true
        // capabilities.codeActionProvider = true
        // capabilities.codeLensProvider = CodeLensOptions(resolveProvider: false)
        // capabilities.documentFormattingProvider = true
        // capabilities.documentRangeFormattingProvider = true
        // capabilities.documentOnTypeFormattingProvider =
        //     DocumentOnTypeFormattingOptions(firstTriggerCharacter: "{", moreTriggerCharacter: nil)
        // capabilities.renameProvider = true
        // capabilities.documentLinkProvider = DocumentLinkOptions(resolveProvider: false)
        // try configureWorkspace(settings: nil)

        return .initialize(requestId: requestId, result: InitializeResult(capabilities: capabilities))
    }

    private func doInitialized() throws -> LanguageServerResponse? {
      let params = ShowMessageParams(type: .info, message: "LSP initialized")
      return .windowShowMessage(params: params)
    }

    private func doCompile(originalFile: DocumentUri, temporaryFile: String) -> LanguageServerResponse {
        var flintDiagnostics: [FlintDiagnostic]!
        do {
            let config = DiagnoserConfiguration(inputFiles: [URL(string: temporaryFile)!])
            flintDiagnostics = try Compiler.diagnose(config: config)
        } catch let err {
            flintDiagnostics = [Diagnostic(severity: .error,
                                           sourceLocation: nil,
                                           message: err.localizedDescription)]
        }

        let lspDiagnostic = flintDiagnostics.compactMap(translateDiagnostic)
        let params = PublishDiagnosticsParams(uri: originalFile, diagnostics: lspDiagnostic)

        return .textDocumentPublishDiagnostics(params: params)
    }

    private func doCompile(originalFile: DocumentUri, sourceCode: String) -> LanguageServerResponse {
        let url = URL(fileURLWithPath: originalFile)
        let filename = url.lastPathComponent + "-" + UUID().uuidString

        let tempSourceFile = (NSTemporaryDirectory() as NSString).appendingPathComponent(filename)
        let fileManager = FileManager.default
        fileManager.createFile(atPath: tempSourceFile, contents: sourceCode.data(using: .utf8), attributes: nil)

        let response = doCompile(originalFile: originalFile, temporaryFile: "file://" + tempSourceFile)

        do {
            try fileManager.removeItem(atPath: tempSourceFile)
        } catch {
            log("Error: could not remove temporary file", category: languageServerLogCategory)
        }

        return response
    }

    private func doCompile(inputFile: DocumentUri) -> LanguageServerResponse {
        return doCompile(originalFile: inputFile, temporaryFile: inputFile)
    }

    func kind(_ value: String?) -> CompletionItemKind {
        switch value ?? "" {
        case "source.lang.swift.decl.function.free": return .function
        case "source.lang.swift.decl.function.method.instance": return .method
        case "source.lang.swift.decl.function.method.static": return .method
        case "source.lang.swift.decl.function.constructor": return .constructor
        case "source.lang.swift.decl.function.destructor": return .constructor
        case "source.lang.swift.decl.function.operator": return .function
        case "source.lang.swift.decl.function.subscript": return .property
        case "source.lang.swift.decl.function.accessor.getter": return .property
        case "source.lang.swift.decl.function.accessor.setter": return .property
        case "source.lang.swift.decl.class": return .`class`
        case "source.lang.swift.decl.struct": return .`class`
        case "source.lang.swift.decl.enum": return .`enum`
        case "source.lang.swift.decl.enumelement": return .property
        case "source.lang.swift.decl.protocol": return .interface
        case "source.lang.swift.decl.typealias": return .reference
        case "source.lang.swift.decl.var.global": return .variable
        case "source.lang.swift.decl.var.instance": return .variable
        case "source.lang.swift.decl.var.static": return .variable
        case "source.lang.swift.decl.var.local": return .variable

        case "source.lang.swift.ref.function.free": return .function
        case "source.lang.swift.ref.function.method.instance": return .method
        case "source.lang.swift.ref.function.method.static": return .method
        case "source.lang.swift.ref.function.constructor": return .constructor
        case "source.lang.swift.ref.function.destructor": return .constructor
        case "source.lang.swift.ref.function.operator": return .function
        case "source.lang.swift.ref.function.subscript": return .property
        case "source.lang.swift.ref.function.accessor.getter": return .property
        case "source.lang.swift.ref.function.accessor.setter": return .property
        case "source.lang.swift.ref.class": return .`class`
        case "source.lang.swift.ref.struct": return .`class`
        case "source.lang.swift.ref.enum": return .`enum`
        case "source.lang.swift.ref.enumelement": return .property
        case "source.lang.swift.ref.protocol": return .interface
        case "source.lang.swift.ref.typealias": return .reference
        case "source.lang.swift.ref.var.global": return .variable
        case "source.lang.swift.ref.var.instance": return .variable
        case "source.lang.swift.ref.var.static": return .variable
        case "source.lang.swift.ref.var.local": return .variable

        case "source.lang.swift.decl.extension.struct": return .`class`
        case "source.lang.swift.decl.extension.class": return .`class`
        case "source.lang.swift.decl.extension.enum": return .`enum`
        default: return .text
        }
    }
}
