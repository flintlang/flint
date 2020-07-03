use super::environment::*;
use super::SemanticAnalysis::*;
use super::AST::*;
use std::thread::panicking;

#[derive(Debug, Default)]
pub struct Context {
    pub environment: Environment,
    pub ContractDeclarationContext: Option<ContractDeclarationContext>,
    pub ContractBehaviourDeclarationContext: Option<ContractBehaviourDeclarationContext>,
    pub StructDeclarationContext: Option<StructDeclarationContext>,
    pub FunctionDeclarationContext: Option<FunctionDeclarationContext>,
    pub SpecialDeclarationContext: Option<SpecialDeclarationContext>,
    pub TraitDeclarationContext: Option<TraitDeclarationContext>,
    pub ScopeContext: Option<ScopeContext>,
    pub AssetContext: Option<AssetDeclarationContext>,
    pub BlockContext: Option<BlockContext>,
    pub FunctionCallReceiverTrail: Vec<Expression>,
    pub IsPropertyDefaultAssignment: bool,
    pub IsFunctionCallContext: bool,
    pub IsFunctionCallArgument: bool,
    pub IsFunctionCallArgumentLabel: bool,
    pub ExternalCallContext: Option<ExternalCall>,
    pub IsExternalFunctionCall: bool,
    pub InAssignment: bool,
    pub InIfCondition: bool,
    pub InBecome: bool,
    pub IsLValue: bool,
    pub InSubscript: bool,
    pub IsEnclosing: bool,
    pub InEmit: bool,
    pub PreStatements: Vec<Statement>,
    pub PostStatements: Vec<Statement>,
}

impl Context {
    pub fn enclosing_type_identifier(&self) -> Option<Identifier> {
        if self.is_contract_behaviour_declaration_context() {
            let i = self
                .ContractBehaviourDeclarationContext
                .as_ref()
                .unwrap()
                .identifier
                .clone();
            return Some(i);
        } else if self.is_struct_declaration_context() {
            let i = self
                .StructDeclarationContext
                .as_ref()
                .unwrap()
                .identifier
                .clone();
            return Some(i);
        } else if self.is_contract_declaration_context() {
            let i = self
                .ContractDeclarationContext
                .as_ref()
                .unwrap()
                .identifier
                .clone();
            return Some(i);
        } else if self.is_asset_declaration_context() {
            let i = self.AssetContext.as_ref().unwrap().identifier.clone();
            return Some(i);
        } else {
            None
        }
    }
    pub fn is_contract_declaration_context(&self) -> bool {
        self.ContractDeclarationContext.is_some()
    }

    pub fn is_contract_behaviour_declaration_context(&self) -> bool {
        self.ContractBehaviourDeclarationContext.is_some()
    }

    fn is_struct_declaration_context(&self) -> bool {
        self.StructDeclarationContext.is_some()
    }

    fn is_asset_declaration_context(&self) -> bool {
        self.AssetContext.is_some()
    }

    pub fn is_function_declaration_context(&self) -> bool {
        self.FunctionDeclarationContext.is_some()
    }

    pub fn is_special_declaration_context(&self) -> bool {
        self.SpecialDeclarationContext.is_some()
    }

    pub fn is_trait_declaration_context(&self) -> bool {
        self.TraitDeclarationContext.is_some()
    }

    pub(crate) fn in_function_or_special(&self) -> bool {
        self.is_function_declaration_context() || self.is_special_declaration_context()
    }

    pub(crate) fn has_scope_context(&self) -> bool {
        self.ScopeContext.is_some()
    }

    pub fn scope_context(&self) -> Option<&ScopeContext> {
        self.ScopeContext.as_ref()
    }
}

#[derive(Debug)]
pub struct ContractDeclarationContext {
    pub identifier: Identifier,
}

#[derive(Debug, Clone)]
pub struct ContractBehaviourDeclarationContext {
    pub identifier: Identifier,
    pub caller: Option<Identifier>,
    pub caller_protections: Vec<CallerProtection>,
}

#[derive(Debug, Clone)]
pub struct StructDeclarationContext {
    pub identifier: Identifier,
}

#[derive(Debug, Default, Clone)]
pub struct FunctionDeclarationContext {
    pub declaration: FunctionDeclaration,
    pub local_variables: Vec<VariableDeclaration>,
}
impl FunctionDeclarationContext {
    pub fn mutates(&self) -> Vec<Identifier> {
        self.declaration.mutates()
    }
}

#[derive(Debug, Clone)]
pub struct SpecialDeclarationContext {
    pub declaration: SpecialDeclaration,
    pub local_variables: Vec<VariableDeclaration>,
}

#[derive(Debug, Clone)]
pub struct TraitDeclarationContext {
    pub identifier: Identifier,
}

#[derive(Debug, Clone)]
pub struct BlockContext {
    pub ScopeContext: ScopeContext,
}

#[derive(Debug, Default, Clone)]
pub struct ScopeContext {
    pub parameters: Vec<Parameter>,
    pub local_variables: Vec<VariableDeclaration>,
    pub counter: u64,
}

impl ScopeContext {
    pub fn declaration(&self, name: String) -> Option<VariableDeclaration> {
        let mut identifiers: Vec<VariableDeclaration> = self
            .local_variables
            .clone()
            .into_iter()
            .chain(
                self.parameters
                    .clone()
                    .into_iter()
                    .map(|p| p.as_variable_declaration()),
            )
            .collect();
        identifiers = identifiers
            .into_iter()
            .filter(|v| v.identifier.token == name)
            .collect();
        let result = identifiers.first();
        if result.is_some() {
            let declaration = identifiers.first().unwrap().clone();
            return Some(declaration);
        }
        return None;
    }

    pub fn type_for(&self, variable: String) -> Option<Type> {
        let mut identifiers: Vec<VariableDeclaration> = self
            .local_variables
            .clone()
            .into_iter()
            .chain(
                self.parameters
                    .clone()
                    .into_iter()
                    .map(|p| p.as_variable_declaration()),
            )
            .collect();
        identifiers = identifiers
            .into_iter()
            .filter(|v| {
                v.identifier.token == variable || mangle(variable.clone()) == v.identifier.token
            })
            .collect();
        let result = identifiers.first();
        if result.is_some() {
            let result_type = identifiers.first().unwrap().clone().variable_type;

            return Some(result_type);
        }
        return None;
    }

    pub fn contains_variable_declaration(&self, name: String) -> bool {
        let variables: Vec<String> = self
            .local_variables
            .clone()
            .into_iter()
            .map(|v| v.identifier.token)
            .collect();
        variables.contains(&name)
    }

    pub fn contains_parameter_declaration(&self, name: String) -> bool {
        let parameters: Vec<String> = self
            .parameters
            .clone()
            .into_iter()
            .map(|p| p.identifier.token)
            .collect();
        parameters.contains(&name)
    }

    pub fn fresh_identifier(&mut self, line_info: LineInfo) -> Identifier {
        self.counter = self.counter + 1;
        let count = self.local_variables.len() + self.parameters.len() + self.counter as usize;
        let name = format!("temp__{}", count);
        return Identifier {
            token: name,
            enclosing_type: None,
            line_info: line_info,
        };
    }

    pub fn enclosing_parameter(
        &self,
        expression: Expression,
        t: &TypeIdentifier,
    ) -> Option<String> {
        let expression_enclosing = expression.enclosing_type();
        let expression_enclosing = expression_enclosing.unwrap_or_default();
        if expression_enclosing == t.to_string() {
            if expression.enclosing_identifier().is_some() {
                let enclosing_identifier = expression.enclosing_identifier().clone();
                let enclosing_identifier = enclosing_identifier.unwrap();
                if self.contains_parameter_declaration(enclosing_identifier.token.clone()) {
                    return Option::from(enclosing_identifier.token);
                }
            }
        }

        return None;
    }
}

#[derive(Debug, Clone)]
pub struct AssetDeclarationContext {
    pub identifier: Identifier,
}
