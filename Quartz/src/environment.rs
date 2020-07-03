use super::context::*;
use super::SemanticAnalysis::*;
use super::AST::*;
use std::collections::HashMap;

#[derive(Debug, Default, Clone)]
pub struct Environment {
    pub contract_declarations: Vec<Identifier>,
    pub struct_declarations: Vec<Identifier>,
    pub enum_declarations: Vec<Identifier>,
    pub event_declarations: Vec<Identifier>,
    pub trait_declarations: Vec<Identifier>,
    pub asset_declarations: Vec<Identifier>,
    pub types: HashMap<TypeIdentifier, TypeInfo>,
}

#[derive(Debug, Clone)]
pub enum FunctionCallMatchResult {
    MatchedFunction(FunctionInformation),
    MatchedFunctionWithoutCaller(Candidates),
    MatchedInitializer(SpecialInformation),
    MatchedFallback(SpecialInformation),
    MatchedGlobalFunction(FunctionInformation),
    Failure(Candidates),
}

impl FunctionCallMatchResult {
    fn merge(self, f: FunctionCallMatchResult) -> FunctionCallMatchResult {
        if let FunctionCallMatchResult::Failure(c1) = &self {
            if let FunctionCallMatchResult::Failure(c2) = f.clone() {
                let mut c1_canididates = c1.candidates.clone();
                let mut c2_canididates = c2.candidates.clone();
                c1_canididates.append(&mut c2_canididates);
                return FunctionCallMatchResult::Failure(Candidates {
                    candidates: c1_canididates,
                });
            } else {
                return f;
            }
        } else {
            let result = self.clone();
            return result;
        }
    }
}

#[derive(Debug, Clone)]
pub enum CallableInformation {
    FunctionInformation(FunctionInformation),
    SpecialInformation(SpecialInformation),
}

#[derive(Debug, Default, Clone)]
pub struct Candidates {
    pub(crate) candidates: Vec<CallableInformation>,
}

impl Environment {
    pub fn build(&mut self, module: Module) {
        for declaration in module.declarations {
            match declaration {
                TopLevelDeclaration::ContractDeclaration(c) => self.add_contract_declaration(&c),
                TopLevelDeclaration::StructDeclaration(s) => self.add_struct_declaration(&s),
                TopLevelDeclaration::EnumDeclaration(e) => self.add_enum_declaration(&e),
                TopLevelDeclaration::TraitDeclaration(t) => self.add_trait_declaration(&t),
                TopLevelDeclaration::ContractBehaviourDeclaration(c) => {
                    self.add_contract_behaviour_declaration(&c)
                }
                TopLevelDeclaration::AssetDeclaration(a) => self.add_asset_declaration(&a),
            }
        }
    }

    pub fn add_event_declaration(&mut self, e: &EventDeclaration) {
        let identifier = e.identifier.clone();
        &self.event_declarations.push(identifier);
    }

    pub fn add_contract_declaration(&mut self, c: &ContractDeclaration) {
        let identifier = c.identifier.clone();
        &self.contract_declarations.push(identifier);
        &self.types.insert(
            c.identifier.token.clone(),
            TypeInfo {
                ..Default::default()
            },
        );

        for conformance in &c.conformances {
            self.add_conformance(
                &c.identifier.token.clone(),
                &conformance.identifier.token.clone(),
            )
        }

        let members = &c.contract_members;
        for member in members {
            match member {
                ContractMember::EventDeclaration(e) => self.add_event_declaration(&e),
                ContractMember::VariableDeclaration(v) => self.add_property(
                    Property::VariableDeclaration(v.clone()),
                    &v.identifier.token,
                    &c.identifier.token,
                ),
            }
        }
    }

    pub fn add_struct_declaration(&mut self, s: &StructDeclaration) {
        let identifier = s.identifier.clone();
        &self.struct_declarations.push(identifier);

        &self.types.insert(
            s.identifier.token.clone(),
            TypeInfo {
                ..Default::default()
            },
        );

        let members = &s.members;
        for member in members {
            match member {
                StructMember::VariableDeclaration(v) => self.add_property(
                    Property::VariableDeclaration(v.clone()),
                    &v.identifier.token,
                    &s.identifier.token,
                ),
                StructMember::FunctionDeclaration(f) => {
                    self.add_function(f, &s.identifier.token, vec![])
                }
                StructMember::SpecialDeclaration(sd) => {
                    self.add_special(sd, &s.identifier.token, Vec::new())
                }
            }
        }
    }

    pub fn add_asset_declaration(&mut self, a: &AssetDeclaration) {
        let identifier = a.identifier.clone();
        &self.asset_declarations.push(identifier);

        &self.types.insert(
            a.identifier.token.clone(),
            TypeInfo {
                ..Default::default()
            },
        );

        let members = &a.members;
        for member in members {
            match member {
                AssetMember::VariableDeclaration(v) => self.add_property(
                    Property::VariableDeclaration(v.clone()),
                    &v.identifier.token,
                    &a.identifier.token,
                ),
                AssetMember::FunctionDeclaration(f) => {
                    self.add_function(f, &a.identifier.token, vec![])
                }
                AssetMember::SpecialDeclaration(sd) => {
                    self.add_special(sd, &a.identifier.token, Vec::new())
                }
            }
        }
    }

    pub fn add_trait_declaration(&mut self, t: &TraitDeclaration) {
        let identifier = t.identifier.clone();
        &self.trait_declarations.push(identifier);

        let special = Environment::external_trait_init();
        self.add_init_sig(special, &t.identifier.token.clone(), vec![], true);

        if !t.modifiers.is_empty() {
            if self.types.get(&t.identifier.token).is_none() {
                self.types.insert(
                    t.identifier.token.clone(),
                    TypeInfo {
                        ordered_properties: vec![],
                        properties: Default::default(),
                        functions: Default::default(),
                        initialisers: vec![],
                        fallbacks: vec![],
                        public_initializer: None,
                        conformances: vec![],
                        modifiers: vec![],
                    },
                );
            }

            if self.types.get(&t.identifier.token).is_some() {
                let type_info = self.types.get_mut(&t.identifier.token);
                let type_info = type_info.unwrap();
                type_info.modifiers = t.modifiers.clone();
            }
        }

        for member in t.members.clone() {
            match member {
                TraitMember::FunctionDeclaration(f) => {
                    self.add_function(&f, &t.identifier.token, vec![])
                }
                TraitMember::SpecialDeclaration(s) => {
                    self.add_special(&s, &t.identifier.token, vec![])
                }
                TraitMember::FunctionSignatureDeclaration(f) => {
                    self.add_function_signature(&f, &t.identifier.token, vec![], true)
                }
                TraitMember::SpecialSignatureDeclaration(_) => unimplemented!(),
                TraitMember::ContractBehaviourDeclaration(_) => {}
                TraitMember::EventDeclaration(_) => {}
            }
        }
    }

    fn add_contract_behaviour_declaration(&mut self, c: &ContractBehaviourDeclaration) {
        let members = &c.members;
        let caller_protections = &c.caller_protections.clone();
        for member in members {
            match member {
                ContractBehaviourMember::FunctionDeclaration(f) => {
                    self.add_function(f, &c.identifier.token, c.caller_protections.clone())
                }
                ContractBehaviourMember::SpecialDeclaration(s) => {
                    self.add_special(s, &c.identifier.token, caller_protections.clone())
                }
                ContractBehaviourMember::SpecialSignatureDeclaration(_) => continue,
                ContractBehaviourMember::FunctionSignatureDeclaration(_) => continue,
            }
        }
    }

    fn add_enum_declaration(&mut self, e: &EnumDeclaration) {
        let identifier = e.identifier.clone();
        &self.trait_declarations.push(identifier);

        &self.types.insert(
            e.identifier.token.clone(),
            TypeInfo {
                ..Default::default()
            },
        );
    }

    fn add_conformance(&mut self, t: &TypeIdentifier, conformance_identifier: &TypeIdentifier) {
        let trait_info = &self.types.get(conformance_identifier);
        let type_info = &self.types.get(t);
        if trait_info.is_some() && type_info.is_some() {
            let conformance = self.types.get(conformance_identifier).unwrap().clone();
            &self
                .types
                .get_mut(t)
                .unwrap()
                .conformances
                .push(conformance);
        }
    }

    pub fn add_function(
        &mut self,
        f: &FunctionDeclaration,
        t: &TypeIdentifier,
        caller_protections: Vec<CallerProtection>,
    ) {
        let name = f.head.identifier.token.clone();
        let function_information = FunctionInformation {
            declaration: f.clone(),
            mutating: f.is_mutating(),
            caller_protection: caller_protections,
            ..Default::default()
        };
        let type_info = &self.types.get(t);
        if type_info.is_some() {
            if self
                .types
                .get_mut(t)
                .unwrap()
                .functions
                .get_mut(&name)
                .is_some()
            {
                &self
                    .types
                    .get_mut(t)
                    .unwrap()
                    .functions
                    .get_mut(&name)
                    .unwrap()
                    .push(function_information);
            } else {
                &self
                    .types
                    .get_mut(t)
                    .unwrap()
                    .functions
                    .insert(name, vec![function_information]);
            }
        } else {
            self.types.insert(
                t.to_string(),
                TypeInfo {
                    ordered_properties: vec![],
                    properties: Default::default(),
                    functions: Default::default(),
                    initialisers: vec![],
                    fallbacks: vec![],
                    public_initializer: None,
                    conformances: vec![],
                    modifiers: vec![],
                },
            );
            if self
                .types
                .get_mut(t)
                .unwrap()
                .functions
                .get_mut(&name)
                .is_some()
            {
                &self
                    .types
                    .get_mut(t)
                    .unwrap()
                    .functions
                    .get_mut(&name)
                    .unwrap()
                    .push(function_information);
            } else {
                &self
                    .types
                    .get_mut(t)
                    .unwrap()
                    .functions
                    .insert(name, vec![function_information]);
            }
        }
    }

    pub fn remove_function(&mut self, function: &FunctionDeclaration, t: &TypeIdentifier) {
        let name = function.head.identifier.token.clone();
        let type_info = &self.types.get(t);
        if type_info.is_some() {
            if self
                .types
                .get_mut(t)
                .unwrap()
                .functions
                .get_mut(&name)
                .is_some()
            {
                let functions: Vec<FunctionInformation> = self
                    .types
                    .get(t)
                    .unwrap()
                    .functions
                    .clone()
                    .remove(&name)
                    .unwrap()
                    .into_iter()
                    .filter(|f| {
                        f.declaration.head.identifier.token == name
                            && do_vecs_match(
                                &f.declaration.parameters_and_types(),
                                &function.parameters_and_types(),
                            )
                    })
                    .collect();

                self.types
                    .get_mut(t)
                    .unwrap()
                    .functions
                    .insert(name, functions);
            }
        }
    }

    pub fn add_function_signature(
        &mut self,
        f: &FunctionSignatureDeclaration,
        t: &TypeIdentifier,
        caller_protections: Vec<CallerProtection>,
        is_external: bool,
    ) {
        let name = f.identifier.token.clone();
        let function_declaration = FunctionDeclaration {
            head: f.clone(),
            body: vec![],
            ScopeContext: None,
            tags: vec![],
            mangledIdentifier: None,
            is_external,
        };

        let function_information = FunctionInformation {
            declaration: function_declaration.clone(),
            mutating: function_declaration.is_mutating(),
            caller_protection: caller_protections,
            is_signature: true,
            ..Default::default()
        };
        let type_info = &self.types.get(t);
        if type_info.is_some() {
            if self
                .types
                .get_mut(t)
                .unwrap()
                .functions
                .get_mut(&name)
                .is_some()
            {
                &self
                    .types
                    .get_mut(t)
                    .unwrap()
                    .functions
                    .get_mut(&name)
                    .unwrap()
                    .push(function_information);
            } else {
                &self
                    .types
                    .get_mut(t)
                    .unwrap()
                    .functions
                    .insert(name, vec![function_information]);
            }
        } else {
            self.types.insert(
                t.to_string(),
                TypeInfo {
                    ordered_properties: vec![],
                    properties: Default::default(),
                    functions: Default::default(),
                    initialisers: vec![],
                    fallbacks: vec![],
                    public_initializer: None,
                    conformances: vec![],
                    modifiers: vec![],
                },
            );

            &self
                .types
                .get_mut(t)
                .unwrap()
                .functions
                .insert(name, vec![function_information]);
        }
    }

    pub fn add_special(
        &mut self,
        s: &SpecialDeclaration,
        t: &TypeIdentifier,
        caller_protections: Vec<CallerProtection>,
    ) {
        if s.is_init() {
            if s.is_public() {
                let type_info = &self.types.get_mut(t);
                if type_info.is_some() {
                    self.types.get_mut(t).unwrap().public_initializer = Some(s.clone());
                }
            }
            let type_info = &self.types.get_mut(t);
            if type_info.is_some() {
                &self
                    .types
                    .get_mut(t)
                    .unwrap()
                    .initialisers
                    .push(SpecialInformation {
                        declaration: s.clone(),
                        caller_protections,
                    });
            }
        } else {
            let type_info = &self.types.get_mut(t);
            if type_info.is_some() {
                self.types
                    .get_mut(t)
                    .unwrap()
                    .fallbacks
                    .push(SpecialInformation {
                        declaration: s.clone(),
                        caller_protections,
                    });
            }
        }
    }

    pub fn add_init_sig(
        &mut self,
        sig: SpecialSignatureDeclaration,
        enclosing: &TypeIdentifier,
        caller_protections: Vec<CallerProtection>,
        generated: bool,
    ) {
        let special = SpecialDeclaration {
            head: sig,
            body: vec![],
            ScopeContext: Default::default(),
            generated,
        };
        let type_info = &self.types.get_mut(enclosing);
        if type_info.is_some() {
            &self
                .types
                .get_mut(enclosing)
                .unwrap()
                .initialisers
                .push(SpecialInformation {
                    declaration: special.clone(),
                    caller_protections,
                });
        } else {
            self.types.insert(
                enclosing.to_string(),
                TypeInfo {
                    ordered_properties: vec![],
                    properties: Default::default(),
                    functions: Default::default(),
                    initialisers: vec![],
                    fallbacks: vec![],
                    public_initializer: None,
                    conformances: vec![],
                    modifiers: vec![],
                },
            );
            &self
                .types
                .get_mut(enclosing)
                .unwrap()
                .initialisers
                .push(SpecialInformation {
                    declaration: special.clone(),
                    caller_protections,
                });
        }
    }

    pub fn add_property(
        &mut self,
        property: Property,
        identifier: &TypeIdentifier,
        t: &TypeIdentifier,
    ) {
        let type_info = &self.types.get_mut(t);
        if type_info.is_some() {
            &self
                .types
                .get_mut(t)
                .unwrap()
                .properties
                .insert(identifier.to_string(), PropertyInformation { property });
            &self
                .types
                .get_mut(t)
                .unwrap()
                .ordered_properties
                .push(identifier.to_string());
        }
    }

    pub fn property(&self, identifier: String, t: &TypeIdentifier) -> Option<PropertyInformation> {
        let type_info = &self.types.get(t);
        if type_info.is_some() {
            let properties = &self
                .types
                .get(t)
                .unwrap()
                .properties
                .get(identifier.as_str());
            if properties.is_some() {
                let property = properties.unwrap().clone();
                return Some(property);
            }
        }
        None
    }

    pub fn property_declarations(&self, t: &TypeIdentifier) -> Vec<Property> {
        let type_info = &self.types.get(t);
        if type_info.is_some() {
            let properties: Vec<Property> = self
                .types
                .get(t)
                .unwrap()
                .properties
                .clone()
                .into_iter()
                .map(|(_, v)| v.property)
                .collect();
            return properties;
        }
        return vec![];
    }

    pub fn is_property_defined(&self, identifier: String, t: &TypeIdentifier) -> bool {
        self.property(identifier, t).is_some()
    }

    pub fn is_property_constant(&self, identifier: String, t: &TypeIdentifier) -> bool {
        if self.property(identifier.clone(), t).is_some() {
            return self.property(identifier, t).unwrap().is_constant();
        }
        return false;
    }

    pub fn has_public_initialiser(&mut self, t: &TypeIdentifier) -> bool {
        self.types.get_mut(t).unwrap().public_initializer.is_some()
    }

    pub fn is_contract_declared(&self, t: &TypeIdentifier) -> bool {
        let contract = &self.contract_declarations.iter().find(|&x| x.token.eq(t));
        if contract.is_none() {
            return false;
        }
        true
    }

    pub fn is_contract_stateful(&self, t: &TypeIdentifier) -> bool {
        let enum_name = ContractDeclaration::contract_enum_prefix() + t;
        let enums = self.enum_declarations.clone();
        let enums: Vec<String> = enums.into_iter().map(|i| i.token).collect();
        if enums.contains(&enum_name) {
            return true;
        }
        return false;
    }

    pub fn is_state_declared(&self, state: &TypeIdentifier, t: &TypeIdentifier) -> bool {
        let enum_name = ContractDeclaration::contract_enum_prefix() + t;
        if self.types.get(enum_name.as_str()).is_some() {
            return self
                .types
                .get(enum_name.as_str())
                .unwrap()
                .properties
                .get(state)
                .is_some();
        }
        return false;
    }

    pub fn is_struct_declared(&self, t: &TypeIdentifier) -> bool {
        let struct_decl = &self.struct_declarations.iter().find(|&x| x.token.eq(t));
        if struct_decl.is_none() {
            return false;
        }
        true
    }

    pub fn is_trait_declared(&self, t: &TypeIdentifier) -> bool {
        let identifier = &self.trait_declarations.iter().find(|&x| x.token.eq(t));
        if identifier.is_none() {
            return false;
        }
        true
    }

    pub fn is_asset_declared(&self, t: &TypeIdentifier) -> bool {
        let identifier = &self.asset_declarations.iter().find(|&x| x.token.eq(t));
        if identifier.is_none() {
            return false;
        }
        true
    }

    pub fn is_enum_declared(&self, t: &TypeIdentifier) -> bool {
        let enum_declaration = &self.enum_declarations.iter().find(|&x| x.token.eq(t));
        if enum_declaration.is_none() {
            return false;
        }
        true
    }

    pub fn is_conflicting(&self, identifier: &Identifier) -> bool {
        let list = vec![
            &self.contract_declarations,
            &self.struct_declarations,
            &self.asset_declarations,
        ];
        let list: Vec<&Identifier> = list.iter().flat_map(|s| s.iter()).collect();

        for i in list {
            if is_redeclaration(i, identifier) {
                return true;
            }
        }
        false
    }

    pub fn conflicting(&self, identifier: &Identifier, list: Vec<&Vec<Identifier>>) -> bool {
        let list: Vec<&Identifier> = list.iter().flat_map(|s| s.iter()).collect();

        for i in list {
            if is_redeclaration(i, identifier) {
                return true;
            }
        }
        false
    }

    pub fn conflicting_property_declaration(
        &self,
        identifier: &Identifier,
        t: &TypeIdentifier,
    ) -> bool {
        let type_info = self.types.get(t);
        if type_info.is_some() {
            let properties: Vec<&PropertyInformation> =
                type_info.unwrap().properties.values().collect();

            let identifiers: Vec<Identifier> = properties
                .into_iter()
                .map(|p| p.property.get_identifier())
                .collect();
            for i in identifiers {
                if is_redeclaration(&i, identifier) {
                    return true;
                }
            }
        }
        return false;
    }

    pub fn conflicting_trait_signatures(&self, t: &TypeIdentifier) -> bool {
        let type_info = self.types.get(t);
        let conflicting = |f: &Vec<FunctionInformation>| {
            let first = f.get(0);
            if first.is_none() {
                return false;
            }
            let first_signature = first.unwrap().clone();
            let first_parameter = first_signature.declaration.head.clone();
            for function in f {
                if function.get_parameter_types() == first_signature.get_parameter_types()
                    && function.declaration.head.is_equal(first_parameter.clone())
                {
                    return true;
                }
            }
            return false;
        };
        if type_info.is_some() {
            let traits = type_info.unwrap().trait_functions().clone();
            let traits: HashMap<String, Vec<FunctionInformation>> = traits
                .into_iter()
                .filter(|(_, v)| v.len() > 1)
                .filter(|(_, v)| conflicting(v))
                .collect();
            if !traits.is_empty() {
                return true;
            }
        }

        return false;
    }

    pub fn is_conflicting_function_declaration(
        &self,
        function_declaration: &FunctionDeclaration,
        identifier: &TypeIdentifier,
    ) -> bool {
        if self.is_contract_declared(identifier) {
            let type_info = &self.types.get(identifier);
            let mut list = vec![&self.contract_declarations, &self.struct_declarations];
            let mut value = Vec::new();
            if type_info
                .unwrap()
                .functions
                .contains_key(&function_declaration.head.identifier.token)
            {
                for function in self
                    .types
                    .get(identifier)
                    .unwrap()
                    .functions
                    .get(&function_declaration.head.identifier.token)
                    .unwrap()
                {
                    &value.push(function.declaration.head.identifier.clone());
                }
                list.push(&value);
            }
            return self.conflicting(&function_declaration.head.identifier, list);
        }
        let type_info = &self.types.get(identifier);
        if type_info.is_some() {
            if type_info
                .unwrap()
                .functions
                .contains_key(&function_declaration.head.identifier.token)
            {
                for function in self
                    .types
                    .get(identifier)
                    .unwrap()
                    .functions
                    .get(&function_declaration.head.identifier.token)
                    .unwrap()
                {
                    let declaration = &function.declaration.head.identifier;
                    let parameters = &function.declaration.head.parameters;
                    if is_redeclaration(&function_declaration.head.identifier, declaration)
                        && &function_declaration.head.parameters == parameters
                    {
                        return true;
                    }
                }
            }
        }
        return false;
    }

    pub fn is_recursive_struct(&self, t: &TypeIdentifier) -> bool {
        let properties = &self.types.get(t).unwrap().ordered_properties;

        for property in properties {
            let type_property = self.types.get(t).unwrap().properties.get(property);
            if type_property.is_some() {
                match type_property.unwrap().get_type() {
                    Type::UserDefinedType(i) => return i.token == t.to_string(),
                    _ => {
                        return false;
                    }
                }
            }
        }
        false
    }

    pub fn is_type_declared(&self, t: &TypeIdentifier) -> bool {
        self.types.get(t).is_some()
    }

    pub fn is_initiliase_call(&self, function_call: FunctionCall) -> bool {
        self.is_struct_declared(&function_call.identifier.token)
            || self.is_asset_declared(&function_call.identifier.token)
    }

    pub fn contains_caller_protection(&self, c: &CallerProtection, t: &TypeIdentifier) -> bool {
        self.declared_caller_protections(t).contains(&c.name())
    }

    fn declared_caller_protections(&self, t: &TypeIdentifier) -> Vec<String> {
        let type_info = self.types.get(t);
        let caller_protection_property = |p: &PropertyInformation| match p.property.get_type() {
            Type::Address => true,
            Type::FixedSizedArrayType(f) => {
                if f.key_type.is_address_type() {
                    return true;
                }
                return false;
            }
            Type::ArrayType(a) => {
                if a.key_type.is_address_type() {
                    return true;
                }
                return false;
            }
            Type::DictionaryType(d) => {
                if d.value_type.is_address_type() {
                    return true;
                }
                return false;
            }
            _ => false,
        };
        let caller_protection_function = |f: &FunctionInformation| {
            if f.declaration.get_result_type().is_some() {
                if f.get_result_type().unwrap().is_address_type()
                    && f.get_parameter_types().is_empty()
                {
                    return true;
                }
                if f.get_result_type().unwrap().is_bool_type() && f.get_parameter_types().len() == 1
                {
                    let element = f.get_parameter_types().remove(0);
                    if element.is_address_type() {
                        return true;
                    }
                }
                return false;
            }
            return false;
        };
        if type_info.is_some() {
            let mut properties: Vec<String> = type_info
                .unwrap()
                .properties
                .clone()
                .into_iter()
                .filter(|(_, v)| caller_protection_property(v))
                .map(|(k, _)| k)
                .collect();

            let functions: HashMap<String, Vec<FunctionInformation>> = self
                .types
                .get(t)
                .unwrap()
                .functions
                .clone()
                .into_iter()
                .map(|(k, v)| {
                    (
                        k,
                        v.clone()
                            .into_iter()
                            .filter(|f| caller_protection_function(f))
                            .collect(),
                    )
                })
                .collect();
            let mut functions: Vec<String> = functions
                .into_iter()
                .filter(|(k, v)| !v.is_empty())
                .map(|(k, v)| k)
                .collect();

            properties.append(&mut functions);

            return properties;
        }

        return Vec::new();
    }

    pub fn match_function_call(
        &self,
        f: FunctionCall,
        t: &TypeIdentifier,
        caller_protections: Vec<CallerProtection>,
        scope: ScopeContext,
    ) -> FunctionCallMatchResult {
        let result = FunctionCallMatchResult::Failure(Candidates {
            ..Default::default()
        });

        let arguments = f.arguments.clone();

        let argument_types: Vec<Type> = arguments
            .into_iter()
            .map(|a| {
                self.get_expression_type(a.expression.clone(), t, vec![], vec![], scope.clone())
            })
            .collect();

        println!("BEfore REgular MAtch");

        let regular_match =
            self.match_regular_function(f.clone(), t, caller_protections.clone(), scope.clone());

        let initaliser_match = self.match_initialiser_function(
            f.clone(),
            argument_types.clone(),
            caller_protections.clone(),
        );

        let global_match = self.match_global_function(
            f.clone(),
            argument_types.clone(),
            caller_protections.clone(),
        );

        let result = result.merge(regular_match);
        let result = result.merge(initaliser_match);
        let result = result.merge(global_match);
        return result;
    }

    fn compatible_caller_protections(
        &self,
        source: Vec<CallerProtection>,
        target: Vec<CallerProtection>,
    ) -> bool {
        if target.is_empty() {
            return true;
        }
        for caller_protection in source {
            for parent in &target {
                if !caller_protection.is_sub_protection(parent.clone()) {
                    return false;
                }
            }
        }
        true
    }

    fn function_call_arguments_compatible(
        &self,
        source: FunctionInformation,
        target: FunctionCall,
        t: &TypeIdentifier,
        scope: ScopeContext,
    ) -> bool {
        let no_self_declaration_type = Environment::replace_self(source.get_parameter_types(), t);

        println!("SELF SUPPOSEDLY REPLACED");
        println!("{:?}", no_self_declaration_type);
        let parameters: Vec<VariableDeclaration> = source
            .declaration
            .head
            .parameters
            .clone()
            .into_iter()
            .map(|p| p.as_variable_declaration())
            .collect();

        println!("Parameter Types = ");
        println!("{:?}", parameters.clone());
        println!("Target Types = ");
        println!("{:?}", target.arguments.clone());

        if target.arguments.len() <= source.parameter_identifiers().len()
            && target.arguments.len() >= source.required_parameter_identifiers().len()
        {
            return self.check_parameter_compatibility(
                target.arguments.clone(),
                parameters.clone(),
                t,
                scope.clone(),
                no_self_declaration_type,
            );
        } else {
            return false;
        }
    }

    fn check_parameter_compatibility(
        &self,
        arguments: Vec<FunctionArgument>,
        parameters: Vec<VariableDeclaration>,
        enclosing: &TypeIdentifier,
        scope: ScopeContext,
        declared_types: Vec<Type>,
    ) -> bool {
        let mut index = 0;
        let mut argument_index = 0;

        let required_parameters = parameters.clone();
        let required_parameters: Vec<VariableDeclaration> = required_parameters
            .into_iter()
            .filter(|f| f.expression.is_none())
            .collect();

        while index < required_parameters.len() {
            if arguments[argument_index].identifier.is_some() {
                let argument_name = arguments[argument_index]
                    .identifier
                    .as_ref()
                    .unwrap()
                    .token
                    .clone();

                if argument_name != parameters[index].identifier.token {
                    println!("FLOP ONE");
                    println!("{:?}", argument_name.clone());
                    println!("{:?}", parameters[index].identifier.token.clone());
                    return false;
                }
            } else {
                println!("FLOP TWO");
                return false;
            }

            // Check Types
            let declared_type = declared_types[index].clone();
            let argument_expression = arguments[argument_index].expression.clone();
            let argument_type = self.get_expression_type(
                argument_expression,
                enclosing,
                vec![],
                vec![],
                scope.clone(),
            );

            println!("TYPE CHECKING");
            println!("{:?}", argument_type);
            println!("{:?}", declared_type);

            if declared_type != argument_type {
                return false;
            }

            index += 1;
            argument_index += 1;
        }

        while index < required_parameters.len() && argument_index < arguments.len() {
            if arguments[argument_index].identifier.is_some() {
            } else {
                let declared_type = declared_types[index].clone();

                let argument_expression = arguments[argument_index].expression.clone();
                let argument_type = self.get_expression_type(
                    argument_expression,
                    enclosing,
                    vec![],
                    vec![],
                    scope.clone(),
                );
                //TODO replacing self
                if declared_type != argument_type {
                    return false;
                }
                index += 1;
                argument_index += 1;
                continue;
            }

            while index < parameters.len() {
                if arguments[argument_index].identifier.is_some() {
                    let argument_name = arguments[argument_index]
                        .identifier
                        .as_ref()
                        .unwrap()
                        .token
                        .clone();
                    if argument_name != parameters[index].identifier.token {
                        index += 1;
                    }
                } else {
                    break;
                }
            }

            if index == parameters.len() {
                // Identifier was not found
                return false;
            }

            // Check Types
            let declared_type = declared_types[index].clone();
            let argument_expression = arguments[argument_index].expression.clone();
            let argument_type = self.get_expression_type(
                argument_expression,
                enclosing,
                vec![],
                vec![],
                scope.clone(),
            );

            if declared_type != argument_type {
                return false;
            }

            index += 1;
            argument_index += 1;
        }

        if argument_index < arguments.len() {
            return false;
        }
        return true;
    }

    fn match_regular_function(
        &self,
        f: FunctionCall,
        t: &TypeIdentifier,
        c: Vec<CallerProtection>,
        scope: ScopeContext,
    ) -> FunctionCallMatchResult {
        let mut candidates = Vec::new();

        let arguments = f.arguments.clone();

        let argument_types: Vec<Type> = arguments
            .into_iter()
            .map(|a| {
                self.get_expression_type(a.expression.clone(), t, vec![], vec![], scope.clone())
            })
            .collect();

        let type_info = self.types.get(t);

        println!("{:?}", t);
        if type_info.is_some() {
            println!("Type Info is some");

            let functions = self.types.get(t).unwrap().all_functions();
            // println!("{:?}", functions.clone());
            let functions = functions.get(&f.identifier.token).clone();
            let functions = functions.clone();
            if functions.is_some() {
                let functions = functions.unwrap();
                for function in functions {
                    let current_function = function.clone();
                    println!("Function Present");
                    println!("{:?}", f.clone());
                    if self.function_call_arguments_compatible(
                        current_function.clone(),
                        f.clone(),
                        t,
                        scope.clone(),
                    ) {
                        if self.compatible_caller_protections(
                            c.clone(),
                            current_function.caller_protection.clone(),
                        ) {
                            println!("SUCEEDED>");
                            return FunctionCallMatchResult::MatchedFunction(current_function);
                        }
                        println!("FLOOOPPPPPED HERE");
                    }
                    println!("FLOOOPPPPPED HERE");
                    candidates.push(function.clone());
                    continue;
                }
            }
        }

        let matched_candidates: Vec<FunctionInformation> = candidates
            .clone()
            .into_iter()
            .filter(|c| {
                let p_types = c.get_parameter_types();
                if p_types.len() != argument_types.len() {
                    return false;
                }
                let mut arg_types = argument_types.clone();
                for p in p_types {
                    if p != arg_types.remove(0) {
                        return false;
                    }
                }
                true
            })
            .collect();

        let matched_candidates: Vec<CallableInformation> = matched_candidates
            .into_iter()
            .map(|i| CallableInformation::FunctionInformation(i.clone()))
            .collect();

        if !matched_candidates.is_empty() {
            let matched_candidates = Candidates {
                candidates: matched_candidates,
            };
            return FunctionCallMatchResult::MatchedFunctionWithoutCaller(matched_candidates);
        }

        let candidates: Vec<CallableInformation> = candidates
            .into_iter()
            .map(|i| CallableInformation::FunctionInformation(i.clone()))
            .collect();

        let candidates = Candidates { candidates };

        return FunctionCallMatchResult::Failure(candidates);
    }

    fn match_fallback_function(&self, f: FunctionCall, c: Vec<CallerProtection>) {
        let mut candidates = Vec::new();
        let typeInfo = self.types.get(&f.identifier.token.clone());
        if typeInfo.is_some() {
            let fallbacks = &typeInfo.unwrap().fallbacks;
            for fallback in fallbacks {
                if self
                    .compatible_caller_protections(c.clone(), fallback.caller_protections.clone())
                {
                    // TODO Return MatchedFallBackFunction
                } else {
                    candidates.push(fallback);
                    continue;
                }
            }
        }
        // TODO return failure
    }

    fn match_initialiser_function(
        &self,
        f: FunctionCall,
        argument_types: Vec<Type>,
        c: Vec<CallerProtection>,
    ) -> FunctionCallMatchResult {
        let mut candidates = Vec::new();

        let type_info = self.types.get(&f.identifier.token.clone());
        // println!("initititititiiititiitititititititADddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd some");
        // println!("{:?}", f.identifier.token.clone());
        if type_info.is_some() {
            println!("TYpe is some");
            println!("{:?}", f.identifier.token.clone());
            println!("{:?}", f.arguments.clone());
            let initialisers = &type_info.unwrap().initialisers;
            for initialiser in initialisers {
                println!("ADddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd some");

                let parameter_types = initialiser.parameter_types();
                println!("{:?}", parameter_types.clone());
                let mut equal_types = true;
                for argument_type in argument_types.clone() {
                    if !parameter_types.contains(&argument_type) {
                        equal_types = false;
                    }
                }

                println!("{:?}", equal_types.clone());
                if equal_types
                    && self.compatible_caller_protections(
                        c.clone(),
                        initialiser.caller_protections.clone(),
                    )
                {
                    return FunctionCallMatchResult::MatchedInitializer(initialiser.clone());
                } else {
                    candidates.push(initialiser);
                    continue;
                }
            }
        }
        let candidates: Vec<CallableInformation> = candidates
            .into_iter()
            .map(|i| CallableInformation::SpecialInformation(i.clone()))
            .collect();

        let candidates = Candidates { candidates };
        return FunctionCallMatchResult::Failure(candidates);
    }

    fn match_global_function(
        &self,
        f: FunctionCall,
        argument_types: Vec<Type>,
        c: Vec<CallerProtection>,
    ) -> FunctionCallMatchResult {
        println!("ENTER MATCHING GLOBAL");
        let token = f.identifier.token.clone();
        let mut candidates = Vec::new();
        let type_info = self.types.get(&"Quartz_Global".to_string());
        if type_info.is_some() {
            let functions = &type_info.unwrap().functions;
            let functions = functions.get(&f.identifier.token.clone());
            let functions = functions.clone();

            if functions.is_some() {
                let functions = functions.unwrap();

                for function in functions {
                    let parameter_types = function.get_parameter_types();
                    let mut equal_types = true;
                    for argument_type in argument_types.clone() {
                        if !parameter_types.contains(&argument_type) {
                            equal_types = false;
                        }
                    }
                    if equal_types
                        && self.compatible_caller_protections(
                            c.clone(),
                            function.caller_protection.clone(),
                        )
                    {
                        return FunctionCallMatchResult::MatchedGlobalFunction(function.clone());
                    } else {
                        candidates.push(function);
                        continue;
                    }
                }
            }
        }
        let candidates: Vec<CallableInformation> = candidates
            .into_iter()
            .map(|i| CallableInformation::FunctionInformation(i.clone()))
            .collect();
        let candidates = Candidates { candidates };
        println!("{:?}", f.identifier.token.clone());
        // println!("{:?}", candidates.clone());
        if token == "fatalError".to_string() {
            unimplemented!()
        }
        return FunctionCallMatchResult::Failure(candidates);
    }

    pub fn is_runtime_function_call(function_call: &FunctionCall) -> bool {
        let ident = function_call.identifier.token.clone();
        ident.starts_with("Quartz_")
    }

    pub fn get_expression_type(
        &self,
        expression: Expression,
        t: &TypeIdentifier,
        type_states: Vec<TypeState>,
        caller_protections: Vec<CallerProtection>,
        scope: ScopeContext,
    ) -> Type {
        match expression {
            Expression::Identifier(i) => {
                if i.enclosing_type.is_none() {
                    let result_type = scope.type_for(i.token.clone());
                    if result_type.is_some() {
                        let result_type = result_type.unwrap();
                        return if let Type::InoutType(inout) = result_type {
                            *inout.key_type
                        } else {
                            result_type
                        };
                    }
                }

                let enclosing_type = if i.enclosing_type.is_some() {
                    let enclosing = i.enclosing_type.as_ref();
                    enclosing.unwrap()
                } else {
                    t
                };

                return self.get_property_type(i.token.clone(), enclosing_type, scope);
            }
            Expression::BinaryExpression(b) => {
                return self.get_binary_expression_type(
                    b,
                    t,
                    type_states,
                    caller_protections,
                    scope,
                );
            }
            Expression::InoutExpression(e) => {
                let key_type = self.get_expression_type(
                    *e.expression,
                    t,
                    type_states,
                    caller_protections,
                    scope,
                );

                return Type::InoutType(InoutType {
                    key_type: Box::from(key_type),
                });
            }
            Expression::ExternalCall(e) => {
                return self.get_expression_type(
                    Expression::BinaryExpression(e.function_call),
                    t,
                    type_states,
                    caller_protections,
                    scope,
                )
            }
            Expression::FunctionCall(f) => {
                let enclosing_type = if f.identifier.enclosing_type.is_some() {
                    let enclosing = f.identifier.enclosing_type.as_ref();
                    enclosing.unwrap()
                } else {
                    t
                };

                return self.get_function_call_type(
                    f.clone(),
                    enclosing_type,
                    type_states,
                    caller_protections,
                    scope,
                );
            }
            Expression::VariableDeclaration(v) => return v.variable_type,
            Expression::BracketedExpression(e) => {
                return self.get_expression_type(
                    *e.expression,
                    t,
                    type_states,
                    caller_protections,
                    scope,
                )
            }
            Expression::AttemptExpression(a) => {
                return self.get_attempt_expression_type(
                    a,
                    t,
                    type_states,
                    caller_protections,
                    scope,
                )
            }
            Expression::Literal(l) => {
                return self.get_literal_type(l, t, type_states, caller_protections, scope)
            }
            Expression::ArrayLiteral(a) => {
                return self.get_array_literal_type(a, t, type_states, caller_protections, scope)
            }
            Expression::DictionaryLiteral(_) => unimplemented!(),
            Expression::SelfExpression => Type::UserDefinedType(Identifier {
                token: t.clone(),
                enclosing_type: None,
                line_info: Default::default(),
            }),
            Expression::SubscriptExpression(s) => {
                //    Get Identifier Type
                let identifer_type = self.get_expression_type(
                    Expression::Identifier(s.base_expression.clone()),
                    t,
                    vec![],
                    vec![],
                    scope,
                );

                match identifer_type {
                    Type::ArrayType(a) => *a.key_type,
                    Type::FixedSizedArrayType(a) => *a.key_type,
                    Type::DictionaryType(d) => *d.key_type,
                    _ => Type::Error,
                }
            }
            Expression::RangeExpression(r) => {
                return self.get_range_type(r, t, type_states, caller_protections, scope)
            }
            Expression::RawAssembly(_, _) => unimplemented!(),
            Expression::CastExpression(c) => c.cast_type,
            Expression::Sequence(_) => unimplemented!(),
        }
    }

    pub fn get_property_type(&self, name: String, t: &TypeIdentifier, scope: ScopeContext) -> Type {
        let enclosing = self.types.get(t);
        // println!("{:?}", t);
        if enclosing.is_some() {
            let enclosing = enclosing.unwrap();
            // println!("{:?}", enclosing.clone());
            // println!("{:?}", name.clone());
            if enclosing.properties.get(name.as_str()).is_some() {
                return self
                    .types
                    .get(t)
                    .unwrap()
                    .properties
                    .get(name.as_str())
                    .unwrap()
                    .property
                    .get_type();
            }

            if enclosing.functions.get(name.as_str()).is_some() {
                unimplemented!()
            }
        }

        if scope.type_for(name.clone()).is_some() {
            unimplemented!()
        }

        Type::Error
    }

    fn get_literal_type(
        &self,
        literal: Literal,
        t: &TypeIdentifier,
        type_states: Vec<TypeState>,
        caller_protections: Vec<CallerProtection>,
        scope: ScopeContext,
    ) -> Type {
        match literal {
            Literal::BooleanLiteral(_) => Type::Bool,
            Literal::AddressLiteral(_) => Type::Address,
            Literal::StringLiteral(_) => Type::String,
            Literal::IntLiteral(_) => Type::Int,
            Literal::FloatLiteral(_) => Type::Int,
        }
    }

    fn get_attempt_expression_type(
        &self,
        expression: AttemptExpression,
        t: &TypeIdentifier,
        type_states: Vec<TypeState>,
        caller_protections: Vec<CallerProtection>,
        scope: ScopeContext,
    ) -> Type {
        if expression.is_soft() {
            return Type::Bool;
        }

        let function_call = expression.function_call.clone();

        let enclosing_type = if function_call.identifier.enclosing_type.is_some() {
            let enclosing = function_call.identifier.enclosing_type.clone();
            enclosing.unwrap()
        } else {
            t.clone()
        };

        return self.get_expression_type(
            Expression::FunctionCall(function_call),
            &enclosing_type,
            type_states,
            caller_protections,
            scope,
        );
    }

    fn get_range_type(
        &self,
        expression: RangeExpression,
        t: &TypeIdentifier,
        type_states: Vec<TypeState>,
        caller_protections: Vec<CallerProtection>,
        scope: ScopeContext,
    ) -> Type {
        let element_type = self.get_expression_type(
            *expression.start_expression,
            t,
            type_states.clone(),
            caller_protections.clone(),
            scope.clone(),
        );
        let bound_type = self.get_expression_type(
            *expression.end_expression,
            t,
            type_states,
            caller_protections,
            scope,
        );
        if element_type != bound_type {
            return Type::Error;
        }

        return Type::RangeType(RangeType {
            key_type: Box::new(element_type),
        });
    }

    fn get_binary_expression_type(
        &self,
        b: BinaryExpression,
        t: &TypeIdentifier,
        type_states: Vec<TypeState>,
        caller_protections: Vec<CallerProtection>,
        scope: ScopeContext,
    ) -> Type {
        if b.op.is_boolean() {
            return Type::Bool;
        }

        if let BinOp::Dot = b.op {
            let lhs_type = self.get_expression_type(
                *b.lhs_expression,
                t,
                type_states.clone(),
                caller_protections.clone(),
                scope.clone(),
            );
            match lhs_type {
                Type::ArrayType(_) => {
                    if let Expression::Identifier(i) = *b.rhs_expression {
                        if i.token == "size" {
                            return Type::Int;
                        }
                    }
                    println!("Arrays only have property 'size'");
                    return Type::Error;
                }
                Type::FixedSizedArrayType(_) => {
                    if let Expression::Identifier(i) = *b.rhs_expression {
                        if i.token == "size" {
                            return Type::Int;
                        }
                    }
                    println!("Arrays only have property 'size'");
                    return Type::Error;
                }
                Type::DictionaryType(d) => {
                    if let Expression::Identifier(i) = *b.rhs_expression {
                        if i.token == "size" {
                            return Type::Int;
                        } else if i.token == "keys" {
                            return Type::ArrayType(ArrayType {
                                key_type: d.key_type,
                            });
                        }
                    }
                    println!("Dictionaries only have properties size and keys");
                    return Type::Error;
                }
                _ => {}
            };
            let rhs_type = self.get_expression_type(
                *b.rhs_expression,
                &lhs_type.name(),
                type_states.clone(),
                caller_protections.clone(),
                scope.clone(),
            );
            return rhs_type;
        }

        return self.get_expression_type(
            *b.rhs_expression,
            t,
            type_states,
            caller_protections,
            scope,
        );
    }

    fn get_array_literal_type(
        &self,
        a: ArrayLiteral,
        t: &TypeIdentifier,
        type_states: Vec<TypeState>,
        caller_protections: Vec<CallerProtection>,
        scope: ScopeContext,
    ) -> Type {
        let mut element_type: Option<Type> = None;

        for elements in a.elements {
            let elements_type = self.get_expression_type(
                elements.clone(),
                t,
                type_states.clone(),
                caller_protections.clone(),
                scope.clone(),
            );

            if element_type.is_some() {
                let comparison_type = element_type.clone();
                let comparison_type = comparison_type.unwrap();
                if comparison_type != elements_type {
                    return Type::Error;
                }
            }
            if element_type.is_none() {
                element_type = Some(elements_type)
            }
        }
        let result_type = if element_type.is_some() {
            element_type.unwrap()
        } else {
            //TODO change to Type::Any
            Type::Error
        };
        return Type::ArrayType(ArrayType {
            key_type: Box::new(result_type),
        });
    }

    fn get_function_call_type(
        &self,
        f: FunctionCall,
        t: &TypeIdentifier,
        type_states: Vec<TypeState>,
        caller_protections: Vec<CallerProtection>,
        scope: ScopeContext,
    ) -> Type {
        let identifier = f.identifier.clone();
        let function_call = self.match_function_call(f, t, caller_protections, scope);
        match function_call {
            FunctionCallMatchResult::MatchedFunction(m) => {
                return m.get_result_type().unwrap_or(Type::Error);
            }
            FunctionCallMatchResult::MatchedFunctionWithoutCaller(m) => {
                if m.candidates.len() == 1 {
                    let first = m.candidates.first().clone();
                    let first = first.unwrap();
                    return if let CallableInformation::FunctionInformation(fi) = first {
                        fi.get_result_type().unwrap_or(Type::Error)
                    } else {
                        Type::Error
                    };
                }
                return Type::Error;
            }
            FunctionCallMatchResult::MatchedInitializer(m) => {
                return Type::UserDefinedType(identifier)
            }
            (_) => {
                return Type::Error;
            }
        }
    }

    pub fn property_offset(&self, property: String, t: &TypeIdentifier) -> u64 {
        let mut offset_map: HashMap<String, u64> = HashMap::new();
        let mut offset: u64 = 0;

        let root_type = self.types.get(t);
        if root_type.is_some() {
            let root_type = root_type.unwrap();
            let ordered_properties = root_type.ordered_properties.clone();
            let ordered_properties: Vec<String> = ordered_properties
                .into_iter()
                .take_while(|p| p.to_string() != property)
                .collect();
            for p in ordered_properties {
                offset_map.insert(p.clone(), offset);
                let property_type = root_type.properties.get(&p).clone();
                let property_type = property_type.unwrap();
                let property_size = self.type_size(property_type.property.get_type());

                offset = offset + property_size;
            }
            return offset;
        } else {
            return offset;
        }
    }

    pub fn replace_self(list: Vec<Type>, enclosing: &TypeIdentifier) -> Vec<Type> {
        let result: Vec<Type> = list
            .into_iter()
            .map(|t| t.replacing_self(enclosing))
            .collect();
        return result;
    }

    fn external_trait_init() -> SpecialSignatureDeclaration {
        SpecialSignatureDeclaration {
            special_token: "init".to_string(),
            attributes: vec![],
            modifiers: vec![],
            mutates: vec![],
            parameters: vec![Parameter {
                identifier: Identifier {
                    token: "address".to_string(),
                    enclosing_type: None,
                    line_info: Default::default(),
                },
                type_assignment: Type::Address,
                expression: None,
                line_info: Default::default(),
            }],
        }
    }

    pub fn type_size(&self, input_type: Type) -> u64 {
        match input_type {
            Type::Bool => 1,
            Type::Int => 1,
            Type::String => 1,
            Type::Address => 1,
            Type::QuartzType(_) => unimplemented!(),
            Type::InoutType(_) => unimplemented!(),
            Type::ArrayType(_) => 1,
            Type::RangeType(_) => unimplemented!(),
            Type::FixedSizedArrayType(a) => {
                let key_size = self.type_size(*a.key_type.clone());
                let size = a.size.clone();
                key_size * size
            }
            Type::DictionaryType(_) => unimplemented!(),
            Type::UserDefinedType(i) => {
                if self.is_enum_declared(&i.token) {
                    unimplemented!()
                }

                let mut acc = 0;
                let enclosing = self.types.get(&i.token);
                let enclosing = enclosing.unwrap();
                let enclosing_properties = enclosing.properties.clone();

                for (_, v) in enclosing_properties {
                    acc = acc + self.type_size(v.property.get_type())
                }

                return acc;
            }
            Type::Error => unimplemented!(),
            Type::SelfType => unimplemented!(),
            Type::Solidity(_) => unimplemented!(),
        }
    }
}
