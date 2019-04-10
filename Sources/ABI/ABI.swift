//
//  ABI.swift
//  ABI
//
//  Created by Aurel Bílý on 27/11/18.
//

import CryptoSwift

/// Returns 4 bytes of the Keccak-256 hash of the given signature.
public func soliditySelectorRaw(of signature: String) -> [UInt8] {
  return Array(signature.bytes.sha3(.keccak256).prefix(4))
}

/// Returns the hex-digest of 4 bytes of the Keccak-256 hash of the given
/// signature, in the format "0x12345678".
public func soliditySelectorHex(of signature: String) -> String {
  return "0x\(soliditySelectorRaw(of: signature).toHexString())"
}
