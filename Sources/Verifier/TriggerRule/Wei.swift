import AST
import Source
import Utils

import Foundation

extension TriggerRule {
    static func weiCreationImplicit() -> Rule<Parameter> {
      let isParameterWeiImplicit: ((Parameter, Context, ExtraType) -> Bool) = { parameter, _, _ in
        if case .userDefinedType("Wei") = parameter.type.rawType,
          parameter.isImplicit {
          return true
        }
        return false
      }

      let updateReceivedAndTotalValue: ((Parameter, Context, ExtraType) -> ([BStatement], [BStatement])) = { parameter, _, extra in
        guard let implicitWei = extra["normalised_parameter_name"] else {
          print("Could not process trigger \"isParameterWeiImplicit\", couldn't find normalised_parameter_name in extra")
          fatalError()
        }

        // totalValue += rawValue_Wei[implicitWei]
        // sentValue += rawValue_Wei[implicitWei]

        return ([], [.assignment(.identifier("totalValue_Wei"),
                            .add(.identifier("totalValue_Wei"), .mapRead(.identifier("rawValue_Wei"),
                                                                         .identifier(implicitWei as! String))),
                            TranslationInformation(sourceLocation: parameter.sourceLocation)),
                     .assignment(.identifier("receivedValue_Wei"),
                            .add(.identifier("receivedValue_Wei"), .mapRead(.identifier("rawValue_Wei"),
                                                                         .identifier(implicitWei as! String))),
                            TranslationInformation(sourceLocation: parameter.sourceLocation))])
      }
      return Rule<Parameter>(condition: isParameterWeiImplicit,
                             rule: updateReceivedAndTotalValue,
                             mutates: ["totalValue_Wei", "receivedValue_Wei"])
    }

    static func weiCreationUnsafeInit() -> Rule<FunctionDeclaration> {
      let isWeiCreation: ((FunctionDeclaration, Context, ExtraType) -> Bool) = { functionDeclaration, c, _ in
        if functionDeclaration.explicitParameters.count == 0 {
          return false
        }

        let firstArgumentType = functionDeclaration.explicitParameters[0].type.rawType
        let firstArgumentIsTypeInt: Bool
        if case .basicType(.int) = firstArgumentType {
          firstArgumentIsTypeInt = true
        } else {
          firstArgumentIsTypeInt = false
        }

        return functionDeclaration.name == "init" && c.enclosingType == "Wei" &&
          functionDeclaration.explicitParameters.count == 1 && firstArgumentIsTypeInt
      }

      let updateReceivedAndTotalValue: ((FunctionDeclaration, Context, ExtraType) -> ([BStatement], [BStatement])) = { functionDeclaration, _, _ in
        return ([], [.assignment(.identifier("totalValue_Wei"),
                            .add(.identifier("totalValue_Wei"), .identifier("unsafeRawValue_initInt_Wei")),
                            TranslationInformation(sourceLocation: functionDeclaration.sourceLocation))])
      }

      return Rule<FunctionDeclaration>(condition: isWeiCreation,
                                       rule: updateReceivedAndTotalValue,
                                       mutates: ["totalValue_Wei"])
    }

    static func weiDirectAssignment() -> Rule<BinaryExpression> {
      let isWeiAssignment: ((BinaryExpression, Context, ExtraType) -> Bool) = { binaryExpression, c, e in
        // is assignment? - check not assigning to fresh variable
        // is type of lhs + rhs wei?

        let assignmentType = c.environment.type(of: binaryExpression.lhs,
                                                enclosingType: c.enclosingType,
                                                scopeContext: c.scopeContext)
        if case .variableDeclaration = binaryExpression.lhs {
          return false
        }
        if let fname = (e["enclosing_function"]), (fname as! String) == "init" {
          return false
        }

        if case .equal = binaryExpression.opToken,
          case .userDefinedType("Wei") = assignmentType {
          // Can assume rhsType == lhsType, otherwise would have failed semantic check
          return true
        }
        return false
      }

      let updateTotalValue: ((BinaryExpression, Context, ExtraType) -> ([BStatement], [BStatement])) = { binaryExpression, c, e in
        // totalValue -= totalValue_Wei[lhs]
        let lhsBExpr = e["lhs_translated_expression"] as! BExpression
        let update = BStatement.assignment(.identifier("totalValue_Wei"),
                                           .subtract(.identifier("totalValue_Wei"), lhsBExpr),
                                           TranslationInformation(sourceLocation: binaryExpression.sourceLocation))
        return ([update], [])
      }
      return Rule<BinaryExpression>(condition: isWeiAssignment,
                                    rule: updateTotalValue,
                                    mutates: ["totalValue_Wei"])
    }

    static func weiSetupInvariantOnInit() -> Rule<FunctionDeclaration> {
      let isContractInit: ((FunctionDeclaration, Context, ExtraType) -> Bool) = { function, c, e in
        return function.identifier.name == "init" && c.environment.isContractDeclared(c.enclosingType)
      }
      let updateVariables: ((FunctionDeclaration, Context, ExtraType) -> ([BStatement], [BStatement])) = { function, c, e in
        let mark = TranslationInformation(sourceLocation: function.sourceLocation)
        var preStmts = [BStatement]()
        preStmts.append(.assignment(.identifier("totalValue_Wei"), .integer(0), mark))
        preStmts.append(.assignment(.identifier("sentValue_Wei"), .integer(0), mark))
        preStmts.append(.assignment(.identifier("receivedValue_Wei"), .integer(0), mark))
        return (preStmts, [])
      }

      return Rule<FunctionDeclaration>(condition: isContractInit,
                                       rule: updateVariables,
                                       mutates: [
                                         "totalValue_Wei",
                                         "sentValue_Wei",
                                         "receivedValue_Wei"
                                       ])
    }

    static func weiInvariants() -> [BIRInvariant] {
      // TODO: Pass in SourceLocation - for Wei - determine the syntax needed for this
      let source = SourceLocation(line: 2, column: 3, length: 51,
                                  file: Path.getFullUrl(path: "stdlib/WeiAccounting.inv"),
                                  isFromStdlib: false)
      return [(BIRInvariant(expression: .equals(.identifier("totalValue_Wei"),
                                                .subtract(.identifier("receivedValue_Wei"),
                                                          .identifier("sentValue_Wei"))),
                            ti: TranslationInformation(sourceLocation: source, triggerName: "WeiAccounting")))]
    }

    static func weiMetaVariables() -> [BVariableDeclaration] {
      var declarations = [BVariableDeclaration]()
      // Wei Accounting
      declarations.append(BVariableDeclaration(name: "totalValue_Wei",
                                               rawName: "totalValue_Wei",
                                               type: .int))
      declarations.append(BVariableDeclaration(name: "receivedValue_Wei",
                                               rawName: "receivedValue_Wei",
                                               type: .int))
      declarations.append(BVariableDeclaration(name: "sentValue_Wei",
                                               rawName: "sentValue_Wei",
                                               type: .int))
      return declarations
    }
}
