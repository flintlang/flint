import XCTest
@testable import SemanticAnalyzer
import Cuckoo
@testable import AST
import Diagnostic
import Source
import Lexer

final class SemanticAnalyzerTests: XCTestCase {

  // MARK: Fixture -
  private struct Fixture {
    let pass = SemanticAnalyzer()
  }

  // MARK: Mocking Utilities
  private func buildPassContext(stubEnvironment: (MockEnvironment.Stubbing) -> Void) -> ASTPassContext {
    var context = ASTPassContext()
    let environment = MockEnvironment()
    stub(environment, block: stubEnvironment)
    context.environment = environment
    return context
  }

  // MARK: Dummies
  func buildDummyFunctionDeclaration() -> FunctionDeclaration {
    return FunctionDeclaration(
      signature: FunctionSignatureDeclaration(
        funcToken: .DUMMY,
        attributes: [],
        modifiers: [],
        identifier: .DUMMY,
        parameters: [],
        closeBracketToken: .DUMMY,
        resultType: nil),
      body: [],
      closeBraceToken: .DUMMY)
  }

  func buildDummySpecialInformation() -> SpecialInformation {
    let declaration = SpecialDeclaration(buildDummyFunctionDeclaration())
    return SpecialInformation(declaration: declaration, callerProtections: [], isSignature: false)
  }

  func buildDummyFunctionInformation() -> FunctionInformation {
    return FunctionInformation(declaration: buildDummyFunctionDeclaration(),
                               typeStates: [],
                               callerProtections: [],
                               isMutating: false,
                               isSignature: false)
  }

  func buildDummyContractDeclaration() -> ContractDeclaration {
    return ContractDeclaration(contractToken: .DUMMY, identifier: .DUMMY, conformances: [], states: [], members: [])
  }

  // MARK: postProcess TopLevelModule -
  // Emit a diagnostic when there are no contracts declared in the top level module
  func testTopLevelModule_noDeclaredContract_diagnosticEmitted() {
    // Given
    let f = Fixture()
    let module = TopLevelModule(declarations: [])
    let passContext = buildPassContext { (environment) in
      environment.hasDeclaredContract().thenReturn(false)
    }

    // When
    let result = f.pass.postProcess(topLevelModule: module, passContext: passContext)

    // Then
    XCTAssertEqual(result.diagnostics.count, 1)
    XCTAssertEqual(result.diagnostics.first!, Diagnostic.contractNotDeclaredInModule())
  }

  // Emit a diagnostic when there is no public fallback function but there are private ones
  func testTopLevelModule_publicFallbackNotUnqiueButHasPrivate_diagnosticEmitted() {
    // Given
    let f = Fixture()
    let contract = buildDummyContractDeclaration()
    let passContext = buildPassContext { (environment) in
      environment.publicFallback(forContract: equal(to: contract.identifier.name)).thenReturn(nil)
      environment.fallbacks(in: equal(to: contract.identifier.name)).thenReturn([buildDummySpecialInformation()])
    }
    var diagnostics: [Diagnostic] = []

    // When
    _ = f.pass.checkUniquePublicFallback(environment: passContext.environment!,
                                                  contractDeclaration: contract,
                                                  diagnostics: &diagnostics)

    // Then
    XCTAssertEqual(diagnostics.count, 1)
    XCTAssertEqual(diagnostics.first!,
                   Diagnostic.contractOnlyHasPrivateFallbacks(contractIdentifier: contract.identifier,
                                                              [buildDummySpecialInformation().declaration]))
  }

  // Do not emit a diagnostic when there are no public nor private fallback functions
  func testTopLevelModule_publicFallbackNotUniqueNoPrivate_noDiagnosticEmitted() {
    // Given
    let f = Fixture()
    let contract = buildDummyContractDeclaration()
    let passContext = buildPassContext { (environment) in
      environment.publicFallback(forContract: equal(to: contract.identifier.name)).thenReturn(nil)
      environment.fallbacks(in: equal(to: contract.identifier.name)).thenReturn([])
    }
    var diagnostics: [Diagnostic] = []

    // When
    _ = f.pass.checkUniquePublicFallback(environment: passContext.environment!,
                                             contractDeclaration: contract,
                                             diagnostics: &diagnostics)

    // Then
    XCTAssertEqual(diagnostics.count, 0)
  }

  // Emit a diagnostic when there is at least one undefined function in a contract
  func testTopLevelModule_contractHasUndefinedFunctions_diagnosticEmitted() {
    // Given
    let f = Fixture()
    let contract = buildDummyContractDeclaration()
    let passContext = buildPassContext { (environment) in
      environment.undefinedFunctions(in: equal(to: contract.identifier)).thenReturn([buildDummyFunctionInformation()])
    }
    var diagnostics: [Diagnostic] = []

    // When
    _ = f.pass.checkAllContractTraitFunctionsDefined(environment: passContext.environment!,
                                                         contractDeclaration: contract,
                                                         diagnostics: &diagnostics)

    // Then
    XCTAssertEqual(diagnostics.count, 1)
    XCTAssertEqual(diagnostics.first!,
                   Diagnostic.notImplementedFunctions([buildDummyFunctionInformation()], in: contract))
  }

  // Do not emit a diagnostic when there are no undefined functions in a contract
  func testTopLevelModule_contractHasNoUndefinedFunctions_noDiagnosticEmitted() {
    // Given
    let f = Fixture()
    let contract = buildDummyContractDeclaration()
    let passContext = buildPassContext { (environment) in
      environment.undefinedFunctions(in: equal(to: contract.identifier)).thenReturn([])
    }
    var diagnostics: [Diagnostic] = []

    // When
    _ = f.pass.checkAllContractTraitFunctionsDefined(environment: passContext.environment!,
                                                         contractDeclaration: contract,
                                                         diagnostics: &diagnostics)

    // Then
    XCTAssertEqual(diagnostics.count, 0)
  }

  // Emit a diagnostic when there is at least one undefined initializer in a contract
  func testTopLevelModule_contractHasUndefinedInitializers_diagnosticEmitted() {
    // Given
    let f = Fixture()
    let contract = buildDummyContractDeclaration()
    let passContext = buildPassContext { (environment) in
      environment.undefinedInitialisers(in: equal(to: contract.identifier)).thenReturn([buildDummySpecialInformation()])
    }
    var diagnostics: [Diagnostic] = []

    // When
    _ = f.pass.checkAllContractTraitInitializersDefined(environment: passContext.environment!,
                                                            contractDeclaration: contract,
                                                            diagnostics: &diagnostics)

    // Then
    XCTAssertEqual(diagnostics.count, 1)
    XCTAssertEqual(diagnostics.first!,
                   Diagnostic.notImplementedInitialiser([buildDummySpecialInformation()], in: contract))
  }

  // Do not emit a diagnostic when there are no undefined initializers in a contract
  func testTopLevelModule_contractHasNoUndefinedInitializers_noDiagnosticEmitted() {
    // Given
    let f = Fixture()
    let contract = buildDummyContractDeclaration()
    let passContext = buildPassContext { (environment) in
      environment.undefinedInitialisers(in: equal(to: contract.identifier)).thenReturn([])
    }
    var diagnostics: [Diagnostic] = []

    // When
    _ = f.pass.checkAllContractTraitInitializersDefined(environment: passContext.environment!,
                                                            contractDeclaration: contract,
                                                            diagnostics: &diagnostics)

    // Then
    XCTAssertEqual(diagnostics.count, 0)
  }

  // Ensure that the contract declaration check functions are made
  // We can't currently test this as this requires some planning and refactoring for the SemanticAnalyzer.
  // The checking functions should probably be part of a checking unit that returns a result object that is later
  // combined (a la ASTPassResult) rather than taking inout parameters. Once this is implemented, they can be stubbed
  // using Cuckoo and dependency-injected in the tests.
  // Since the whole SemanticAnalyzer consiststs of a series of checks and corresponding diagnostics being output,
  // common elements can probably be factored out to prevent duplication.
//  func testTopLevelModule_contractDeclarations_callsFunctionsToCheckContractDeclaration() {
//    // To be implemented
//  }

  static var allTests = [
    ("testTopLevelModule_noDeclaredContract_diagnosticEmitted",
     testTopLevelModule_noDeclaredContract_diagnosticEmitted),
    ("testTopLevelModule_publicFallbackNotUnqiueButHasPrivate_diagnosticEmitted",
     testTopLevelModule_publicFallbackNotUnqiueButHasPrivate_diagnosticEmitted),
    ("testTopLevelModule_publicFallbackNotUniqueNoPrivate_noDiagnosticEmitted",
     testTopLevelModule_publicFallbackNotUniqueNoPrivate_noDiagnosticEmitted),
    ("testTopLevelModule_contractHasUndefinedFunctions_diagnosticEmitted",
     testTopLevelModule_contractHasUndefinedFunctions_diagnosticEmitted),
    ("testTopLevelModule_contractHasNoUndefinedFunctions_noDiagnosticEmitted",
     testTopLevelModule_contractHasNoUndefinedFunctions_noDiagnosticEmitted),
    ("testTopLevelModule_contractHasUndefinedInitializers_diagnosticEmitted",
     testTopLevelModule_contractHasUndefinedInitializers_diagnosticEmitted),
    ("testTopLevelModule_contractHasNoUndefinedInitializers_noDiagnosticEmitted",
     testTopLevelModule_contractHasNoUndefinedInitializers_noDiagnosticEmitted)
  ]
}
