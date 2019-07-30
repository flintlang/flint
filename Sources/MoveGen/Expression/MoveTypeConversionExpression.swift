//
//  MoveTypeConversionExpression.swift
//  MoveGen
//
//  Created by Nik on 27/11/2018.
//

import AST
import MoveIR

struct MoveTypeConversionExpression {
  let typeConversionExpression: TypeConversionExpression

  func rendered(functionContext: FunctionContext) -> MoveIR.Expression {
    // Is this an upcast or a downcast?
    let originalType = functionContext.environment.type(
      of: typeConversionExpression.expression,
      enclosingType: typeConversionExpression.expression.enclosingType ??
        functionContext.enclosingTypeName,
      scopeContext: functionContext.scopeContext)
    let targetType = typeConversionExpression.type.rawType

    let originalTypeInformation = typeInformation(type: originalType)
    let targetTypeInformation = typeInformation(type: targetType)

    let expressionIr = MoveExpression(expression: typeConversionExpression.expression)
      .rendered(functionContext: functionContext)

    // If the number of bits is increasing or staying the same, we don't have to make any checks.
    if originalTypeInformation.size <= targetTypeInformation.size {
      return expressionIr
    }

    // The maximum value of the target type
    let targetMax = MoveTypeConversionExpression.maximumValue[targetTypeInformation.size]!
    return MoveRuntimeFunction.revertIfGreater(value: expressionIr, max: .literal(.hex(targetMax)))
  }

  private struct TypeInformation {
    let size: Int
    let signed: Bool
  }

  private static let maximumValue: [Int: String] = [
    8: "0xFF",
    16: "0xFFFF",
    24: "0xFFFFFF",
    32: "0xFFFFFFFF",
    40: "0xFFFFFFFFFF",
    48: "0xFFFFFFFFFFFF",
    56: "0xFFFFFFFFFFFFFF",
    64: "0xFFFFFFFFFFFFFFFF",
    72: "0xFFFFFFFFFFFFFFFFFF",
    80: "0xFFFFFFFFFFFFFFFFFFFF",
    88: "0xFFFFFFFFFFFFFFFFFFFFFF",
    96: "0xFFFFFFFFFFFFFFFFFFFFFFFF",
    104: "0xFFFFFFFFFFFFFFFFFFFFFFFFFF",
    112: "0xFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
    120: "0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
    128: "0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
    136: "0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
    144: "0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
    152: "0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
    160: "0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
    168: "0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
    176: "0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
    184: "0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
    192: "0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
    200: "0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
    208: "0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
    216: "0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
    224: "0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
    232: "0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
    240: "0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
    248: "0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
    256: "0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF"
  ]

  private func typeInformation(type: RawType) -> (size: Int, signed: Bool) {
    switch type {
    case .basicType(let basicType):
      switch basicType {
      case .int:
        return (size: 256, signed: true)
      default:
        return (size: 256, signed: false)
      }
    case .solidityType(let solidityType):
      switch solidityType {
      case .int8:
        return (size: 8, signed: true)
      case .int16:
        return (size: 16, signed: true)
      case .int24:
        return (size: 24, signed: true)
      case .int32:
        return (size: 32, signed: true)
      case .int40:
        return (size: 40, signed: true)
      case .int48:
        return (size: 48, signed: true)
      case .int56:
        return (size: 56, signed: true)
      case .int64:
        return (size: 64, signed: true)
      case .int72:
        return (size: 72, signed: true)
      case .int80:
        return (size: 80, signed: true)
      case .int88:
        return (size: 88, signed: true)
      case .int96:
        return (size: 96, signed: true)
      case .int104:
        return (size: 104, signed: true)
      case .int112:
        return (size: 112, signed: true)
      case .int120:
        return (size: 120, signed: true)
      case .int128:
        return (size: 128, signed: true)
      case .int136:
        return (size: 136, signed: true)
      case .int144:
        return (size: 144, signed: true)
      case .int152:
        return (size: 152, signed: true)
      case .int160:
        return (size: 160, signed: true)
      case .int168:
        return (size: 168, signed: true)
      case .int176:
        return (size: 176, signed: true)
      case .int184:
        return (size: 184, signed: true)
      case .int192:
        return (size: 192, signed: true)
      case .int200:
        return (size: 200, signed: true)
      case .int208:
        return (size: 208, signed: true)
      case .int216:
        return (size: 216, signed: true)
      case .int224:
        return (size: 224, signed: true)
      case .int232:
        return (size: 232, signed: true)
      case .int240:
        return (size: 240, signed: true)
      case .int248:
        return (size: 248, signed: true)
      case .int256:
        return (size: 256, signed: true)
      case .uint8:
        return (size: 8, signed: false)
      case .uint16:
        return (size: 16, signed: false)
      case .uint24:
        return (size: 24, signed: false)
      case .uint32:
        return (size: 32, signed: false)
      case .uint40:
        return (size: 40, signed: false)
      case .uint48:
        return (size: 48, signed: false)
      case .uint56:
        return (size: 56, signed: false)
      case .uint64:
        return (size: 64, signed: false)
      case .uint72:
        return (size: 72, signed: false)
      case .uint80:
        return (size: 80, signed: false)
      case .uint88:
        return (size: 88, signed: false)
      case .uint96:
        return (size: 96, signed: false)
      case .uint104:
        return (size: 104, signed: false)
      case .uint112:
        return (size: 112, signed: false)
      case .uint120:
        return (size: 120, signed: false)
      case .uint128:
        return (size: 128, signed: false)
      case .uint136:
        return (size: 136, signed: false)
      case .uint144:
        return (size: 144, signed: false)
      case .uint152:
        return (size: 152, signed: false)
      case .uint160:
        return (size: 160, signed: false)
      case .uint168:
        return (size: 168, signed: false)
      case .uint176:
        return (size: 176, signed: false)
      case .uint184:
        return (size: 184, signed: false)
      case .uint192:
        return (size: 192, signed: false)
      case .uint200:
        return (size: 200, signed: false)
      case .uint208:
        return (size: 208, signed: false)
      case .uint216:
        return (size: 216, signed: false)
      case .uint224:
        return (size: 224, signed: false)
      case .uint232:
        return (size: 232, signed: false)
      case .uint240:
        return (size: 240, signed: false)
      case .uint248:
        return (size: 248, signed: false)
      case .uint256:
        return (size: 256, signed: false)
      default:
        return (size: 256, signed: false)
      }
    default:
      return (size: 256, signed: false)
    }
  }
}
