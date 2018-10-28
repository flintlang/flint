//
//  DiagnosticTranslator.swift
//  AST
//
//  Created by Ethan on 27/10/2018.
//
import struct Diagnostic.Diagnostic
import LanguageServerProtocol

public protocol DiagnosticTranslator {
  func translate(diagnostic: Diagnostic) -> LanguageServerProtocol.Diagnostic
}
