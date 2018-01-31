" Based on https://github.com/apple/swift/blob/master/utils/vim/syntax/swift.vim

if exists("b:current_syntax")
    finish
endif

syn keyword flintKeyword
      \ associatedtype
      \ break
      \ case
      \ catch
      \ continue
      \ default
      \ defer
      \ do
      \ else
      \ fallthrough
      \ for
      \ guard
      \ if
      \ in
      \ repeat
      \ return
      \ switch
      \ throw
      \ try
      \ where
      \ while
      \ implicit

syn keyword flintImport skipwhite nextgroup=flintImportModule
      \ import

syn keyword flintDefinitionModifier
      \ public

syn keyword flintIdentifierKeyword
      \ self

syn keyword flintFuncKeywordGeneral skipwhite nextgroup=flintTypeParameters
      \ init

syn keyword flintMutating skipwhite nextgroup=flintFuncDefinition
      \ mutating

syn keyword flintFuncDefinition skipwhite nextgroup=flintTypeName,flintOperator
      \ func

syn keyword flintTypeDefinition skipwhite nextgroup=flintTypeName
      \ contract
      \ struct

syn keyword flintVarDefinition skipwhite nextgroup=flintVarName
      \ let
      \ var

syn keyword flintBoolean
      \ false
      \ true

syn keyword flintNil
      \ nil

syn match flintImportModule contained nextgroup=flintImportComponent
      \ /\<[A-Za-z_][A-Za-z_0-9]*\>/
syn match flintImportComponent contained nextgroup=flintImportComponent
      \ /\.\<[A-Za-z_][A-Za-z_0-9]*\>/

syn match flintTypeName contained skipwhite nextgroup=flintTypeParameters
      \ /\<[A-Za-z_][A-Za-z_0-9\.]*\>/
syn match flintVarName contained skipwhite nextgroup=flintTypeDeclaration
      \ /\<[A-Za-z_][A-Za-z_0-9]*\>/
syn match flintImplicitVarName
      \ /\$\<[A-Za-z_0-9]\+\>/

" TypeName[Optionality]?
syn match flintType contained skipwhite nextgroup=flintTypeParameters
      \ /\<[A-Za-z_][A-Za-z_0-9\.]*\>[!?]\?/
" [Type:Type] (dictionary) or [Type] (array)
syn region flintType contained contains=flintTypePair,flintType
      \ matchgroup=Delimiter start=/\[/ end=/\]/
syn match flintTypePair contained skipwhite nextgroup=flintTypeParameters,flintTypeDeclaration
      \ /\<[A-Za-z_][A-Za-z_0-9\.]*\>[!?]\?/
" (Type[, Type]) (tuple)
"
syn match flintCapability contained skipwhite nextgroup=flintCapabilityBinding
      \ /\<[A-Za-z_][A-Za-z_0-9\.]*\>[!?]\?/

" FIXME: we should be able to use skip="," and drop flintParamDelim
syn region flintType contained contains=flintType,flintParamDelim
      \ matchgroup=Delimiter start="[^@](" end=")" matchgroup=NONE skip=","
syn match flintParamDelim contained
      \ /,/
" <Generic Clause> (generics)
syn region flintTypeParameters contained contains=flintVarName,flintConstraint
      \ matchgroup=Delimiter start="<" end=">" matchgroup=NONE skip=","
syn keyword flintConstraint contained
      \ where

syn match flintTypeDeclaration skipwhite nextgroup=flintType,flintInOutKeyword
      \ /:/
syn match flintTypeDeclaration skipwhite nextgroup=flintType
      \ /->/

syn match flintCapabilityGroupDeclaration skipwhite nextgroup=flintCapability,flintCapabilityGroup
      \ /::/
syn match flintCapabilityBinding skipwhite nextgroup=flintCapabilityGroup
      \ /<-/

syn region flintCapabilityGroup contained contains=flintCapability,flintParamDelim
      \ matchgroup=Delimiter start="[^@](" end=")" matchgroup=NONE skip=","

syn region flintString start=/"/ skip=/\\\\\|\\"/ end=/"/ contains=flintInterpolationRegion
syn region flintInterpolationRegion matchgroup=flintInterpolation start=/\\(/ end=/)/ contained contains=TOP
syn region flintComment start="/\*" end="\*/" contains=flintComment,flintLineComment,flintTodo
syn region flintLineComment start="//" end="$" contains=flintComment,flintTodo

syn match flintDecimal /[+\-]\?\<\([0-9][0-9_]*\)\([.][0-9_]*\)\?\([eE][+\-]\?[0-9][0-9_]*\)\?\>/
syn match flintHex /[+\-]\?\<0x[0-9A-Fa-f][0-9A-Fa-f_]*\(\([.][0-9A-Fa-f_]*\)\?[pP][+\-]\?[0-9][0-9_]*\)\?\>/
syn match flintOct /[+\-]\?\<0o[0-7][0-7_]*\>/
syn match flintBin /[+\-]\?\<0b[01][01_]*\>/

syn match flintOperator +\.\@<!\.\.\.\@!\|[/=\-+*%<>!&|^~]\@<!\(/[/*]\@![/=\-+*%<>!&|^~]*\|*/\@![/=\-+*%<>!&|^~]*\|->\@![/=\-+*%<>!&|^~]*\|[=+%<>!&|^~][/=\-+*%<>!&|^~]*\)+ skipwhite nextgroup=flintTypeParameters
syn match flintOperator "\.\.[<.]" skipwhite nextgroup=flintTypeParameters

syn match flintChar /'\([^'\\]\|\\\(["'tnr0\\]\|x[0-9a-fA-F]\{2}\|u[0-9a-fA-F]\{4}\|U[0-9a-fA-F]\{8}\)\)'/

syn match flintAttribute /@\<\w\+\>/ skipwhite nextgroup=flintType

syn keyword flintTodo MARK TODO FIXME contained

syn region flintReservedIdentifier oneline
      \ start=/`/ end=/`/

hi def link flintImport Include
hi def link flintImportModule Title
hi def link flintImportComponent Identifier
hi def link flintKeyword Statement
hi def link flintMultiwordKeyword Statement
hi def link flintTypeDefinition Define
hi def link flintMultiwordTypeDefinition Define
hi def link flintType Type
hi def link flintTypePair Type
hi def link flintTypeName Function
hi def link flintCapability Identifier
hi def link flintConstraint Special
hi def link flintFuncDefinition Define
hi def link flintDefinitionModifier Define
hi def link flintInOutKeyword Define
hi def link flintFuncKeyword Function
hi def link flintFuncKeywordGeneral Function
hi def link flintVarDefinition Define
hi def link flintVarName Identifier
hi def link flintImplicitVarName Identifier
hi def link flintIdentifierKeyword Identifier
hi def link flintTypeDeclaration Delimiter
hi def link flintTypeParameters Delimiter
hi def link flintCapabilityGroupDeclaration Delimiter
hi def link flintCapabilityBinding Delimiter
hi def link flintBoolean Boolean
hi def link flintString String
hi def link flintInterpolation Special
hi def link flintComment Comment
hi def link flintLineComment Comment
hi def link flintDecimal Number
hi def link flintHex Number
hi def link flintOct Number
hi def link flintBin Number
hi def link flintOperator Function
hi def link flintChar Character
hi def link flintLabel Operator
hi def link flintMutating Statement
hi def link flintPreproc PreCondit
hi def link flintPreprocFalse Comment
hi def link flintAttribute Type
hi def link flintTodo Todo
hi def link flintNil Constant
hi def link flintCastOp Operator
hi def link flintNilOps Operator
hi def link flintScope PreProc

let b:current_syntax = "flint"
