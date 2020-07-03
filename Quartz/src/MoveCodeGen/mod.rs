use super::context::*;
use super::environment::*;
use super::AST::*;
use crate::MoveCodeGen::MoveIRTransfer::Move;
use std::fmt;
use std::fs::File;
use std::io::Write;
use std::path::Path;

pub mod MovePreProcessor;

#[derive(Debug, Clone)]
pub enum MovePosition {
    Left,
    Accessed,
    Normal,
    Inout,
}

impl Default for MovePosition {
    fn default() -> Self {
        MovePosition::Normal
    }
}

pub fn generate(module: Module, context: &mut Context) {

    let trait_declarations: Vec<TraitDeclaration> = module
        .declarations
        .clone()
        .into_iter()
        .filter_map(|d| match d {
            TopLevelDeclaration::TraitDeclaration(t) => Some(t),
            _ => None,
        })
        .collect();

    let mut contracts: Vec<MoveContract> = Vec::new();
    for declaration in &module.declarations {
        if let TopLevelDeclaration::ContractDeclaration(c) = declaration {
            let contract_behaviour_declarations: Vec<ContractBehaviourDeclaration> = module
                .declarations
                .clone()
                .into_iter()
                .filter_map(|d| match d {
                    TopLevelDeclaration::ContractBehaviourDeclaration(cbd) => Some(cbd),
                    (_) => None,
                })
                .filter(|cbd| cbd.identifier.token == c.identifier.token)
                .collect();

            let struct_declarations: Vec<StructDeclaration> = module
                .declarations
                .clone()
                .into_iter()
                .filter_map(|d| match d {
                    TopLevelDeclaration::StructDeclaration(s) => Some(s),
                    (_) => None,
                })
                .collect();

            let asset_declarations: Vec<AssetDeclaration> = module
                .declarations
                .clone()
                .into_iter()
                .filter_map(|d| match d {
                    TopLevelDeclaration::AssetDeclaration(a) => Some(a),
                    (_) => None,
                })
                .collect();

            let contract = MoveContract {
                contract_declaration: c.clone(),
                contract_behaviour_declarations,
                struct_declarations,
                asset_declarations,
                environment: context.environment.clone(),
                external_traits: trait_declarations.clone(),
            };
            contracts.push(contract);
        }
    }

    for contract in contracts {
        let c = contract.generate();

        let mut code = CodeGen {
            code: "".to_string(),
            indent_level: 0,
            indent_size: 2,
        };

        code.add(c);
        print!("{}", code.code);

        let name = contract.contract_declaration.identifier.token.clone();
        let path = &format!("output/{name}.mvir", name = name);
        let path = Path::new(path);
        let display = path.display();

        let mut file = match File::create(&path) {
            Err(why) => panic!("couldn't create {}: {}", display, why),
            Ok(file) => file,
        };

        match file.write_all(code.code.as_bytes()) {
            Err(why) => panic!("couldn't write to {}: {}", display, why),
            Ok(_) => println!("successfully wrote to {}", display),
        }
    }
}

pub struct MoveContract {
    pub contract_declaration: ContractDeclaration,
    pub contract_behaviour_declarations: Vec<ContractBehaviourDeclaration>,
    pub struct_declarations: Vec<StructDeclaration>,
    pub asset_declarations: Vec<AssetDeclaration>,
    pub external_traits: Vec<TraitDeclaration>,
    pub environment: Environment,
}

impl MoveContract {
    fn generate(&self) -> String {
        let imports = self.external_traits.clone();
        let imports: Vec<TraitDeclaration> = imports
            .into_iter()
            .filter_map(|i| {
                if i.get_module_address().is_some() {
                    Some(i)
                } else {
                    None
                }
            })
            .collect();
        let mut imports: Vec<MoveIRStatement> = imports
            .into_iter()
            .map(|i| {
                let module_address = i.get_module_address();
                let module_address = module_address.unwrap();
                MoveIRStatement::Import(MoveIRModuleImport {
                    name: i.identifier.token,
                    address: module_address,
                })
            })
            .collect();
        let mut runtime_imports = MoveRuntimeTypes::get_all_imports();
        imports.append(&mut runtime_imports);
        let imports = imports.clone();

        let import_code: Vec<String> = imports.into_iter().map(|a| format!("{}", a)).collect();
        let import_code = import_code.join("\n");


        let runtime_funcions = MoveRuntimeFunction::get_all_functions();
        let runtime_functions = runtime_funcions.join("\n\n");

        let functions: Vec<FunctionDeclaration> = self
            .contract_behaviour_declarations
            .clone()
            .into_iter()
            .flat_map(|c| {
                c.members.into_iter().filter_map(|m| match m {
                    ContractBehaviourMember::FunctionDeclaration(f) => Some(f),
                    (_) => None,
                })
            })
            .collect();

        let functions: Vec<String> = functions
            .into_iter()
            .map(|f| MoveFunction {
                function_declaration: f,
                environment: self.environment.clone(),
                IsContractFunction: false,
                enclosing_type: self.contract_declaration.identifier.clone(),
            })
            .map(|f| f.generate(true))
            .collect();
        let functions = functions.join("\n\n");

        let function_context = FunctionContext {
            environment: self.environment.clone(),
            ScopeContext: Default::default(),
            enclosing_type: "".to_string(),
            block_stack: vec![MoveIRBlock { statements: vec![] }],
            in_struct_function: false,
            is_constructor: false,
        };

        let members: Vec<VariableDeclaration> = self
            .contract_declaration
            .contract_members
            .clone()
            .into_iter()
            .filter_map(|m| {
                if let ContractMember::VariableDeclaration(v) = m {
                    Some(v)
                } else {
                    None
                }
            })
            .collect();

        let members: Vec<VariableDeclaration> = members
            .into_iter()
            .filter(|m| !m.variable_type.is_dictionary_type())
            .collect();
        let members: Vec<String> = members
            .into_iter()
            .map(|v| {
                let declaration =
                    MoveFieldDeclaration { declaration: v }.generate(&function_context);
                return format!("{declaration}", declaration = declaration);
            })
            .collect();
        let members = members.join(",\n");

        let dict_resources: Vec<VariableDeclaration> = self
            .contract_declaration
            .contract_members
            .clone()
            .into_iter()
            .filter_map(|m| {
                if let ContractMember::VariableDeclaration(v) = m {
                    Some(v)
                } else {
                    None
                }
            })
            .collect();

        let dict_resources: Vec<VariableDeclaration> = dict_resources
            .into_iter()
            .filter(|m| m.variable_type.is_dictionary_type())
            .collect();
        let dict_runtime = dict_resources.clone();
        let dict_resources: Vec<String> = dict_resources
            .into_iter()
            .map(|d| {
                let result_type = MoveType::move_type(
                    d.variable_type.clone(),
                    Option::from(self.environment.clone()),
                );
                let result_type = result_type.generate(&function_context);
                format!(
                    "resource {name} {{ \n value: {dic_type} \n }}",
                    name = mangle_dictionary(d.identifier.token.clone()),
                    dic_type = result_type
                )
            })
            .collect();

        let dict_resources = dict_resources.join("\n\n");


        let dict_runtime: Vec<String> = dict_runtime
            .into_iter()
            .map(|d| {
                let r_name = mangle_dictionary(d.identifier.token.clone());
                let result_type = MoveType::move_type(
                    d.variable_type.clone(),
                    Option::from(self.environment.clone()),
                );
                let result_type = result_type.generate(&function_context);
                format!(
                    "_get_{r_name}(__address_this: address): {r_type} acquires {r_name} {{
    let this: &mut Self.{r_name};
    let temp: &{r_type};
    let result: {r_type};
    this = borrow_global_mut<{r_name}>(move(__address_this));
    temp = &copy(this).value;
    result = *copy(temp);
    return move(result);
  }}

        _insert_{r_name}(__address_this: address, v: {r_type}) acquires {r_name} {{
    let new_value: Self.{r_name};
    let cur: &mut Self.{r_name};
    let b: bool;
    b = exists<{r_name}>(copy(__address_this));
    if (move(b)) {{
      cur = borrow_global_mut<{r_name}>(move(__address_this));
      *(&mut move(cur).value) = move(v);
    }} else {{
       new_value = {r_name} {{
      value: move(v)
    }};
    move_to_sender<{r_name}>(move(new_value));
    }}
    return;
  }}",
                    r_name = r_name,
                    r_type = result_type
                )
            })
            .collect();

        let dict_runtime = dict_runtime.join("\n\n");

        let structs: Vec<StructDeclaration> = self
            .struct_declarations
            .clone()
            .into_iter()
            .filter(|s| s.identifier.token != format!("Quartz_Global"))
            .collect();
        let mut structs: Vec<String> = structs
            .into_iter()
            .map(|s| {
                MoveStruct {
                    struct_declaration: s,
                    environment: self.environment.clone(),
                }
                .generate()
            })
            .collect();
        let mut runtime_structs = MoveRuntimeTypes::get_all_declarations();
        structs.append(&mut runtime_structs);
        let structs = structs.clone();
        let structs = structs.join("\n\n");

        let struct_functions: Vec<String> = self
            .struct_declarations
            .clone()
            .into_iter()
            .map(|s| {
                MoveStruct {
                    struct_declaration: s,
                    environment: self.environment.clone(),
                }
                .generate_all_functions()
            })
            .collect();
        let struct_functions = struct_functions.join("\n\n");

        let assets = format!("");

        let assets: Vec<String> = self
            .asset_declarations
            .clone()
            .into_iter()
            .map(|a| {
                MoveAsset {
                    declaration: a,
                    environment: self.environment.clone(),
                }
                .generate()
            })
            .collect();
        let assets = assets.join("\n");

        let asset_functions: Vec<String> = self
            .asset_declarations
            .clone()
            .into_iter()
            .map(|s| {
                MoveAsset {
                    declaration: s,
                    environment: self.environment.clone(),
                }
                .generate_all_functions()
            })
            .collect();
        let asset_functions = asset_functions.join("\n\n");

        let mut contract_behaviour_declaration = None;
        let mut initialiser_declaration = None;
        for declarations in self.contract_behaviour_declarations.clone() {
            for member in declarations.members.clone() {
                if let ContractBehaviourMember::SpecialDeclaration(s) = member {
                    if s.is_init() && s.is_public() {
                        contract_behaviour_declaration = Some(declarations.clone());
                        initialiser_declaration = Some(s.clone());
                    }
                }
            }
        }

        if initialiser_declaration.is_none() {
            panic!("Public Initiliaser not found")
        }
        let initialiser_declaration = initialiser_declaration.unwrap();
        let contract_behaviour_declaration = contract_behaviour_declaration.unwrap();

        let scope = ScopeContext {
            parameters: vec![],
            local_variables: vec![],
            counter: 0,
        };

        let function_context = FunctionContext {
            environment: self.environment.clone(),
            ScopeContext: scope,
            enclosing_type: self.contract_declaration.identifier.token.clone(),
            block_stack: vec![MoveIRBlock { statements: vec![] }],
            in_struct_function: false,
            is_constructor: false,
        };

        let params = initialiser_declaration.head.parameters.clone();
        let params: Vec<MoveIRExpression> = params
            .into_iter()
            .map(|p| {
                MoveIdentifier {
                    identifier: p.identifier,
                    position: MovePosition::Left,
                }
                .generate(&function_context, false, false)
            })
            .collect();
        let params: Vec<String> = params.into_iter().map(|i| format!("{}", i)).collect();

        let params_values = initialiser_declaration.head.parameters.clone();
        let params_values: Vec<MoveIRExpression> = params_values
            .into_iter()
            .map(|p| {
                MoveIdentifier {
                    identifier: p.identifier,
                    position: MovePosition::Left,
                }
                .generate(&function_context, true, false)
            })
            .collect();
        let params_values: Vec<String> = params_values
            .into_iter()
            .map(|i| format!("{}", i))
            .collect();
        let params_values = params_values.join(", ");

        let param_types = initialiser_declaration.head.parameters.clone();
        let param_types: Vec<MoveIRType> = param_types
            .into_iter()
            .map(|p| {
                MoveType::move_type(p.type_assignment, Option::from(self.environment.clone()))
                    .generate(&function_context)
            })
            .collect();
        let param_types: Vec<String> = param_types.into_iter().map(|i| format!("{}", i)).collect();

        let parameters: Vec<String> = params
            .into_iter()
            .zip(param_types)
            .map(|(k, v)| format!("{name}: {t}", name = k, t = v))
            .collect();

        let parameters = parameters.join(", ");


        let mut statements = initialiser_declaration.body.clone();
        let properties = self
            .contract_declaration
            .get_variable_declarations_without_dict();

        let mut function_context = FunctionContext {
            environment: self.environment.clone(),
            ScopeContext: Default::default(),
            enclosing_type: self.contract_declaration.identifier.token.clone(),
            block_stack: vec![MoveIRBlock { statements: vec![] }],
            in_struct_function: false,
            is_constructor: true,
        };

        let mut body = format!("");

        for property in properties {
            let property_type = MoveType::move_type(
                property.variable_type.clone(),
                Option::from(self.environment.clone()),
            );
            let property_type = property_type.generate(&function_context);
            function_context.emit(MoveIRStatement::Expression(
                MoveIRExpression::VariableDeclaration(MoveIRVariableDeclaration {
                    identifier: format!("__this_{}", property.identifier.token),
                    declaration_type: property_type,
                }),
            ));
        }

        let unassigned = self
            .contract_declaration
            .get_variable_declarations_without_dict();
        let mut unassigned: Vec<Identifier> =
            unassigned.into_iter().map(|v| v.identifier).collect();


        while !(statements.is_empty() || unassigned.is_empty()) {
            let statement = statements.remove(0);
            if let Statement::Expression(e) = statement.clone() {
                if let Expression::BinaryExpression(b) = e {
                    if let BinOp::Equal = b.op {
                        if let Expression::Identifier(i) = *b.lhs_expression.clone() {
                            if i.enclosing_type.is_some() {
                                let enclosing = i.enclosing_type.clone();
                                let enclosing = enclosing.unwrap();
                                if enclosing == self.contract_declaration.identifier.token.clone() {
                                    unassigned = unassigned
                                        .into_iter()
                                        .filter(|u| u.token != i.token)
                                        .collect();
                                }
                            }
                            if let Expression::BinaryExpression(lb) = *b.lhs_expression.clone() {
                                let op = lb.op.clone();
                                let lhs = *lb.lhs_expression;
                                let rhs = *lb.rhs_expression;
                                if let BinOp::Dot = op {
                                    if let Expression::SelfExpression = lhs {
                                        if let Expression::Identifier(i) = rhs {
                                            unassigned = unassigned
                                                .into_iter()
                                                .filter(|u| u.token != i.token)
                                                .collect();
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                let move_statement = MoveStatement {
                    statement: statement.clone(),
                }
                .generate(&mut function_context);
                function_context.emit(move_statement);
            }
        }

        let fields = self
            .contract_declaration
            .get_variable_declarations_without_dict();
        let fields: Vec<(String, MoveIRExpression)> = fields
            .into_iter()
            .map(|p| {
                (
                    p.identifier.token.clone(),
                    MoveIRExpression::Transfer(MoveIRTransfer::Move(Box::from(
                        MoveIRExpression::Identifier(format!("__this_{}", p.identifier.token)),
                    ))),
                )
            })
            .collect();
        let constructor = MoveIRExpression::StructConstructor(MoveIRStructConstructor {
            identifier: Identifier {
                token: format!("T"),
                enclosing_type: None,
                line_info: Default::default(),
            },
            fields: fields,
        });

        if !(statements.is_empty()) {

            function_context.is_constructor = false;

            let shadow = format!("Quartz$self");

            let selfType = MoveType::move_type(
                Type::type_from_identifier(self.contract_declaration.identifier.clone()),
                Option::from(self.environment.clone()),
            )
            .generate(&function_context);

            let emit = MoveIRExpression::VariableDeclaration(MoveIRVariableDeclaration {
                identifier: "this".to_string(),
                declaration_type: MoveIRType::MutableReference(Box::from(selfType.clone())),
            });
            function_context.emit(MoveIRStatement::Expression(emit));

            let emit = MoveIRExpression::VariableDeclaration(MoveIRVariableDeclaration {
                identifier: mangle(shadow.clone()),
                declaration_type: selfType,
            });

            function_context.emit(MoveIRStatement::Expression(emit));

            let self_identifier = MoveSelf {
                token: format!("self"),
                position: Default::default(),
            };
            let self_identifier = Identifier {
                token: self_identifier.token.clone(),
                enclosing_type: None,
                line_info: Default::default(),
            };

            let shadow_identifier = Identifier {
                token: shadow.clone(),
                enclosing_type: None,
                line_info: Default::default(),
            };

            let mut scope = function_context.ScopeContext.clone();
            scope.local_variables.push(VariableDeclaration {
                declaration_token: None,
                identifier: self_identifier,
                variable_type: Type::InoutType(InoutType {
                    key_type: Box::new(Type::UserDefinedType(Identifier {
                        token: function_context.enclosing_type.clone(),
                        enclosing_type: None,
                        line_info: Default::default(),
                    })),
                }),
                expression: None,
            });

            while !statements.is_empty() {
                let statement = statements.remove(0);
                let statement = MoveStatement { statement }.generate(&mut function_context);
                function_context.emit(statement);
            }

            function_context.emit_release_references();
            body = function_context.generate()
        } else {
            function_context.emit_release_references();
            function_context.emit(MoveIRStatement::Return(constructor));
            body = function_context.generate()
        }

        let initialiser = format!(
            "new({params}): Self.T {{ {body} }} \n\n \
             public publish({params}) {{ \n move_to_sender<T>(Self.new({values})); \n return; \n }}",
            params = parameters,
            body = body,
            values = params_values
        );


        return format!("module {name} {{ \n  {imports} \n resource T {{ \n {members} \n }} {dict_resources} \n {assets}  \n {structs} \n {init} \n \n {asset_functions} \n \n {struct_functions} \n {functions} \n {runtime} \n {dict_runtime} }}"
                 , name = self.contract_declaration.identifier.token, functions = functions, members = members,
                             assets = assets, asset_functions = asset_functions, structs = structs, dict_resources = dict_resources,
                             init = initialiser, struct_functions = struct_functions, imports = import_code,
                            runtime = runtime_functions, dict_runtime = dict_runtime
        );
    }
}

struct MoveAsset {
    pub declaration: AssetDeclaration,
    pub environment: Environment,
}

impl MoveAsset {
    fn generate(&self) -> String {
        let function_context = FunctionContext {
            environment: self.environment.clone(),
            ScopeContext: Default::default(),
            enclosing_type: self.declaration.identifier.token.clone(),
            block_stack: vec![MoveIRBlock { statements: vec![] }],
            in_struct_function: false,
            is_constructor: false,
        };

        let members: Vec<MoveIRExpression> = self
            .declaration
            .members
            .clone()
            .into_iter()
            .filter_map(|s| match s {
                AssetMember::VariableDeclaration(v) => {
                    Some(MoveFieldDeclaration { declaration: v }.generate(&function_context))
                }
                (_) => None,
            })
            .collect();
        let members: Vec<String> = members.into_iter().map(|e| format!("{}", e)).collect();
        let members = members.join(",\n");
        let result = format!(
            "resource {name} {{ \n {members} \n }}",
            name = self.declaration.identifier.token,
            members = members
        );
        return result;
    }

    pub fn generate_all_functions(&self) -> String {
        let init = format!("");
        format!(
            "{initialisers} \n\n {functions}",
            initialisers = self.generate_initialisers(),
            functions = self.generate_functions()
        )
    }

    pub fn generate_initialisers(&self) -> String {
        let initialisers: Vec<SpecialDeclaration> = self
            .declaration
            .members
            .clone()
            .into_iter()
            .filter_map(|m| {
                if let AssetMember::SpecialDeclaration(s) = m {
                    if s.is_init() {
                        return Some(s);
                    }
                }
                return None;
            })
            .collect();
        let initialisers: Vec<String> = initialisers
            .into_iter()
            .map(|i| {
                MoveStructInitialiser {
                    declaration: i.clone(),
                    identifier: self.declaration.identifier.clone(),
                    environment: self.environment.clone(),
                    properties: self.declaration.get_variable_declarations(),
                }
                .generate()
            })
            .collect();
        let initialisers = initialisers.join("\n\n");
        return initialisers;
    }

    pub fn generate_functions(&self) -> String {
        let functions: Vec<FunctionDeclaration> = self
            .declaration
            .members
            .clone()
            .into_iter()
            .filter_map(|m| {
                if let AssetMember::FunctionDeclaration(f) = m {
                    return Some(f);
                }
                return None;
            })
            .collect();
        let functions: Vec<String> = functions
            .into_iter()
            .map(|f| {
                MoveFunction {
                    function_declaration: f.clone(),
                    environment: self.environment.clone(),
                    IsContractFunction: false,
                    enclosing_type: self.declaration.identifier.clone(),
                }
                .generate(true)
            })
            .collect();
        let functions = functions.join("\n\n");
        return functions;
    }
}

struct MoveStruct {
    pub struct_declaration: StructDeclaration,
    pub environment: Environment,
}

impl MoveStruct {
    fn generate(&self) -> String {
        let function_context = FunctionContext {
            environment: self.environment.clone(),
            ScopeContext: Default::default(),
            enclosing_type: self.struct_declaration.identifier.token.clone(),
            block_stack: vec![],
            in_struct_function: true,
            is_constructor: false,
        };

        let members: Vec<MoveIRExpression> = self
            .struct_declaration
            .members
            .clone()
            .into_iter()
            .filter_map(|s| match s {
                StructMember::VariableDeclaration(v) => {
                    Some(MoveFieldDeclaration { declaration: v }.generate(&function_context))
                }
                (_) => None,
            })
            .collect();
        let members: Vec<String> = members.into_iter().map(|e| format!("{}", e)).collect();
        let members = members.join(",\n");
        let kind = MoveType::move_type(
            Type::UserDefinedType(self.struct_declaration.identifier.clone()),
            Option::from(self.environment.clone()),
        );
        let kind = if kind.is_resource() {
            format!("resource")
        } else {
            format!("struct")
        };
        let result = format!(
            "{kind} {name} {{ \n {members} \n }}",
            kind = kind,
            name = self.struct_declaration.identifier.token,
            members = members
        );
        return result;
    }

    pub fn generate_all_functions(&self) -> String {
        format!(
            "{initialisers} \n\n {functions}",
            initialisers = self.generate_initialisers(),
            functions = self.generate_functions()
        )
    }
    pub fn generate_initialisers(&self) -> String {
        let initialisers: Vec<SpecialDeclaration> = self
            .struct_declaration
            .members
            .clone()
            .into_iter()
            .filter_map(|m| {
                if let StructMember::SpecialDeclaration(s) = m {
                    if s.is_init() {
                        return Some(s);
                    }
                }
                return None;
            })
            .collect();
        let initialisers: Vec<String> = initialisers
            .into_iter()
            .map(|i| {
                MoveStructInitialiser {
                    declaration: i.clone(),
                    identifier: self.struct_declaration.identifier.clone(),
                    environment: self.environment.clone(),
                    properties: self.struct_declaration.get_variable_declarations(),
                }
                .generate()
            })
            .collect();
        let initialisers = initialisers.join("\n\n");
        return initialisers;
    }

    pub fn generate_functions(&self) -> String {
        let functions: Vec<FunctionDeclaration> = self
            .struct_declaration
            .members
            .clone()
            .into_iter()
            .filter_map(|m| {
                if let StructMember::FunctionDeclaration(f) = m {
                    return Some(f);
                }
                return None;
            })
            .collect();
        let functions: Vec<String> = functions
            .into_iter()
            .map(|f| {
                MoveFunction {
                    function_declaration: f.clone(),
                    environment: self.environment.clone(),
                    IsContractFunction: false,
                    enclosing_type: self.struct_declaration.identifier.clone(),
                }
                .generate(true)
            })
            .collect();
        let functions = functions.join("\n\n");
        return functions;
    }
}

pub struct MoveStatement {
    pub statement: Statement,
}

impl MoveStatement {
    fn generate(&self, function_context: &mut FunctionContext) -> MoveIRStatement {
        match self.statement.clone() {
            Statement::ReturnStatement(r) => {
                MoveReturnStatement { statement: r }.generate(function_context)
            }
            Statement::Expression(e) => MoveIRStatement::Expression(
                MoveExpression {
                    expression: e,
                    position: Default::default(),
                }
                .generate(function_context),
            ),
            Statement::BecomeStatement(b) => {
                MoveBecomeStatement { statement: b }.generate(function_context)
            }
            Statement::EmitStatement(e) => {
                MoveEmitStatement { statement: e }.generate(function_context)
            }
            Statement::ForStatement(f) => {
                MoveForStatement { statement: f }.generate(function_context)
            }
            Statement::IfStatement(i) => {
                MoveIfStatement { statement: i }.generate(function_context)
            }
            Statement::DoCatchStatement(_) => panic!("Do Catch not currently supported"),
        }
    }
}

struct MoveIfStatement {
    pub statement: IfStatement,
}

impl MoveIfStatement {
    pub fn generate(&self, function_context: &mut FunctionContext) -> MoveIRStatement {
        let condition = MoveExpression {
            expression: self.statement.condition.clone(),
            position: Default::default(),
        }
        .generate(function_context);
        println!("With new block");
        let count = function_context.push_block();
        for statement in self.statement.body.clone() {
            let statement = MoveStatement { statement }.generate(function_context);
            function_context.emit(statement);
        }
        let body = function_context.with_new_block(count);
        MoveIRStatement::If(MoveIRIf {
            expression: condition,
            block: body,
            else_block: None,
        })
    }
}

struct MoveReturnStatement {
    pub statement: ReturnStatement,
}

impl MoveReturnStatement {
    pub fn generate(&self, function_context: &mut FunctionContext) -> MoveIRStatement {

        if self.statement.expression.is_none() {
            function_context.emit_release_references();
            return MoveIRStatement::Inline(String::from("return"));
        }

        let return_identifier = Identifier {
            token: "ret".to_string(),
            enclosing_type: None,
            line_info: self.statement.line_info.clone(),
        };
        let expression = self.statement.expression.clone().unwrap();
        let expression = MoveExpression {
            expression,
            position: Default::default(),
        }
        .generate(&function_context);
        let assignment = MoveIRExpression::Assignment(MoveIRAssignment {
            identifier: return_identifier.token.clone(),
            expresion: Box::from(expression),
        });
        function_context.emit(MoveIRStatement::Expression(assignment));

        for statement in self.statement.cleanup.clone() {
            let move_statement = MoveStatement { statement }.generate(function_context);
            function_context.emit(move_statement);
        }

        function_context.emit_release_references();
        let string = format!(
            "return move({identifier})",
            identifier = return_identifier.token
        );
        return MoveIRStatement::Inline(string);
    }
}

struct MoveBecomeStatement {
    pub statement: BecomeStatement,
}

impl MoveBecomeStatement {
    pub fn generate(&self, function_context: &mut FunctionContext) -> MoveIRStatement {
        panic!("Become Statements not currently supported")
    }
}

struct MoveForStatement {
    pub statement: ForStatement,
}

impl MoveForStatement {
    pub fn generate(&self, function_context: &mut FunctionContext) -> MoveIRStatement {
        unimplemented!()
    }
}

struct MoveEmitStatement {
    pub statement: EmitStatement,
}

impl MoveEmitStatement {
    pub fn generate(&self, function_context: &mut FunctionContext) -> MoveIRStatement {
        MoveIRStatement::Inline(format!(
            "{}",
            MoveFunctionCall {
                function_call: self.statement.function_call.clone(),
                module_name: "Self".to_string()
            }
            .generate(function_context)
        ))
    }
}

struct MoveStructInitialiser {
    pub declaration: SpecialDeclaration,
    pub identifier: Identifier,
    pub environment: Environment,
    pub properties: Vec<VariableDeclaration>,
}

impl MoveStructInitialiser {
    pub fn generate(&self) -> String {
        let modifiers: Vec<String> = self
            .declaration
            .head
            .modifiers
            .clone()
            .into_iter()
            .filter(|s| s.eq("public"))
            .collect();
        let modifiers = modifiers.join(",");

        let scope = ScopeContext {
            parameters: self.declaration.head.parameters.clone(),
            local_variables: vec![],
            counter: 0,
        };

        let function_context = FunctionContext {
            environment: self.environment.clone(),
            ScopeContext: scope,
            enclosing_type: self.identifier.token.clone(),
            block_stack: vec![MoveIRBlock { statements: vec![] }],
            in_struct_function: true,
            is_constructor: false,
        };

        let parameter_move_types: Vec<MoveType> = self
            .declaration
            .head
            .parameters
            .clone()
            .into_iter()
            .map(|p| MoveType::move_type(p.type_assignment, Option::from(self.environment.clone())))
            .collect();

        let parameter_name: Vec<MoveIRExpression> = self
            .declaration
            .head
            .parameters
            .clone()
            .into_iter()
            .map(|p| {
                MoveIdentifier {
                    identifier: p.identifier,
                    position: MovePosition::Left,
                }
                .generate(&function_context, false, false)
            })
            .collect();

        let parameter_name: Vec<String> = parameter_name
            .into_iter()
            .map(|p| format!("{}", p))
            .collect();

        let parameters: Vec<String> = parameter_name
            .into_iter()
            .zip(parameter_move_types.into_iter())
            .map(|(p, t)| {
                format!(
                    "{parameter}: {ir_type}",
                    parameter = p,
                    ir_type = t.generate(&function_context)
                )
            })
            .collect();
        let parameters = parameters.join(", ");


        let result_type = Type::from_identifier(self.identifier.clone());
        let result_type = MoveType::move_type(result_type, Option::from(self.environment.clone()));
        let result_type = result_type.generate(&function_context);

        let mut function_context = FunctionContext {
            environment: self.environment.clone(),
            ScopeContext: self.declaration.ScopeContext.clone(),
            enclosing_type: self.identifier.token.clone(),
            block_stack: vec![MoveIRBlock { statements: vec![] }],
            in_struct_function: true,
            is_constructor: true,
        };

        let body = if self.declaration.body.is_empty() {
            "".to_string()
        } else {
            let mut properties = self.properties.clone();
            for property in &self.properties {
                let property = properties.remove(0);
                let property_type = MoveType::move_type(
                    property.variable_type,
                    Option::from(self.environment.clone()),
                )
                .generate(&function_context);
                let name = format!("__this_{}", property.identifier.token);
                function_context.emit(MoveIRStatement::Expression(
                    MoveIRExpression::VariableDeclaration(MoveIRVariableDeclaration {
                        identifier: name,
                        declaration_type: property_type,
                    }),
                ));
            }

            let mut unassigned: Vec<Identifier> = self
                .properties
                .clone()
                .into_iter()
                .map(|v| v.identifier)
                .collect();
            let mut statements = self.declaration.body.clone();
            while !(statements.is_empty() || unassigned.is_empty()) {
                let statement = statements.remove(0);
                if let Statement::Expression(e) = statement.clone() {
                    if let Expression::BinaryExpression(b) = e {
                        if let BinOp::Equal = b.op {
                            match *b.lhs_expression {
                                Expression::Identifier(i) => {
                                    if i.enclosing_type.is_some() {
                                        let enclosing = i.enclosing_type.clone();
                                        let enclosing = enclosing.unwrap();
                                        if enclosing == self.identifier.token.clone() {
                                            unassigned = unassigned
                                                .into_iter()
                                                .filter(|u| u.token != i.token)
                                                .collect();
                                        }
                                    }

                                }
                                Expression::BinaryExpression(be) => {
                                    let op = be.op.clone();
                                    let lhs = *be.lhs_expression;
                                    let rhs = *be.rhs_expression;
                                    if let BinOp::Dot = op {
                                        if let Expression::SelfExpression = lhs {
                                            if let Expression::Identifier(i) = rhs {
                                                unassigned = unassigned
                                                    .into_iter()
                                                    .filter(|u| u.token != i.token)
                                                    .collect();
                                            }
                                        }
                                    }
                                }
                                _ => break,
                            }
                        }
                    }
                }

                let statement = MoveStatement { statement }.generate(&mut function_context);
                function_context.emit(statement);
            }

            let fields = self.properties.clone();
            let fields = fields
                .into_iter()
                .map(|f| {
                    (
                        f.identifier.token.clone(),
                        MoveIRExpression::Transfer(MoveIRTransfer::Move(Box::from(
                            MoveIRExpression::Identifier(format!(
                                "__this_{}",
                                f.identifier.token.clone()
                            )),
                        ))),
                    )
                })
                .collect();

            let constructor = MoveIRExpression::StructConstructor(MoveIRStructConstructor {
                identifier: self.identifier.clone(),
                fields: fields,
            });

            if statements.is_empty() {
                function_context.emit_release_references();
                function_context.emit(MoveIRStatement::Return(constructor));
                function_context.generate()
            } else {
                function_context.is_constructor = false;

                function_context.emit_release_references();

                let shadowSelfName = "Quartz$self";
                let selfType = MoveType::move_type(
                    Type::type_from_identifier(self.identifier.clone()),
                    Option::from(self.environment.clone()),
                )
                .generate(&function_context);

                let emit = MoveIRExpression::VariableDeclaration(MoveIRVariableDeclaration {
                    identifier: "this".to_string(),
                    declaration_type: MoveIRType::MutableReference(Box::from(selfType.clone())),
                });
                function_context.emit(MoveIRStatement::Expression(emit));

                let emit = MoveIRExpression::VariableDeclaration(MoveIRVariableDeclaration {
                    identifier: "".to_string(),
                    declaration_type: selfType,
                });
                function_context.emit(MoveIRStatement::Expression(emit));

                function_context.generate()
            }

        };


        format!(
            "{modifiers}{name}({parameters}): {result_type} {{ \n\n {body} \n\n }}",
            modifiers = modifiers,
            result_type = result_type,
            name = self.identifier.token,
            parameters = parameters,
            body = body
        )
    }
}

#[derive(Debug)]
struct MoveFunction {
    pub function_declaration: FunctionDeclaration,
    pub environment: Environment,
    pub IsContractFunction: bool,
    pub enclosing_type: Identifier,
}

impl MoveFunction {
    fn generate(&self, _return: bool) -> String {
        let scope = self.function_declaration.ScopeContext.clone();
        let scope = scope.unwrap_or(Default::default());

        let function_context = FunctionContext {
            environment: self.environment.clone(),
            ScopeContext: scope,
            enclosing_type: self.enclosing_type.token.clone(),
            block_stack: vec![MoveIRBlock { statements: vec![] }],
            in_struct_function: !self.IsContractFunction,
            is_constructor: false,
        };

        let modifiers: Vec<String> = self
            .function_declaration
            .head
            .modifiers
            .clone()
            .into_iter()
            .filter(|s| s.eq("public"))
            .collect();
        let modifiers = modifiers.join(",");
        let name = self.function_declaration.head.identifier.token.clone();
        let name = self
            .function_declaration
            .mangledIdentifier
            .as_ref()
            .unwrap_or(&name);
        let parameter_move_types: Vec<MoveType> = self
            .function_declaration
            .head
            .parameters
            .clone()
            .into_iter()
            .map(|p| MoveType::move_type(p.type_assignment, Option::from(self.environment.clone())))
            .collect();
        let parameters: Vec<MoveIRExpression> = self
            .function_declaration
            .head
            .parameters
            .clone()
            .into_iter()
            .map(|p| {
                MoveIdentifier {
                    identifier: p.identifier.clone(),
                    position: MovePosition::Left,
                }
                .generate(&function_context, false, false)
            })
            .collect();
        let parameters: Vec<String> = parameters
            .into_iter()
            .zip(parameter_move_types.into_iter())
            .map(|(p, t)| {
                format!(
                    "{parameter}: {ir_type}",
                    parameter = p,
                    ir_type = t.generate(&function_context)
                )
            })
            .collect();
        let parameters = parameters.join(", ");

        let result_type = if self.function_declaration.get_result_type().is_some() && _return {
            let result = self.function_declaration.get_result_type().clone();
            let result = result.unwrap();
            let result = MoveType::move_type(result, Option::from(self.environment.clone()));
            format!("{}", result.generate(&function_context))
        } else {
            "".to_string()
        };
        let tags = self.function_declaration.tags.clone();
        let tags = tags.join("");

        let scope = self.function_declaration.ScopeContext.clone();

        let mut scope = scope.unwrap_or(Default::default());

        let variables = self.function_declaration.body.clone();
        let variables: Vec<Expression> = variables
            .into_iter()
            .filter_map(|v| {
                if let Statement::Expression(e) = v {
                    Some(e)
                } else {
                    None
                }
            })
            .collect();

        let mut variables: Vec<VariableDeclaration> = variables
            .into_iter()
            .filter_map(|v| {
                if let Expression::VariableDeclaration(e) = v {
                    Some(e)
                } else {
                    None
                }
            })
            .collect();

        let mut all_variables = scope.local_variables.clone();
        all_variables.append(&mut variables);

        scope.local_variables = all_variables;
        let mut function_context = FunctionContext {
            environment: self.environment.clone(),
            enclosing_type: self.enclosing_type.token.clone(),
            block_stack: vec![MoveIRBlock { statements: vec![] }],
            ScopeContext: scope,
            in_struct_function: !self.IsContractFunction,
            is_constructor: false,
        };
        let statements = self.function_declaration.body.clone();
        let mut statements: Vec<MoveStatement> = statements
            .into_iter()
            .map(|s| MoveStatement { statement: s })
            .collect();
        while !statements.is_empty() {
            let statement = statements.remove(0);
            let statement = statement.generate(&mut function_context);
            function_context.emit(statement);
        }

        let body = function_context.generate();
        if result_type.is_empty() {
            let result = format!(
                " {modifiers} {name} ({parameters}) {tags} {{ \n {body} \n }}",
                modifiers = modifiers,
                name = name,
                parameters = parameters,
                tags = tags,
                body = body
            );
            return result;
        }

        let result = format!(
            " {modifiers} {name} ({parameters}): {result} {tags} {{ \n {body} \n }}",
            modifiers = modifiers,
            name = name,
            parameters = parameters,
            result = result_type,
            tags = tags,
            body = body
        );
        return result;
    }
}

#[derive(Debug, Default, Clone)]
pub struct FunctionContext {
    pub environment: Environment,
    pub ScopeContext: ScopeContext,
    pub enclosing_type: String,
    pub block_stack: Vec<MoveIRBlock>,
    pub in_struct_function: bool,
    pub is_constructor: bool,
}

impl FunctionContext {
    pub fn generate(&mut self) -> String {
        let block = self.block_stack.last();
        if !self.block_stack.is_empty() {
            let statements = block.unwrap().statements.clone();
            let statements: Vec<String> = statements
                .into_iter()
                .map(|s| format!("{s}", s = s))
                .collect();
            return statements.join("\n");
        }

        return String::from("");
    }

    pub fn emit(&mut self, statement: MoveIRStatement) {
        let count = self.block_stack.len();
        let block = self.block_stack.get_mut(count - 1);
        block.unwrap().statements.push(statement);
    }

    pub fn with_new_block(&mut self, count: usize) -> MoveIRBlock {
        while self.block_stack.len() != count {
            let block = MoveIRStatement::Block(self.pop_block());
            self.emit(block);
        }
        return self.pop_block();
    }

    pub fn push_block(&mut self) -> usize {
        self.block_stack.push(MoveIRBlock { statements: vec![] });
        self.block_stack.len()
    }

    pub fn pop_block(&mut self) -> MoveIRBlock {
        self.block_stack.pop().unwrap()
    }
    pub fn emit_release_references(&mut self) {
        let references: Vec<Identifier> = self
            .ScopeContext
            .parameters
            .clone()
            .into_iter()
            .filter(|i| i.is_inout())
            .map(|p| p.identifier)
            .collect();
        for reference in references {
            let expression = MoveIdentifier {
                identifier: reference,
                position: Default::default(),
            }
            .generate(self, true, false);
            self.emit(MoveIRStatement::Inline(format!("_ = {}", expression)))
        }
    }

    pub fn self_type(&self) -> Type {
        let result = self.ScopeContext.type_for("self".to_string());
        if result.is_some() {
            return result.unwrap();
        } else {
            return self.environment.get_expression_type(
                Expression::SelfExpression,
                &self.enclosing_type,
                vec![],
                vec![],
                self.ScopeContext.clone(),
            );
        }
    }

}

struct MoveExternalCall {
    pub external_call: ExternalCall,
}

impl MoveExternalCall {
    pub fn generate(&self, function_context: &FunctionContext) -> MoveIRExpression {
        if let Expression::FunctionCall(f) =
            *self.external_call.function_call.rhs_expression.clone()
        {
            let mut lookup = f.clone();
            if !lookup.arguments.is_empty() {
                lookup.arguments.remove(0);
            }
            let enclosing = f.identifier.enclosing_type.clone();
            let enclosing = enclosing.unwrap_or(function_context.enclosing_type.clone());

            let result = function_context.environment.match_function_call(
                lookup,
                &enclosing,
                vec![],
                function_context.ScopeContext.clone(),
            );

            if let FunctionCallMatchResult::MatchedFunction(_) = result {
            } else if let FunctionCallMatchResult::Failure(c) = result {
                let candidate = c.clone();
                let mut candidate = candidate.candidates.clone();
                if candidate.is_empty() {
                    panic!("Cannot match function signature of external call")
                } else {
                    let candidate = candidate.remove(0);

                    if let CallableInformation::FunctionInformation(_) = candidate {
                    } else {
                        panic!("Cannot match function signature of external call")
                    }
                }
            } else {
                panic!("Cannot match function signature of external call")
            }

            if self.external_call.external_trait_name.is_some() {
                let external_trait_name = self.external_call.external_trait_name.clone();
                let external_trait_name = external_trait_name.unwrap();

                let type_info = function_context.environment.types.get(&external_trait_name);

                if type_info.is_some() {
                    let type_info = type_info.clone();
                    let type_info = type_info.unwrap();

                    if type_info.is_external_module() {
                        return MoveFunctionCall {
                            function_call: f.clone(),
                            module_name: external_trait_name,
                        }
                        .generate(function_context);
                    }
                }
            }

            let mut function_call = f.clone();

            if self.external_call.external_trait_name.is_some() {
                let external_trait_name = self.external_call.external_trait_name.clone();
                let external_trait_name = external_trait_name.unwrap();
                let ident = function_call.mangled_identifier.clone();
                let ident = ident.unwrap_or(function_call.identifier.clone());
                let ident = ident.token;
                function_call.mangled_identifier = Option::from(Identifier {
                    token: format!("{ext}_{i}", ext = external_trait_name, i = ident),
                    enclosing_type: None,
                    line_info: Default::default(),
                });
            }

            return MoveFunctionCall {
                function_call,
                module_name: format!("Self"),
            }
            .generate(function_context);

        } else {
            panic!("Cannot match external call with function")
        }
        unimplemented!()
    }
}

struct MoveFunctionCall {
    pub function_call: FunctionCall,
    pub module_name: String,
}

impl MoveFunctionCall {
    pub fn generate(&self, function_context: &FunctionContext) -> MoveIRExpression {

        let mut look_up = self.function_call.clone();
        if !self.function_call.arguments.is_empty() {
            let mut args = self.function_call.arguments.clone();
            let arg1 = args.remove(0);
            let expression = arg1.expression;
            if let Expression::SelfExpression = expression {
                look_up.arguments = args;
            }
        }

        let mut module = self.module_name.clone();
        let mut call = if self.function_call.mangled_identifier.is_some() {
            let mangled = self.function_call.mangled_identifier.clone();
            let mangled = mangled.unwrap();

            mangled.token
        } else {
            self.function_call.identifier.token.clone()
        };

        if function_context
            .environment
            .is_trait_declared(&self.function_call.identifier.token)
        {
            let type_info = function_context
                .environment
                .types
                .get(&self.function_call.identifier.token)
                .clone();
            if type_info.is_some() {
                let type_info = type_info.unwrap();
                if type_info.is_external_struct() {
                    if type_info.is_external_module() {
                        module = look_up.identifier.token.clone();
                        call = format!("new");
                    }
                } else {
                    let external_address = look_up.arguments.remove(0).expression;
                    return MoveExpression {
                        expression: external_address,
                        position: Default::default(),
                    }
                    .generate(function_context);
                }
            }
        }

        let arguments: Vec<MoveIRExpression> = self
            .function_call
            .arguments
            .clone()
            .into_iter()
            .map(|a| {
                if let Expression::Identifier(i) = a.expression.clone() {
                    MoveIdentifier {
                        identifier: i,
                        position: Default::default(),
                    }
                    .generate(function_context, false, true)
                } else {
                    MoveExpression {
                        expression: a.expression,
                        position: Default::default(),
                    }
                    .generate(function_context)
                }
            })
            .collect();
        let identifier = format!("{module}.{function}", module = module, function = call);
        MoveIRExpression::FunctionCall(MoveIRFunctionCall {
            identifier,
            arguments,
        })
    }
}

struct MoveExpression {
    pub expression: Expression,
    pub position: MovePosition,
}

impl MoveExpression {
    pub fn generate(&self, function_context: &FunctionContext) -> MoveIRExpression {
        return match self.expression.clone() {
            Expression::Identifier(i) => MoveIdentifier {
                identifier: i,
                position: self.position.clone(),
            }
            .generate(function_context, false, false),
            Expression::BinaryExpression(b) => MoveBinaryExpression {
                expression: b,
                position: self.position.clone(),
            }
            .generate(function_context),
            Expression::InoutExpression(i) => MoveInoutExpression {
                expression: i,
                position: self.position.clone(),
            }
            .generate(function_context),
            Expression::ExternalCall(f) => {
                MoveExternalCall { external_call: f }.generate(function_context)
            }
            Expression::FunctionCall(f) => {
                MoveFunctionCall {
                    function_call: f,
                    module_name: "Self".to_string(),
                }
            }
            .generate(function_context),
            Expression::VariableDeclaration(v) => {
                MoveVariableDeclaration { declaration: v }.generate(function_context)
            }
            Expression::BracketedExpression(b) => MoveExpression {
                expression: *b.expression,
                position: Default::default(),
            }
            .generate(function_context),
            Expression::AttemptExpression(a) => {
                MoveAttemptExpression { expression: a }.generate(function_context)
            }
            Expression::Literal(l) => {
                MoveIRExpression::Literal(MoveLiteralToken { token: l }.generate())
            }
            Expression::ArrayLiteral(a) => {
                let elements = a.elements.clone();
                let elements = elements
                    .into_iter()
                    .map(|e| {
                        MoveExpression {
                            expression: e,
                            position: Default::default(),
                        }
                        .generate(function_context)
                    })
                    .collect();
                MoveIRExpression::Vector(MoveIRVector {
                    elements,
                    vec_type: None,
                })
            }
            Expression::DictionaryLiteral(_) => unimplemented!(),
            Expression::SelfExpression => MoveSelf {
                token: "self".to_string(),
                position: self.position.clone(),
            }
            .generate(function_context, false),
            Expression::SubscriptExpression(s) => MoveSubscriptExpression {
                expression: s,
                position: self.position.clone(),
                rhs: None,
            }
            .generate(function_context),
            Expression::RangeExpression(_) => unimplemented!(),
            Expression::RawAssembly(s, _) => MoveIRExpression::Inline(s),
            Expression::CastExpression(c) => {
                MoveCastExpression { expression: c }.generate(function_context)
            }
            Expression::Sequence(_) => unimplemented!()
        };
    }
}

struct MoveCastExpression {
    pub expression: CastExpression,
}

impl MoveCastExpression {
    pub fn generate(&self, function_context: &FunctionContext) -> MoveIRExpression {
        let enclosing = self.expression.expression.enclosing_type().clone();
        let enclosing = enclosing.unwrap_or(function_context.enclosing_type.clone());
        let scope = function_context.ScopeContext.clone();
        let original_type = function_context.environment.get_expression_type(
            *self.expression.expression.clone(),
            &enclosing,
            vec![],
            vec![],
            scope,
        );
        let target_type = self.expression.cast_type.clone();

        let original_type_information = MoveCastExpression::get_type_info(original_type);
        let target_type_information = MoveCastExpression::get_type_info(target_type);

        let expression_code = MoveExpression {
            expression: *self.expression.expression.clone(),
            position: Default::default(),
        }
        .generate(function_context);

        if original_type_information.0 <= target_type_information.0 {
            return expression_code;
        }

        let target = MoveCastExpression::maximum_value(target_type_information.0);

        return MoveRuntimeFunction::revert_if_greater(
            expression_code,
            MoveIRExpression::Inline(target),
        );
    }

    pub fn get_type_info(input: Type) -> (u64, bool) {
        match input {
            Type::Bool => (256, false),
            Type::Int => (256, true),
            Type::String => (256, false),
            Type::Address => (256, false),
            _ => (256, false),
        }
    }

    pub fn maximum_value(input: u64) -> String {
        match input {
            8 => format!("255"),
            16 => format!("65535"),
            24 => format!("16777215"),
            32 => format!("4294967295"),
            40 => format!("1099511627775"),
            48 => format!("281474976710655"),
            56 => format!("72057594037927935"),
            64 => format!("18446744073709551615"),
            _ => unimplemented!(),
        }
    }
}

struct MoveSubscriptExpression {
    pub expression: SubscriptExpression,
    pub position: MovePosition,
    pub rhs: Option<MoveIRExpression>,
}

impl MoveSubscriptExpression {
    pub fn generate(&self, function_context: &FunctionContext) -> MoveIRExpression {
        let rhs = self.rhs.clone();
        let rhs = rhs.unwrap_or(MoveIRExpression::Literal(MoveIRLiteral::Num(0)));


        let index = self.expression.clone();
        let index = index.index_expression.clone();
        let index = *index.clone();
        let index = MoveExpression {
            expression: index,
            position: Default::default(),
        }
        .generate(function_context);

        let identifier = self.expression.base_expression.clone();

        let identifier_code = MoveIdentifier {
            identifier,
            position: self.position.clone(),
        }
        .generate(function_context, false, false);
        let base_type = function_context.environment.get_expression_type(
            Expression::Identifier(self.expression.base_expression.clone()),
            &function_context.enclosing_type.clone(),
            vec![],
            vec![],
            function_context.ScopeContext.clone(),
        );


        let inner_type = match base_type.clone() {
            Type::ArrayType(a) => *a.key_type,
            Type::DictionaryType(d) => *d.key_type,
            _ => unimplemented!(),
        };

        let move_type = MoveType::move_type(
            inner_type,
            Option::from(function_context.environment.clone()),
        );
        let move_type = move_type.generate(function_context);

        if let MovePosition::Left = self.position.clone() {
            match base_type {
                Type::ArrayType(a) => {
                    return MoveRuntimeFunction::append_to_array_int(identifier_code, rhs);
                }
                Type::FixedSizedArrayType(a) => panic!("Fixed Size Arrays not currently supported"),
                Type::DictionaryType(p) => {
                    let f_name = format!(
                        "Self._insert_{}",
                        mangle_dictionary(self.expression.base_expression.token.clone())
                    );
                    return MoveIRExpression::FunctionCall(MoveIRFunctionCall {
                        identifier: f_name,
                        arguments: vec![index.clone(), rhs],
                    });
                }
                _ => panic!("Invalid Type for Subscript Expression"),
            }
        }

        match base_type.clone() {
            Type::ArrayType(a) => {
                let identifier = self.expression.base_expression.clone();

                let identifier_code = MoveIdentifier {
                    identifier,
                    position: self.position.clone(),
                }
                .generate(function_context, false, true);
                return MoveRuntimeFunction::get_from_array_int(identifier_code, index);
            }
            Type::FixedSizedArrayType(a) => panic!("Fixed Size Arrays not currently supported"),
            Type::DictionaryType(p) => {
                let f_name = format!(
                    "Self._get_{}",
                    mangle_dictionary(self.expression.base_expression.token.clone())
                );
                return MoveIRExpression::FunctionCall(MoveIRFunctionCall {
                    identifier: f_name,
                    arguments: vec![rhs],
                });
            }
            _ => panic!("Invalid Type for Subscript Expression"),
        }

    }
}

#[derive(Debug)]
struct MoveSelf {
    pub token: String,
    pub position: MovePosition,
}

impl MoveSelf {
    pub fn generate(&self, function_context: &FunctionContext, force: bool) -> MoveIRExpression {
        if function_context.is_constructor {
        }
        if let MovePosition::Left = self.position {
            MoveIRExpression::Identifier(self.name())
        } else if force {
            MoveIRExpression::Transfer(MoveIRTransfer::Move(Box::from(
                MoveIRExpression::Identifier(self.name()),
            )))
        } else if !function_context.self_type().is_inout_type() {
            MoveIRExpression::Identifier(self.name())
        }
        else if let MovePosition::Accessed = self.position {
            MoveIRExpression::Operation(MoveIROperation::Dereference(Box::from(
                MoveIRExpression::Operation(MoveIROperation::MutableReference(Box::from(
                    MoveIRExpression::Transfer(MoveIRTransfer::Copy(Box::from(
                        MoveIRExpression::Identifier(self.name()),
                    ))),
                ))),
            )))
        } else {
            MoveIRExpression::Transfer(MoveIRTransfer::Copy(Box::from(
                MoveIRExpression::Identifier(self.name()),
            )))
        }

    }

    pub fn name(&self) -> String {
        "this".to_string()
    }
}

struct MoveAttemptExpression {
    pub expression: AttemptExpression,
}

impl MoveAttemptExpression {
    pub fn generate(&self, function_context: &FunctionContext) -> MoveIRExpression {
        let function_call = self.expression.function_call.clone();
        let identifier =
            "QuartzWrapper".to_owned() + &self.expression.function_call.identifier.token.clone();
        let arguments: Vec<MoveIRExpression> = self
            .expression
            .function_call
            .arguments
            .clone()
            .into_iter()
            .map(|a| {
                MoveExpression {
                    expression: a.expression.clone(),
                    position: Default::default(),
                }
                .generate(function_context)
            })
            .collect();
        return MoveIRExpression::FunctionCall(MoveIRFunctionCall {
            identifier,
            arguments,
        });
    }
}

struct MoveInoutExpression {
    pub expression: InoutExpression,
    pub position: MovePosition,
}

impl MoveInoutExpression {
    pub fn generate(&self, function_context: &FunctionContext) -> MoveIRExpression {
        let expression_type = function_context.environment.get_expression_type(
            *self.expression.expression.clone(),
            &function_context.enclosing_type,
            vec![],
            vec![],
            function_context.ScopeContext.clone(),
        );

        if let Type::InoutType(i) = expression_type {
            return MoveExpression {
                expression: *self.expression.expression.clone(),
                position: self.position.clone(),
            }
            .generate(function_context);
        }

        if let MovePosition::Accessed = self.position {
        } else {
            if let Expression::Identifier(i) = *self.expression.expression.clone() {
                if i.enclosing_type.is_none() {
                    return MoveIRExpression::Operation(MoveIROperation::MutableReference(
                        Box::from(
                            MoveExpression {
                                expression: *self.expression.expression.clone(),
                                position: MovePosition::Left,
                            }
                            .generate(function_context),
                        ),
                    ));
                }
            }
        }

        if let Expression::SelfExpression = *self.expression.expression.clone() {
            return MoveExpression {
                expression: *self.expression.expression.clone(),
                position: self.position.clone(),
            }
            .generate(function_context);
        }

        let expression = self.expression.clone();
        return MoveIRExpression::Operation(MoveIROperation::MutableReference(Box::from(
            MoveExpression {
                expression: *expression.expression,
                position: MovePosition::Inout,
            }
            .generate(function_context),
        )));
    }
}

struct MoveLiteralToken {
    pub token: Literal,
}

impl MoveLiteralToken {
    pub fn generate(&self) -> MoveIRLiteral {
        return match self.token.clone() {
            Literal::BooleanLiteral(b) => MoveIRLiteral::Bool(b),
            Literal::AddressLiteral(a) => MoveIRLiteral::Hex(a),
            Literal::StringLiteral(s) => MoveIRLiteral::String(s),
            Literal::IntLiteral(i) => MoveIRLiteral::Num(i),
            Literal::FloatLiteral(i) => panic!("Floats not currently supported"),
        };
    }
}

struct MoveIdentifier {
    pub identifier: Identifier,
    pub position: MovePosition,
}

impl MoveIdentifier {
    pub fn generate(
        &self,
        function_context: &FunctionContext,
        force: bool,
        f_call: bool,
    ) -> MoveIRExpression {

        if self.identifier.enclosing_type.is_some() {
            if function_context.is_constructor {
                let name = "__this_".to_owned() + &self.identifier.token.clone();
                return MoveIRExpression::Identifier(name);
            } else {
                return MovePropertyAccess {
                    left: Expression::SelfExpression,
                    right: Expression::Identifier(self.identifier.clone()),
                    position: self.position.clone(),
                }
                .generate(function_context, f_call);
            }
        };

        if self.identifier.is_self() {
            return MoveSelf {
                token: self.identifier.token.clone(),
                position: self.position.clone(),
            }
            .generate(function_context, force);
        }

        let ir_identifier = MoveIRExpression::Identifier(mangle(self.identifier.token.clone()));

        if force {
            return MoveIRExpression::Transfer(MoveIRTransfer::Move(Box::from(ir_identifier)));
        }


        let identifier_type = function_context
            .ScopeContext
            .type_for(self.identifier.token.clone());
        if identifier_type.is_some() {
            let unwrapped_type = identifier_type.unwrap();
            if unwrapped_type.is_currency_type() && f_call {

                return MoveIRExpression::Transfer(MoveIRTransfer::Move(Box::from(ir_identifier)));
            }
            if unwrapped_type.is_currency_type() {

                return ir_identifier;
            }
            if !unwrapped_type.is_inout_type() && unwrapped_type.is_user_defined_type() {
                return MoveIRExpression::Operation(MoveIROperation::MutableReference(Box::from(
                    ir_identifier,
                )));
            }
        }

        if let MovePosition::Left = self.position {
            return ir_identifier;
        }

        if f_call {
            if let MovePosition::Accessed = self.position.clone() {
                let expression =
                    MoveIRExpression::Transfer(MoveIRTransfer::Copy(Box::from(ir_identifier)));
                let expression = MoveIRExpression::Operation(MoveIROperation::MutableReference(
                    Box::from(expression),
                ));
                return expression;
            }
        }

        if let MovePosition::Accessed = self.position {
            let expression =
                MoveIRExpression::Transfer(MoveIRTransfer::Copy(Box::from(ir_identifier)));
            let expression = MoveIRExpression::Operation(MoveIROperation::MutableReference(
                Box::from(expression),
            ));

            return MoveIRExpression::Operation(MoveIROperation::Dereference(Box::from(
                expression,
            )));
        } else {
            return MoveIRExpression::Transfer(MoveIRTransfer::Copy(Box::from(ir_identifier)));
        }
    }
}

struct MoveBinaryExpression {
    pub expression: BinaryExpression,
    pub position: MovePosition,
}

impl MoveBinaryExpression {
    pub fn generate(&self, function_context: &FunctionContext) -> MoveIRExpression {
        if let BinOp::Dot = self.expression.op {
            if let Expression::FunctionCall(f) = *self.expression.rhs_expression.clone() {
                return MoveFunctionCall {
                    function_call: f,
                    module_name: "Self".to_string(),
                }
                .generate(function_context);
            }
            return MovePropertyAccess {
                left: *self.expression.lhs_expression.clone(),
                right: *self.expression.rhs_expression.clone(),
                position: self.position.clone(),
            }
            .generate(function_context, false);
        }

        if let BinOp::Equal = self.expression.op {
            return MoveAssignment {
                lhs: *self.expression.lhs_expression.clone(),
                rhs: *self.expression.rhs_expression.clone(),
            }
            .generate(function_context);
        }

        let lhs = MoveExpression {
            expression: *self.expression.lhs_expression.clone(),
            position: self.position.clone(),
        }
        .generate(function_context);
        let rhs = MoveExpression {
            expression: *self.expression.rhs_expression.clone(),
            position: self.position.clone(),
        }
        .generate(function_context);

        return match self.expression.op.clone() {
            BinOp::Plus => {
                MoveIRExpression::Operation(MoveIROperation::Add(Box::from(lhs), Box::from(rhs)))
            }
            BinOp::Implies => panic!("operator not supported"),
            BinOp::GreaterThan => MoveIRExpression::Operation(MoveIROperation::GreaterThan(
                Box::from(lhs),
                Box::from(rhs),
            )),

            BinOp::OverflowingPlus => {
                MoveIRExpression::Operation(MoveIROperation::Add(Box::from(lhs), Box::from(rhs)))
            },
            BinOp::Minus => {
                MoveIRExpression::Operation(MoveIROperation::Minus(Box::from(lhs), Box::from(rhs)))
            },
            BinOp::OverflowingMinus => MoveIRExpression::Operation(MoveIROperation::Minus(Box::from(lhs), Box::from(rhs))),
            BinOp::Times => {
                MoveIRExpression::Operation(MoveIROperation::Times(Box::from(lhs), Box::from(rhs)))
            },
            BinOp::OverflowingTimes => MoveIRExpression::Operation(MoveIROperation::Times(Box::from(lhs), Box::from(rhs))),
            BinOp::Power => {
                MoveIRExpression::Operation(MoveIROperation::Power(Box::from(lhs), Box::from(rhs)))
            },
            BinOp::Divide => {
                MoveIRExpression::Operation(MoveIROperation::Divide(Box::from(lhs), Box::from(rhs)))
            },
            BinOp::Percent => {
                MoveIRExpression::Operation(MoveIROperation::Modulo(Box::from(lhs), Box::from(rhs)))
            },
            BinOp::Dot => panic!("operator not supported"),
            BinOp::Equal => {
                MoveIRExpression::Operation(MoveIROperation::Equal(Box::from(lhs), Box::from(rhs)))
            }
            BinOp::PlusEqual => panic!("operator not supported"),
            BinOp::MinusEqual => panic!("operator not supported"),
            BinOp::TimesEqual => panic!("operator not supported"),
            BinOp::DivideEqual => panic!("operator not supported"),
            BinOp::DoubleEqual => {
                MoveIRExpression::Operation(MoveIROperation::Equal(Box::from(lhs), Box::from(rhs)))
            }
            BinOp::NotEqual => MoveIRExpression::Operation(MoveIROperation::NotEqual(
                Box::from(lhs),
                Box::from(rhs),
            )),
            BinOp::LessThan => MoveIRExpression::Operation(MoveIROperation::LessThan(
                Box::from(lhs),
                Box::from(rhs),
            )),
            BinOp::LessThanOrEqual => MoveIRExpression::Operation(MoveIROperation::LessThanEqual(
                Box::from(lhs),
                Box::from(rhs),
            )),
            BinOp::GreaterThanOrEqual => MoveIRExpression::Operation(
                MoveIROperation::GreaterThanEqual(Box::from(lhs), Box::from(rhs)),
            ),
            BinOp::Or => {
                MoveIRExpression::Operation(MoveIROperation::Or(Box::from(lhs), Box::from(rhs)))
            }
            BinOp::And => {
                MoveIRExpression::Operation(MoveIROperation::And(Box::from(lhs), Box::from(rhs)))
            }
        };
    }
}

#[derive(Debug)]
struct MovePropertyAccess {
    pub left: Expression,
    pub right: Expression,
    pub position: MovePosition,
}

impl MovePropertyAccess {
    pub fn generate(&self, function_context: &FunctionContext, f_call: bool) -> MoveIRExpression {
        if let Expression::Identifier(e) = self.left.clone() {
            if let Expression::Identifier(p) = self.right.clone() {
                if function_context.environment.is_enum_declared(&e.token) {
                    let property = function_context.environment.property(p.token, &e.token);
                    if property.is_some() {
                        return MoveExpression {
                            expression: property.unwrap().property.get_value().unwrap(),
                            position: self.position.clone(),
                        }
                        .generate(function_context);
                    }
                }
            }
        }
        let rhs_enclosing = self.right.enclosing_identifier();
        if rhs_enclosing.is_some() {
            if function_context.is_constructor {
                return MoveIdentifier {
                    identifier: rhs_enclosing.unwrap(),
                    position: self.position.clone(),
                }
                .generate(function_context, false, false);
            }
            let position = if let MovePosition::Inout = self.position {
                MovePosition::Inout
            } else {
                MovePosition::Accessed
            };
            let lhs = MoveExpression {
                expression: self.left.clone(),
                position,
            }
            .generate(function_context);
            if f_call {
                let exp = lhs.clone();
                if let MoveIRExpression::Operation(o) = exp {
                    if let MoveIROperation::Dereference(e) = o {
                        return MoveIRExpression::Operation(MoveIROperation::Access(
                            e,
                            rhs_enclosing.unwrap().token,
                        ));
                    }
                }
            }
            return MoveIRExpression::Operation(MoveIROperation::Access(
                Box::from(lhs),
                rhs_enclosing.unwrap().token,
            ));
        }
        panic!("Fatal Error")
    }
}

#[derive(Debug)]
struct MoveAssignment {
    pub lhs: Expression,
    pub rhs: Expression,
}

impl MoveAssignment {
    pub fn generate(&self, function_context: &FunctionContext) -> MoveIRExpression {

        let lhs = self.lhs.clone();
        if let Expression::Identifier(i) = &lhs {
            if i.enclosing_type.is_some() {
                let enclosing = i.enclosing_type.clone();
                let enclosing = enclosing.unwrap_or_default();
                let var_type = function_context.environment.get_expression_type(
                    lhs.clone(),
                    &enclosing,
                    vec![],
                    vec![],
                    function_context.ScopeContext.clone(),
                );
                if let Type::ArrayType(a) = var_type {
                    let lhs_ir = MoveExpression {
                        expression: self.lhs.clone(),
                        position: MovePosition::Left,
                    }
                    .generate(function_context);

                    if let Expression::ArrayLiteral(l) = self.rhs.clone() {
                        let rhs_ir = MoveExpression {
                            expression: self.rhs.clone(),
                            position: Default::default(),
                        }
                        .generate(function_context);

                        if let MoveIRExpression::Vector(v) = rhs_ir {
                            let mut vector = v.clone();
                            let vec_type = MoveType::move_type(
                                *a.key_type,
                                Option::from(function_context.environment.clone()),
                            )
                            .generate(function_context);
                            vector.vec_type = Option::from(vec_type);
                            let rhs_ir = MoveIRExpression::Vector(vector);
                            return MoveIRExpression::Assignment(MoveIRAssignment {
                                identifier: format!("{lhs}", lhs = lhs_ir),
                                expresion: Box::new(rhs_ir),
                            });
                        }
                    } else {
                        panic!("Wrong type");
                    }
                }
            }
        }

        let rhs_ir = MoveExpression {
            expression: self.rhs.clone(),
            position: Default::default(),
        }
        .generate(function_context);

        if let Expression::VariableDeclaration(v) = &lhs {
            unimplemented!()
        }

        if let Expression::Identifier(i) = &lhs {
            if i.enclosing_type.is_none() {
                return MoveIRExpression::Assignment(MoveIRAssignment {
                    identifier: mangle(i.token.clone()),
                    expresion: Box::new(rhs_ir),
                });
            }
        }

        if let Expression::SubscriptExpression(s) = lhs {
            return MoveSubscriptExpression {
                expression: s,
                position: MovePosition::Left,
                rhs: Option::from(rhs_ir),
            }
            .generate(function_context);
        }

        if let Expression::RawAssembly(s, _) = lhs {
            if s == "_" {
                if let Expression::Identifier(i) = &self.rhs {
                    return MoveIRExpression::Assignment(MoveIRAssignment {
                        identifier: "_".to_string(),
                        expresion: Box::new(
                            MoveIdentifier {
                                identifier: i.clone(),
                                position: Default::default(),
                            }
                            .generate(function_context, true, false),
                        ),
                    });
                }
            }
        }

        let lhs_ir = MoveExpression {
            expression: self.lhs.clone(),
            position: MovePosition::Left,
        }
        .generate(function_context);

        if function_context.in_struct_function {
            return MoveIRExpression::Assignment(MoveIRAssignment {
                identifier: format!("{lhs}", lhs = lhs_ir),
                expresion: Box::new(rhs_ir),
            });
        } else if self.lhs.enclosing_identifier().is_some() {
            if function_context
                .ScopeContext
                .contains_variable_declaration(self.lhs.enclosing_identifier().unwrap().token)
            {
                return MoveIRExpression::Assignment(MoveIRAssignment {
                    identifier: self.lhs.enclosing_identifier().unwrap().token,
                    expresion: Box::new(rhs_ir),
                });
            }
        }
        return MoveIRExpression::Assignment(MoveIRAssignment {
            identifier: format!("{lhs}", lhs = lhs_ir),
            expresion: Box::new(rhs_ir),
        });
    }
}

struct MoveFieldDeclaration {
    pub declaration: VariableDeclaration,
}

impl MoveFieldDeclaration {
    pub fn generate(&self, function_context: &FunctionContext) -> MoveIRExpression {
        let ir_type = MoveType::move_type(
            self.declaration.variable_type.clone(),
            Option::from(function_context.environment.clone()),
        )
        .generate(function_context);

        return MoveIRExpression::FieldDeclaration(MoveIRFieldDeclaration {
            identifier: self.declaration.identifier.token.clone(),
            declaration_type: ir_type,
            expression: None,
        });
    }
}

struct MoveVariableDeclaration {
    pub declaration: VariableDeclaration,
}

impl MoveVariableDeclaration {
    pub fn generate(&self, function_context: &FunctionContext) -> MoveIRExpression {
        let ir_type = MoveType::move_type(
            self.declaration.variable_type.clone(),
            Option::from(function_context.environment.clone()),
        )
        .generate(function_context);

        if self.declaration.identifier.is_self() {
            return MoveIRExpression::VariableDeclaration(MoveIRVariableDeclaration {
                identifier: "this".to_string(),
                declaration_type: ir_type,
            });
        }
        return MoveIRExpression::VariableDeclaration(MoveIRVariableDeclaration {
            identifier: self.declaration.identifier.token.clone(),
            declaration_type: ir_type,
        });
    }
}

struct MoveRuntimeTypes {}

impl MoveRuntimeTypes {
    pub fn get_all_declarations() -> Vec<String> {
        let libra = format!("resource Libra_Coin {{ \n coin: LibraCoin.T  \n }}");
        vec![libra]
    }

    pub fn get_all_imports() -> Vec<MoveIRStatement> {
        let libra = MoveIRStatement::Import(MoveIRModuleImport {
            name: "LibraCoin".to_string(),
            address: "0x0".to_string(),
        });
        let libra_account = MoveIRStatement::Import(MoveIRModuleImport {
            name: "LibraAccount".to_string(),
            address: "0x0".to_string(),
        });
        let vector = MoveIRStatement::Import(MoveIRModuleImport {
            name: "Vector".to_string(),
            address: "0x0".to_string(),
        });
        vec![libra, libra_account, vector]
    }
}

#[derive(Debug)]
enum MoveRuntimeFunction {
    AppendToArrayInt,
    GetFromArrayInt,
    AssignToFixedArray,
    RevertIfGreater,
    Transfer,
    WithdrawAll,
}

impl MoveRuntimeFunction {
    pub fn revert_if_greater(value: MoveIRExpression, max: MoveIRExpression) -> MoveIRExpression {
        MoveIRExpression::FunctionCall(MoveIRFunctionCall {
            identifier: MoveRuntimeFunction::RevertIfGreater.mangle_runtime(),
            arguments: vec![value, max],
        })
    }

    pub fn append_to_array_int(vec: MoveIRExpression, value: MoveIRExpression) -> MoveIRExpression {
        MoveIRExpression::FunctionCall(MoveIRFunctionCall {
            identifier: MoveRuntimeFunction::AppendToArrayInt.mangle_runtime(),
            arguments: vec![vec, value],
        })
    }

    pub fn get_from_array_int(vec: MoveIRExpression, value: MoveIRExpression) -> MoveIRExpression {
        MoveIRExpression::FunctionCall(MoveIRFunctionCall {
            identifier: MoveRuntimeFunction::GetFromArrayInt.mangle_runtime(),
            arguments: vec![vec, value],
        })
    }

    pub fn mangle_runtime(&self) -> String {
        let string = mangle(format!("{}", self));
        format!("Self.{}", string)
    }

    pub fn get_all_functions() -> Vec<String> {
        vec![
            MoveRuntimeFunction::get_revert_if_greater(),
            MoveRuntimeFunction::get_array_funcs(),
            MoveRuntimeFunction::get_libra_internal(),
        ]
    }

    pub fn get_revert_if_greater() -> String {
        format!(
            "Quartz_RevertIfGreater(a: u64, b: u64): u64 {{  \n \
             assert(copy(a) <= move(b), 1); \n \
             return move(a); \n }}"
        )
    }

    pub fn get_deposit() -> String {
        format!(
            "Quartz_send(money: &mut LibraCoin.T, addr: address) {{ \n \
             LibraAccount.deposit(move(addr), Quartz_withdrawAll(move(money))); \n \
             return; \n }}"
        )
    }

    pub fn get_array_funcs() -> String {
        "

        _GetFromArrayInt(vec: &mut vector<u64>, index: u64):u64 {
            return  *Vector.borrow<u64>(freeze(move(vec)), move(index));
        }


        _insert_array_index_u64(vec: &mut vector<u64>, index: u64, value: u64) {
    let length: u64;
    let temp: u64;
    length = Vector.length<u64>(freeze(copy(vec)));
    Vector.push_back<u64>(copy(vec), move(value));
    if (copy(length) == copy(index)) {
      Vector.swap<u64>(copy(vec), copy(index), copy(length));
      temp = Vector.pop_back<u64>(copy(vec));
      _ = move(temp);
    };
    _ = move(vec);
    return;
  }


  _insert_array_index_bool(vec: &mut vector<bool>, index: u64, value: bool) {
    let length: u64;
    let temp: bool;
    length = Vector.length<bool>(freeze(copy(vec)));
    Vector.push_back<bool>(copy(vec), move(value));
    if (copy(length) == copy(index)) {
      Vector.swap<bool>(copy(vec), copy(index), copy(length));
      temp = Vector.pop_back<bool>(copy(vec));
      _ = move(temp);
    };
    _ = move(vec);
    return;
  }"
        .to_string()
    }

    pub fn get_libra_internal() -> String {
        "Quartz_Self_Create_Libra(input: LibraCoin.T) : Self.Libra {
            return Self.Libra_produce(move(input));
        }

        public Libra_Coin_init(zero: address): Self.Libra_Coin {
        if (move(zero) != 0x0) {
          assert(false, 9001);
        }
        return Libra_Coin {
          coin: LibraCoin.zero()
        };
      }

      public Libra_Coin_getValue(this: &mut Self.Libra_Coin): u64 {
        let coin: &LibraCoin.T;
        coin = &move(this).coin;
        return LibraCoin.value(move(coin));
      }

      public Libra_Coin_withdraw(this: &mut Self.Libra_Coin, \
      amount: u64): Self.Libra_Coin {
        let coin: &mut LibraCoin.T;
        coin = &mut move(this).coin;
        return Libra_Coin {
          coin: LibraCoin.withdraw(move(coin), move(amount))
        };
      }

      public Libra_Coin_transfer(this: &mut Self.Libra_Coin, \
      other: &mut Self.Libra_Coin, amount: u64) {
        let coin: &mut LibraCoin.T;
        let other_coin: &mut LibraCoin.T;
        let temporary: LibraCoin.T;
        coin = &mut move(this).coin;
        temporary = LibraCoin.withdraw(move(coin), move(amount));
        other_coin = &mut move(other).coin;
        LibraCoin.deposit(move(other_coin), move(temporary));
        return;
      }
      public Libra_Coin_transfer_value(this: &mut Self.Libra_Coin, other: Self.Libra) {
        let coin: &mut LibraCoin.T;
        let temp: Self.Libra_Coin;
        let temporary: LibraCoin.T;
        coin = &mut move(this).coin;
        Libra {temp} = move(other);
        Libra_Coin {temporary} = move(temp);
        LibraCoin.deposit(move(coin), move(temporary));
        return;
    }

    public Libra_Coin_send(coin: &mut Self.Libra_Coin, payee: address, amount: u64) {
    let temporary: LibraCoin.T;
    let coin_ref: &mut LibraCoin.T;
    coin_ref = &mut move(coin).coin;
    temporary = LibraCoin.withdraw(move(coin_ref), move(amount));
    LibraAccount.deposit(copy(payee), move(temporary));
    return;
  }

    Libra_Coin_produce (input: LibraCoin.T): Self.Libra_Coin {
        return Libra_Coin {
            coin: move(input)
        };
    }

    Libra_produce (input: LibraCoin.T): Self.Libra {
    return Libra {
      libra: Self.Libra_Coin_produce(move(input))
    };
  }

  Libra_init (): Self.Libra {
    return Self.publicLibra();
  }

  Quartz_Libra_send (this: &mut Self.Libra, _payee: address, _amount: u64)  {
    let _temp__5: &mut Self.Libra_Coin;
    _temp__5 = &mut copy(this).libra;
    Self.Libra_Coin_send(copy(_temp__5), copy(_payee), copy(_amount));
    _ = move(_temp__5);
    _ = move(this);
    return;
  }"
        .to_string()
    }
}

impl fmt::Display for MoveRuntimeFunction {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        write!(f, "{:?}", self)
    }
}

#[derive(Debug, Clone)]
enum MoveType {
    U64,
    Address,
    Bool,
    ByteArray,
    Resource(String),
    StructType(String),
    MutableReference(Box<MoveType>),
    Vector(Box<MoveType>),
    External(String, Box<MoveType>),
}

impl MoveType {
    pub fn generate(&self, function_context: &FunctionContext) -> MoveIRType {
        match self {
            MoveType::U64 => MoveIRType::U64,
            MoveType::Address => MoveIRType::Address,
            MoveType::Bool => MoveIRType::Bool,
            MoveType::ByteArray => MoveIRType::ByteArray,
            MoveType::Resource(s) => {
                let wei = "Wei".to_string();
                let libra = "Libra".to_string();
                let comp = s.clone();

                let resource_type = Type::UserDefinedType(Identifier {
                    token: comp.clone(),
                    enclosing_type: None,
                    line_info: Default::default(),
                });
                if comp == wei || comp == libra {
                    let string = format!("Self.{}", s);
                    return MoveIRType::Resource(string);
                }
                if function_context.enclosing_type == s.to_string() {
                    let string = format!("Self.T");
                    return MoveIRType::Resource(string);
                }
                if resource_type.is_currency_type() {
                    return MoveIRType::Resource(s.to_string());
                }
                let string = format!("{}.T", s);
                MoveIRType::Resource(string)
            }
            MoveType::StructType(s) => {
                let string = s.clone();
                if string == "LibraCoin.T".to_string() {
                    return MoveIRType::StructType(format!("{}", string));
                }
                let string = format!("Self.{}", string);
                MoveIRType::StructType(string)
            }
            MoveType::MutableReference(base_type) => {
                MoveIRType::MutableReference(Box::from(base_type.generate(function_context)))
            }
            MoveType::Vector(v) => MoveIRType::Vector(Box::from(v.generate(function_context))),
            MoveType::External(module, typee) => match *typee.clone() {
                MoveType::Resource(name) => {
                    MoveIRType::Resource(format!("{module}.{name}", module = module, name = name))
                }
                MoveType::StructType(name) => {
                    MoveIRType::StructType(format!("{module}.{name}", module = module, name = name))
                }
                _ => panic!("Only External Structs and Resources are Supported"),
            },
        }
    }

    pub fn move_type(original: Type, environment: Option<Environment>) -> MoveType {
        match original.clone() {
            Type::InoutType(r) => {
                let base_type = MoveType::move_type(*r.key_type, environment);
                MoveType::MutableReference(Box::from(base_type))
            }
            Type::ArrayType(a) => {
                MoveType::Vector(Box::from(MoveType::move_type(*a.key_type, None)))
            }
            Type::FixedSizedArrayType(a) => {
                MoveType::Vector(Box::from(MoveType::move_type(*a.key_type, None)))
            }
            Type::DictionaryType(d) => MoveType::move_type(*d.value_type, None),
            Type::UserDefinedType(i) => {
                if environment.is_some() {
                    let environment_value = environment.unwrap();
                    if MoveType::is_resource_type(original.clone(), &i.token, &environment_value) {

                        return MoveType::Resource(i.token.clone());
                    } else if original.is_external_contract(environment_value.clone()) {
                        return MoveType::Address;
                    } else if original.is_external_module(environment_value.clone()) {
                        let type_info = environment_value.types.get(&i.token).clone();
                        if type_info.is_some() {
                            let type_info = type_info.unwrap();
                            let modifiers = type_info.modifiers.clone();
                            let modifiers: Vec<FunctionCall> = modifiers
                                .into_iter()
                                .filter(|m| m.identifier.token == format!("resource"))
                                .collect();
                            if modifiers.is_empty() {
                                return MoveType::External(
                                    i.token.clone(),
                                    Box::from(MoveType::StructType(format!("T"))),
                                );
                            } else {
                                return MoveType::External(
                                    i.token.clone(),
                                    Box::from(MoveType::Resource(format!("T"))),
                                );
                            }
                        }
                    }
                    if environment_value.is_enum_declared(&i.token) {
                        unimplemented!()
                    } else {
                        return MoveType::StructType(i.token.clone());
                    }
                } else {
                    MoveType::StructType(i.token)
                }
            }
            Type::Bool => MoveType::Bool,
            Type::Int => MoveType::U64,
            Type::String => MoveType::ByteArray,
            Type::Address => MoveType::Address,
            Type::QuartzType(_) => panic!("Cannot convert type to move equivalent"),
            Type::RangeType(_) => panic!("Cannot convert type to move equivalent"),
            Type::SelfType => panic!("Cannot convert type to move equivalent"),
            Type::Error => panic!("Cannot convert type error to move equivalent"),
            Type::Solidity(_) => panic!("Cannot convert Solidity Type to move equivalent"),
        }
    }

    pub fn is_resource_type(original: Type, t: &TypeIdentifier, environment: &Environment) -> bool {
        environment.is_contract_declared(t) || original.is_currency_type()
    }

    pub fn is_resource(&self) -> bool {
        match self {
            MoveType::Resource(_) => true,
            MoveType::External(_, v) => {
                let ext = v.clone();
                if let MoveType::Resource(_) = *ext {
                    return true;
                }
                false
            }
            _ => false,
        }
    }
}


#[derive(Debug, Clone)]
pub struct MoveIRBlock {
    pub statements: Vec<MoveIRStatement>,
}

impl fmt::Display for MoveIRBlock {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let statements: Vec<String> = self
            .statements
            .clone()
            .into_iter()
            .map(|s| format!("{s}", s = s))
            .collect();
        let statements = statements.join("\n");
        write!(f, "{{ \n {statements} \n }}", statements = statements)
    }
}

#[derive(Debug, Clone)]
pub struct MoveIRFunctionDefinition {
    pub identifier: MoveIRIdentifier,
    pub arguments: Vec<MoveIRIdentifier>,
    pub returns: Vec<MoveIRIdentifier>,
    pub body: MoveIRBlock,
}

impl fmt::Display for MoveIRFunctionDefinition {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let arguments: Vec<String> = self
            .arguments
            .clone()
            .into_iter()
            .map(|a| format!("{}", a))
            .collect();
        let arguments = arguments.join(", ");
        let returns: Vec<String> = self
            .returns
            .clone()
            .into_iter()
            .map(|a| format!("{}", a))
            .collect();
        let returns = returns.join(", ");
        write!(
            f,
            "{identifier}({arguments}) {returns}{body}",
            identifier = self.identifier,
            arguments = arguments,
            returns = returns,
            body = self.body
        )
    }
}

#[derive(Debug, Clone)]
pub struct MoveIRIdentifier {
    pub identifier: String,
    pub move_type: MoveIRType,
}

impl fmt::Display for MoveIRIdentifier {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(
            f,
            "{identifier}: {move_type}",
            identifier = self.identifier,
            move_type = self.move_type
        )
    }
}

#[derive(Debug, Clone)]
pub enum MoveIRExpression {
    FunctionCall(MoveIRFunctionCall),
    StructConstructor(MoveIRStructConstructor),
    Identifier(String),
    Transfer(MoveIRTransfer),
    Literal(MoveIRLiteral),
    Catchable,
    Inline(String),
    Assignment(MoveIRAssignment),
    VariableDeclaration(MoveIRVariableDeclaration),
    FieldDeclaration(MoveIRFieldDeclaration),
    Operation(MoveIROperation),
    Vector(MoveIRVector),
    Noop,
}

impl fmt::Display for MoveIRExpression {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            MoveIRExpression::FunctionCall(fc) => write!(f, "{fc}", fc = fc),
            MoveIRExpression::StructConstructor(s) => {
                let args = s.fields.clone();
                let args: Vec<String> = args
                    .into_iter()
                    .map(|(k, v)| format!("{k}: {v}", k = k, v = v))
                    .collect();
                let args = args.join(",\n");
                write!(
                    f,
                    "{name} {{ \n {args} }}",
                    name = s.identifier.token,
                    args = args
                )
            }
            MoveIRExpression::Identifier(s) => write!(f, "{s}", s = s),
            MoveIRExpression::Transfer(t) => write!(f, "{t}", t = t),
            MoveIRExpression::Literal(l) => write!(f, "{l}", l = l),
            MoveIRExpression::Catchable => unimplemented!(),
            MoveIRExpression::Inline(s) => write!(f, "{s}", s = s),
            MoveIRExpression::Assignment(a) => write!(f, "{a}", a = a),
            MoveIRExpression::VariableDeclaration(v) => write!(f, "{v}", v = v),
            MoveIRExpression::Noop => write!(f, ""),
            MoveIRExpression::FieldDeclaration(fd) => write!(f, "{fd}", fd = fd),
            MoveIRExpression::Operation(o) => write!(f, "{o}", o = o),
            MoveIRExpression::Vector(v) => write!(f, "{v}", v = v),
        }
    }
}

#[derive(Debug, Clone)]
pub struct MoveIRVector {
    pub elements: Vec<MoveIRExpression>,
    pub vec_type: Option<MoveIRType>,
}

impl fmt::Display for MoveIRVector {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        if self.vec_type.is_some() {
            let move_type = self.vec_type.clone();
            let move_type = move_type.unwrap();
            write!(f, "Vector.empty<{move_type}>()", move_type = move_type)
        } else {
            write!(f, "Vector.empty<>()")
        }
    }
}

#[derive(Debug, Clone)]
pub struct MoveIRStructConstructor {
    pub identifier: Identifier,
    pub fields: Vec<(String, MoveIRExpression)>,
}

#[derive(Debug, Clone)]
pub struct MoveIRFunctionCall {
    pub identifier: String,
    pub arguments: Vec<MoveIRExpression>,
}

impl fmt::Display for MoveIRFunctionCall {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let arguments: Vec<String> = self
            .arguments
            .clone()
            .into_iter()
            .map(|a| format!("{}", a))
            .collect();
        let arguments = arguments.join(", ");
        write!(
            f,
            "{i}({arguments})",
            i = self.identifier,
            arguments = arguments
        )
    }
}

#[derive(Debug, Clone)]
pub enum MoveIRLiteral {
    Num(u64),
    String(String),
    Bool(bool),
    Decimal(u64, u64),
    Hex(String),
}

impl fmt::Display for MoveIRLiteral {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            MoveIRLiteral::Num(i) => write!(f, "{i}", i = i),
            MoveIRLiteral::String(s) => write!(f, "\"{s}\"", s = s),
            MoveIRLiteral::Bool(b) => write!(f, "{b}", b = b),
            MoveIRLiteral::Decimal(i1, i2) => write!(f, "{i1}.{i2}", i1 = i1, i2 = i2),
            MoveIRLiteral::Hex(h) => write!(f, "{h}", h = h),
        }
    }
}

#[derive(Debug, Clone)]
pub enum MoveIRTransfer {
    Move(Box<MoveIRExpression>),
    Copy(Box<MoveIRExpression>),
}

impl fmt::Display for MoveIRTransfer {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            MoveIRTransfer::Move(e) => write!(f, "move({expression})", expression = e),
            MoveIRTransfer::Copy(e) => write!(f, "copy({expression})", expression = e),
        }
    }
}

#[derive(Debug, Clone)]
pub struct MoveIRAssignment {
    pub identifier: String,
    pub expresion: Box<MoveIRExpression>,
}

impl fmt::Display for MoveIRAssignment {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(
            f,
            "{identifier} = {expression}",
            identifier = self.identifier,
            expression = self.expresion
        )
    }
}

#[derive(Debug, Clone)]
pub struct MoveIRFieldDeclaration {
    pub identifier: String,
    pub declaration_type: MoveIRType,
    pub expression: Option<Expression>,
}

impl fmt::Display for MoveIRFieldDeclaration {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(
            f,
            "{ident}: {ident_type}",
            ident = self.identifier,
            ident_type = self.declaration_type
        )
    }
}

#[derive(Debug, Clone)]
pub struct MoveIRVariableDeclaration {
    pub identifier: String,
    pub declaration_type: MoveIRType,
}

impl fmt::Display for MoveIRVariableDeclaration {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(
            f,
            "let {ident}: {ident_type}",
            ident = self.identifier,
            ident_type = self.declaration_type
        )
    }
}

#[derive(Debug, Clone)]
pub struct MoveIRIf {
    pub expression: MoveIRExpression,
    pub block: MoveIRBlock,
    pub else_block: Option<MoveIRBlock>,
}

impl fmt::Display for MoveIRIf {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let else_block = if self.else_block.is_some() {
            let block = self.else_block.clone();
            let block = block.unwrap();
            format!("{}", block)
        } else {
            format!("{{}}")
        };
        write!(
            f,
            "if ({expression}) {block} else {else_block} ",
            expression = self.expression,
            block = self.block,
            else_block = else_block
        )
    }
}

#[derive(Debug, Clone)]
pub struct MoveIRModuleImport {
    pub name: String,
    pub address: String,
}

impl fmt::Display for MoveIRModuleImport {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(
            f,
            "import {address}.{name}",
            address = self.address,
            name = self.name
        )
    }
}

#[derive(Debug, Clone)]
pub enum MoveIRStatement {
    Block(MoveIRBlock),
    FunctionDefinition(MoveIRFunctionDefinition),
    If(MoveIRIf),
    Expression(MoveIRExpression),
    Switch,
    For,
    Break,
    Continue,
    Noop,
    Inline(String),
    Return(MoveIRExpression),
    Import(MoveIRModuleImport),
}

impl fmt::Display for MoveIRStatement {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            MoveIRStatement::Block(b) => write!(f, "{b}", b = b),
            MoveIRStatement::FunctionDefinition(fd) => write!(f, "{fd}", fd = fd),
            MoveIRStatement::If(i) => write!(f, "{i}", i = i),
            MoveIRStatement::Expression(e) => write!(f, "{e};", e = e),
            MoveIRStatement::Switch => write!(f, ""),
            MoveIRStatement::For => write!(f, ""),
            MoveIRStatement::Break => write!(f, "break"),
            MoveIRStatement::Continue => write!(f, "continue"),
            MoveIRStatement::Noop => write!(f, ""),
            MoveIRStatement::Inline(s) => write!(f, "{s};", s = s),
            MoveIRStatement::Return(e) => write!(f, "return {e};", e = e),
            MoveIRStatement::Import(m) => write!(f, "{s};", s = m),
        }
    }
}

#[derive(Debug, Clone)]
pub enum MoveIRType {
    U64,
    Address,
    Bool,
    ByteArray,
    Resource(String),
    StructType(String),
    MutableReference(Box<MoveIRType>),
    Vector(Box<MoveIRType>),
}

impl fmt::Display for MoveIRType {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            MoveIRType::U64 => write!(f, "u64"),
            MoveIRType::Address => write!(f, "address"),
            MoveIRType::Bool => write!(f, "bool"),
            MoveIRType::ByteArray => write!(f, "bytearray"),
            MoveIRType::Resource(s) => write!(f, "{}", s),
            MoveIRType::StructType(s) => write!(f, "{}", s),
            MoveIRType::MutableReference(base) => write!(f, "&mut {base}", base = base),
            MoveIRType::Vector(base) => write!(f, "vector<{base}>", base = base),
        }
    }
}

#[derive(Debug, Clone)]
pub enum MoveIROperation {
    Add(Box<MoveIRExpression>, Box<MoveIRExpression>),
    Minus(Box<MoveIRExpression>, Box<MoveIRExpression>),
    Times(Box<MoveIRExpression>, Box<MoveIRExpression>),
    Divide(Box<MoveIRExpression>, Box<MoveIRExpression>),
    Modulo(Box<MoveIRExpression>, Box<MoveIRExpression>),
    GreaterThan(Box<MoveIRExpression>, Box<MoveIRExpression>),
    GreaterThanEqual(Box<MoveIRExpression>, Box<MoveIRExpression>),
    LessThan(Box<MoveIRExpression>, Box<MoveIRExpression>),
    LessThanEqual(Box<MoveIRExpression>, Box<MoveIRExpression>),
    Equal(Box<MoveIRExpression>, Box<MoveIRExpression>),
    NotEqual(Box<MoveIRExpression>, Box<MoveIRExpression>),
    And(Box<MoveIRExpression>, Box<MoveIRExpression>),
    Or(Box<MoveIRExpression>, Box<MoveIRExpression>),
    Not(Box<MoveIRExpression>),
    Power(Box<MoveIRExpression>, Box<MoveIRExpression>),
    Access(Box<MoveIRExpression>, String),
    Dereference(Box<MoveIRExpression>),
    MutableReference(Box<MoveIRExpression>),
    Reference(Box<MoveIRExpression>),
}

impl fmt::Display for MoveIROperation {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            MoveIROperation::Add(l, r) => write!(f, "({l} + {r})", l = l, r = r),
            MoveIROperation::Minus(l, r) => write!(f, "({l} - {r})", l = l, r = r),
            MoveIROperation::Times(l, r) => write!(f, "({l} * {r})", l = l, r = r),
            MoveIROperation::GreaterThan(l, r) => write!(f, "({l} > {r})", l = l, r = r),
            MoveIROperation::LessThan(l, r) => write!(f, "({l} < {r})", l = l, r = r),
            MoveIROperation::Divide(l, r) => write!(f, "({l} / {r})", l = l, r = r),
            MoveIROperation::Modulo(l, r) => write!(f, "({l} & {r})", l = l, r = r),
            MoveIROperation::GreaterThanEqual(l, r) => write!(f, "({l} >= {r})", l = l, r = r),
            MoveIROperation::LessThanEqual(l, r) => write!(f, "({l} <= {r})", l = l, r = r),
            MoveIROperation::Equal(l, r) => write!(f, "({l} == {r})", l = l, r = r),
            MoveIROperation::NotEqual(l, r) => write!(f, "({l} != {r})", l = l, r = r),
            MoveIROperation::And(l, r) => write!(f, "({l} && {r})", l = l, r = r),
            MoveIROperation::Or(l, r) => write!(f, "({l} || {r})", l = l, r = r),
            MoveIROperation::Not(e) => write!(f, "!{expression}", expression = e),
            MoveIROperation::Power(l, r) => write!(f, "({l} ** {r})", l = l, r = r),
            MoveIROperation::Access(l, r) => write!(f, "{l}.{r}", l = l, r = r),
            MoveIROperation::Dereference(r) => write!(f, "*{r}", r = r),
            MoveIROperation::MutableReference(r) => write!(f, "&mut {r}", r = r),
            MoveIROperation::Reference(r) => write!(f, "&{r}", r = r),
        }
    }
}
