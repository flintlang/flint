//
//  Functions.swift
//  YUL
//
//  Created by Yicheng Luo on 11/27/18.
//

//import Foundation
//struct YULFunctions {
//
//  static private func call1(_ name: String, _ x: String) -> String {
//    return "\(name)(\(x))"
//  }
//
//  static private func call2(_ name: String, _ x: String, y: String) -> String {
//    return "\(name)(\(x), \(y)"
//  }
//
//  // MARK: Logic
//  func not(x: String) {
//
//  }
//
//  func and(x: String, y: String) {
//
//  }
//
//  func or(x: String, y: String) {
//
//  }
//
//  func xor(x: String, y: String) {
//
//  }
//
//  // MARK: Arithmetic
//  func addu256(x, y) {
//
//  }
//
//  func subu256(x, y) {
//
//  }
//
//  func mulu256(x, y) {
//
//  }
//
//  func divu256(x, y) {
//
//  }
//
//  func divs256(x, y) {
//
//  }
//
//  func modu256(x, y) {
//
//  }
//
//  func mods256(x, y) {
//
//  }
//
//  func signextendu256(i, x) {
//
//  }
//
//  func expu256(x, y) {
//
//  }
//
//  func addmodu256(x, y, m) {
//
//  }
//
//  func mulmodu(x, y, m) {
//  }
//
//  func ltu256(x, y) {
//
//  }
//
//  func gtu256(x, y) {
//
//  }
//
//  func lts256(x, y) {
//
//  }
//
//  func gtu256(x, y) {
//
//  }
//
//  func lts256(x, y) {
//
//  }
//
//  func gts256(x,y) {
//
//  }
//
//  func equ256(x, y) {
//
//  }
//
//  func iszerou256(x) {
//
//  }
//
//  func notu256(x) {
//
//  }
//
//  func andu256(x, y) {
//
//  }
//
//  func oru256(x, y) {
//
//  }
//
//  func xoru(x,y) {
//
//  }
//
//  func shlu256(x, y) {
//
//  }
//
//  func shru256(x, y) {
//
//  }
//
//  func sars256(x, y) {
//
//  }
//
//  func byte(n, x)
//
//  // MARK: Memory and storage
//  func mload(p) {
//
//  }
//
//  func mstore(p, v) {
//
//  }
//
//  func mstore8(p, v) {
//
//  }
//
//  func sload(p) {
//
//  }
//
//  func sstore(p, v) {
//
//  }
//
//  func msize() {
//
//  }
//
//  // MARK: Execution control
//  func create(v, p, n) {
//
//  }
//
//  func create2(v, p, n, s)
//  func call(g:u256, a:u256, v:u256, in:u256, insize:u256, out:u256, outsize:u256)
//  func callcode(g:u256, a:u256, v:u256, in:u256, insize:u256, out:u256, outsize:u256)
//  func delegatecall(g:u256, a:u256, in:u256, insize:u256, out:u256, outsize:u256)
//  func abort()
//  func return_(p, s)
//  func revert(p, s)
//  func selfdestruct(a:u256)
//  log0(p:u256, s:u256)
//  log1(p:u256, s:u256, t1:u256)
//  log2(p:u256, s:u256, t1:u256, t2:u256)
//  log3(p:u256, s:u256, t1:u256, t2:u256, t3:u256)
//  log4(p:u256, s:u256, t1:u256, t2:u256, t3:u256, t4:u256)
//  // MARK: State queries
//  blockcoinbase()
//  blockdifficulty()
//  blockgaslimit()
//  blockhash(b:u256)
//  blocknumber()
//  blocktimestamp() -> timestamp:u256
//  txorigin()
//  txgasprice()
//  gasleft()
//  balance(a:u256)
//  this()
//  caller()
//  callvalue()
//  calldataload(p:u256)
//  calldatasize()
//  calldatacopy(t:u256, f:u256, s:u256)
//  codesize()
//  codecopy(t:u256, f:u256, s:u256)
//  extcodesize(a:u256) -> size:u256
//  extcodecopy(a:u256, t:u256, f:u256, s:u256)
//  extcodehash(a:u256)
//  // MARK: Others
//  discard(unused:bool)
//  discardu256(unused:u256)
//  splitu256tou64(x:u256) -> (x1:u64, x2:u64, x3:u64, x4:u64)
//  combineu64tou256(x1:u64, x2:u64, x3:u64, x4:u64) -> (x:u256)
//  keccak256(p:u256, s:u256) -> v:u256
//  // MARK: Object access
//  datasize(name:string) -> size:u256
//  dataoffset(name:string) -> offset:u256
//  datacopy(dst:u256, src:u256, len:u256)
//
//
//}
