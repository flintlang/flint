//
//  Type.swift
//  YUL
//
//  Created by Aurel Bílý on 12/26/18.
//

public enum Type: String, CustomStringConvertible {
  case bool
  case u8
  case s8
  case u32
  case s32
  case u64
  case s64
  case u128
  case s128
  case u256
  case s256
  case any

  public var description: String {
    return self.rawValue
  }
}
