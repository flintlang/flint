//
//  Environment+Memory.swift
//  AST
//
//  Created by Hails, Daniel R on 22/08/2018.
//

extension Environment {
  /// The memory size of a type, in terms of number of memory slots it occupies.
  public func size(of type: RawType) -> Int {
    switch type {
    case .basicType(.event): return 0 // Events do not use memory.
    case .basicType: return 1
    case .fixedSizeArrayType(let rawType, let elementCount): return size(of: rawType) * elementCount
    case .arrayType: return 1
    case .rangeType: return 0 // Ranges do not use memory
    case .dictionaryType: return 1
    case .inoutType: fatalError()
    case .selfType: fatalError("Self type should have been replaced with concrete type")
    case .any: return 0
    case .errorType: return 0
    case .functionType: return 0
    case .solidityType: return 1

    case .userDefinedType(let identifier):
      if isEnumDeclared(identifier),
        case .enumCase(let enumCase) = types[identifier]!.properties.first!.value.property {
        return size(of: enumCase.hiddenType.rawType)
      }
      return types[identifier]!.properties.reduce(0) { acc, element in
        return acc + size(of: element.value.rawType)
      }
    }
  }

  /// The memory offset of a property in a type.
  public func propertyOffset(for property: String, enclosingType: RawTypeIdentifier) -> Int? {

    var offsetMap = [String: Int]()
    var offset = 0

    let rootType = types[enclosingType]!

    for p in rootType.orderedProperties.prefix(while: { $0 != property }) {
      offsetMap[p] = offset
      let propertyType = rootType.properties[p]!.rawType
      let propertySize = size(of: propertyType)

      offset += propertySize
    }

    return offset
  }
}
