use super::context::*;
use super::environment::*;
use super::AST::*;
use hex::encode;
use sha3::{Digest, Keccak256};
use std::fmt;
use std::fs::File;
use std::io::Write;
use std::path::Path;

pub mod SolidityPreProcessor;

pub fn generate(module: Module, context: &mut Context) {
    let mut contracts: Vec<SolidityContract> = Vec::new();

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

            let contract = SolidityContract {
                declaration: c.clone(),
                behaviour_declarations: contract_behaviour_declarations,
                struct_declarations,
                environment: context.environment.clone(),
            };
            contracts.push(contract);
        }
    }

    for contract in contracts {
        let c = contract.generate();
        let interface = SolidityInterface {
            contract: contract.clone(),
            environment: context.environment.clone(),
        }
        .generate();

        let mut code = CodeGen {
            code: "".to_string(),
            indent_level: 0,
            indent_size: 2,
        };

        code.add(c);
        code.add(interface);
        print!("{}", code.code);

        let name = contract.declaration.identifier.token.clone();
        let path = &format!("output/{name}.sol", name = name);
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

#[derive(Clone)]
pub struct SolidityContract {
    pub declaration: ContractDeclaration,
    pub behaviour_declarations: Vec<ContractBehaviourDeclaration>,
    pub struct_declarations: Vec<StructDeclaration>,
    pub environment: Environment,
}

impl SolidityContract {
    fn generate(&self) -> String {
        //////////////////////// FUNCTIONS
        let mut functions: Vec<SolidityFunction> = vec![];
        for declarations in self.behaviour_declarations.clone() {
            for function in declarations.members.clone() {
                match function {
                    ContractBehaviourMember::FunctionDeclaration(f) => {
                        functions.push(SolidityFunction {
                            declaration: f.clone(),
                            identifier: self.declaration.identifier.clone(),
                            environment: self.environment.clone(),
                            caller_binding: declarations.caller_binding.clone(),
                            caller_protections: declarations.caller_protections.clone(),
                            IsContractFunction: !declarations.caller_protections.is_empty(),
                        })
                    }
                    _ => {}
                }
            }
        }

        let functions_code: Vec<String> = functions
            .clone()
            .into_iter()
            .map(|f| f.generate(true))
            .collect();

        let functions_code = functions_code.join("\n");

        let wrapper_functions: Vec<String> = functions
            .clone()
            .into_iter()
            .filter(|f| !f.has_any_caller())
            .map(|f| {
                SolidityWrapperFunction { function: f }.generate(&self.declaration.identifier.token)
            })
            .collect();

        let wrapper_functions = wrapper_functions.join("\n\n");

        let public_function: Vec<SolidityFunction> = functions
            .clone()
            .into_iter()
            .filter(|f| f.declaration.is_public())
            .collect();
        let selector = SolidityFunctionSelector {
            fallback: None,
            functions: public_function.clone(),
            enclosing: self.declaration.identifier.clone(),
            environment: self.environment.clone(),
        };
        let selector = selector.generate();

        let struct_declarations: Vec<String> = self
            .struct_declarations
            .clone()
            .into_iter()
            .map(|s| {
                SolidityStruct {
                    declaration: s.clone(),
                    environment: self.environment.clone(),
                }
                .generate()
            })
            .collect();

        let structs = struct_declarations.join("\n\n");

        let runtime = SolidityRuntimeFunction::get_all_functions();
        let runtime = runtime.join("\n\n");

        let mut contract_behaviour_declaration = None;
        let mut initialiser_declaration = None;
        for declarations in self.behaviour_declarations.clone() {
            for member in declarations.members.clone() {
                if let ContractBehaviourMember::SpecialDeclaration(s) = member {
                    if s.is_init() && s.is_public() {
                        contract_behaviour_declaration = Some(declarations.clone());
                        initialiser_declaration = Some(s.clone());
                    }
                }
            }
        }

        let initialiser_declaration = initialiser_declaration.unwrap();
        let contract_behaviour_declaration = contract_behaviour_declaration.unwrap();

        let parameter_sizes: Vec<u64> = initialiser_declaration
            .head
            .parameters
            .clone()
            .into_iter()
            .map(|p| self.environment.type_size(p.type_assignment))
            .collect();
        println!("{:?}", parameter_sizes);

        let mut offsets = parameter_sizes.clone();
        offsets.reverse();
        let mut elem_acc = 0;
        let mut list_acc = vec![];
        for offset in &offsets {
            elem_acc = elem_acc + offset * 32;
            list_acc.push(elem_acc);
        }
        offsets.reverse();
        let parameter_sizes: Vec<(u64, u64)> = offsets.into_iter().zip(parameter_sizes).collect();

        let mut scope = ScopeContext {
            parameters: vec![],
            local_variables: vec![],
            counter: 0,
        };
        let caller_binding = contract_behaviour_declaration.caller_binding.clone();

        if caller_binding.is_some() {
            let caller_binding = caller_binding.clone();
            let caller_binding = caller_binding.unwrap();

            let variable_declaration = VariableDeclaration {
                declaration_token: None,
                identifier: caller_binding,
                variable_type: Type::Address,
                expression: None,
            };
            scope.local_variables.push(variable_declaration);
        }

        scope.parameters = initialiser_declaration.head.parameters.clone();

        let mut function_context = FunctionContext {
            environment: self.environment.clone(),
            scope_context: scope,
            InStructFunction: false, //Inside Contract
            block_stack: vec![YulBlock { statements: vec![] }],
            enclosing_type: self.declaration.identifier.token.clone(),
            counter: 0,
        };

        let parameter_names: Vec<YulExpression> = initialiser_declaration
            .head
            .parameters
            .clone()
            .into_iter()
            .map(|p| {
                SolidityIdentifier {
                    identifier: p.identifier.clone(),
                    IsLValue: false,
                }
                .generate(&mut function_context)
            })
            .collect();
        let parameter_names: Vec<String> = parameter_names
            .into_iter()
            .map(|p| format!("{}", p))
            .collect();

        let parameter_binding: Vec<String> = parameter_names
            .into_iter()
            .zip(parameter_sizes)
            .map(|(k, (v1, v2))| {
                format!(
                    "codecopy(0x0), sub(codesize, {offset}), {size}) \n let {param} := mload(0)",
                    offset = v1,
                    size = v2 * 32,
                    param = k
                )
            })
            .collect();

        let parameter_binding = parameter_binding.join("\n");

        let scope = initialiser_declaration.ScopeContext.clone();

        let mut function_context = FunctionContext {
            environment: self.environment.clone(),
            enclosing_type: self.declaration.identifier.token.clone(),
            block_stack: vec![YulBlock { statements: vec![] }],
            scope_context: scope,
            InStructFunction: false,
            counter: 0,
        };

        let caller_binding = if caller_binding.is_some() {
            let binding = caller_binding.clone();
            let binding = binding.unwrap();
            let binding = mangle(binding.token);
            format!("let {binding} := caller()\n", binding = binding)
        } else {
            "".to_string()
        };

        let mut statements = initialiser_declaration.body.clone();
        while !statements.is_empty() {
            let statement = statements.remove(0);
            let yul_statement = SolidityStatement {
                statement: statement.clone(),
            }
            .generate(&mut function_context);
            function_context.emit(yul_statement);
            if let Statement::IfStatement(i) = statement {}
        }
        let body = function_context.generate();
        let body = format!("{binding} {body}", binding = caller_binding, body = body);

        let public_initialiser = format!(
            "init() \n\n function init() {{ \n {params} \n {body} \n }}",
            params = parameter_binding,
            body = body
        );

        let parameters: Vec<String> = initialiser_declaration
            .head
            .parameters
            .clone()
            .into_iter()
            .map(|p| format!(""))
            .collect();
        let parameters = parameters.join(", ");
        let contract_initialiser = format!(
            "constructor({params}) public {{ \n\n assembly {{ \n mstore(0x40, 0x60) \n\n {init} \n \
             /////////////////////////////// \n \
             //STRUCT FUNCTIONS \n  \
             /////////////////////////////// \n \
             {structs} \n\n \
             /////////////////////////////// \n \
             //RUNTIME FUNCTIONS \n  \
             /////////////////////////////// \n \
             {runtime} \n \
             }} \n }}",
            params = parameters,
            init = public_initialiser,
            structs = structs,
            runtime = runtime
        );

        return format!(
            "pragma solidity ^0.5.12; \n \
            contract {name} {{ \n\n \
                {init} \n\n \
                function () external payable {{ \n \
                    assembly {{ \n
                    mstore(0x40, 0x60) \n\n \
                    /////////////////////////////// \n \
                    //SELECTOR \n  \
                    /////////////////////////////// \n \
                    {selector} \n\n \
                    /////////////////////////////// \n \
                    //USER DEFINED FUNCTIONS \n  \
                    /////////////////////////////// \n \
                    {functions} \n\n \
                    /////////////////////////////// \n \
                    //WRAPPER FUNCTIONS \n  \
                    /////////////////////////////// \n \
                    /////////////////////////////// \n \
                    //STRUCT FUNCTIONS \n  \
                    /////////////////////////////// \n \
                    {structs} \n\n \
                    /////////////////////////////// \n \
                    //RUNTIME FUNCTIONS \n  \
                    /////////////////////////////// \n \
                    {runtime} \n \
                }} \n \
                }} \n \
             }}",
            name = self.declaration.identifier.token,
            init = contract_initialiser,
            functions = functions_code,
            structs = structs,
            runtime = runtime,
            selector = selector,
        );
    }
}

pub struct SolidityInterface {
    pub contract: SolidityContract,
    pub environment: Environment,
}

impl SolidityInterface {
    pub fn generate(&self) -> String {
        let behaviour_declarations = self.contract.behaviour_declarations.clone();
        let mut functions: Vec<FunctionDeclaration> = vec![];
        for declarations in behaviour_declarations.clone() {
            for function in declarations.members.clone() {
                match function {
                    ContractBehaviourMember::FunctionDeclaration(f) => {
                        functions.push(f);
                    }
                    _ => {}
                }
            }
        }

        let functions: Vec<Option<String>> = functions
            .into_iter()
            .map(|f| SolidityInterface::render_function(f))
            .collect();
        let functions: Vec<String> = functions.into_iter().filter_map(|s| s).collect();
        let functions = functions.join("\n");

        return format!(
            "interface _Interface{name} {{  \n {functions} \n }}",
            name = self.contract.declaration.identifier.token.clone(),
            functions = functions
        );
    }

    pub fn render_function(function_declaration: FunctionDeclaration) -> Option<String> {
        if function_declaration.is_public() {
            let params = function_declaration.head.parameters.clone();
            let params: Vec<String> = params
                .into_iter()
                .map(|p| {
                    let param_type =
                        SolidityIRType::map_to_solidity_type(p.type_assignment.clone()).generate();
                    let mangled_name = mangle(p.identifier.token.clone());
                    format!(
                        "{param_type} {mangled_name}",
                        param_type = param_type,
                        mangled_name = mangled_name
                    )
                })
                .collect();

            let params = params.join(", ");

            let mut attribute = "".to_string();
            if !function_declaration.is_mutating() {
                attribute = format!("view ");
            }

            let return_string = if function_declaration.get_result_type().is_some() {
                let result = function_declaration.get_result_type().clone();
                let result = result.unwrap();
                let result = SolidityIRType::map_to_solidity_type(result).generate();
                format!(" returns ( {result} ret)", result = result)
            } else {
                format!("")
            };
            return Option::from(format!(
                "function {name}({params}) {attribute}external{return_string};",
                name = function_declaration.head.identifier.token.clone(),
                params = params.clone(),
                attribute = attribute,
                return_string = return_string
            ));
        } else {
            return None;
        }
    }
}

pub struct SolidityStruct {
    pub declaration: StructDeclaration,
    pub environment: Environment,
}

impl SolidityStruct {
    pub fn generate(&self) -> String {
        let functions: Vec<FunctionDeclaration> = self
            .declaration
            .members
            .clone()
            .into_iter()
            .filter_map(|s| {
                if let StructMember::FunctionDeclaration(f) = s {
                    Some(f)
                } else {
                    None
                }
            })
            .collect();
        let functions: Vec<String> = functions
            .into_iter()
            .map(|f| {
                SolidityFunction {
                    declaration: f.clone(),
                    identifier: self.declaration.identifier.clone(),
                    environment: self.environment.clone(),
                    caller_binding: None,
                    caller_protections: vec![],
                    IsContractFunction: false,
                }
                .generate(true)
            })
            .collect();

        let functions = functions.join("\n\n");
        return functions;
    }
}

pub struct FunctionContext {
    pub environment: Environment,
    pub scope_context: ScopeContext,
    pub InStructFunction: bool,
    pub block_stack: Vec<YulBlock>,
    pub enclosing_type: String,
    pub counter: u64,
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

    pub fn emit(&mut self, statement: YulStatement) {
        let count = self.block_stack.len();
        let block = self.block_stack.get_mut(count - 1);
        block.unwrap().statements.push(statement);
    }

    pub fn push_block(&mut self) -> usize {
        self.block_stack.push(YulBlock { statements: vec![] });
        self.block_stack.len()
    }

    pub fn pop_block(&mut self) -> YulBlock {
        self.block_stack.pop().unwrap()
    }

    pub fn with_new_block(&mut self, count: usize) -> YulBlock {
        while self.block_stack.len() != count {
            let block = YulStatement::Block(self.pop_block());
            self.emit(block);
        }
        return self.pop_block();
    }

    pub fn fresh_variable(&mut self) -> String {
        let name = format!("$temp{}", self.counter);
        self.counter += 1;
        return name;
    }
}

pub enum SolidityIRType {
    uint256,
    address,
    bytes32,
}

impl SolidityIRType {
    pub fn map_to_solidity_type(input: Type) -> SolidityIRType {
        match input {
            Type::QuartzType(_) => panic!("Can not convert this type to Solidity Type"),
            Type::InoutType(i) => SolidityIRType::map_to_solidity_type(*i.key_type),
            Type::ArrayType(_) => panic!("Can not convert this type to Solidity Type"),
            Type::RangeType(_) => panic!("Can not convert this type to Solidity Type"),
            Type::FixedSizedArrayType(_) => panic!("Can not convert this type to Solidity Type"),
            Type::DictionaryType(_) => panic!("Can not convert this type to Solidity Type"),
            Type::UserDefinedType(_) => SolidityIRType::uint256,
            Type::Bool => SolidityIRType::uint256,
            Type::Int => SolidityIRType::uint256,
            Type::String => SolidityIRType::bytes32,
            Type::Address => SolidityIRType::address,
            Type::Error => panic!("Can not convert Error type to Solidity Type"),
            Type::SelfType => panic!("Can not convert this type to Solidity Type"),
            Type::Solidity(_) => panic!("Can not convert this type to Solidity Type"),
        }
    }

    pub fn if_maps_to_solidity_type(input: Type) -> bool {
        match input {
            Type::InoutType(i) => SolidityIRType::if_maps_to_solidity_type(*i.key_type),
            Type::UserDefinedType(_) => true,
            Type::Bool => true,
            Type::Int => true,
            Type::String => true,
            Type::Address => true,
            _ => false,
        }
    }

    pub fn generate(&self) -> String {
        match self {
            SolidityIRType::uint256 => format!("uint256"),
            SolidityIRType::address => format!("address"),
            SolidityIRType::bytes32 => format!("bytes32"),
        }
    }
}

#[derive(Clone)]
pub struct SolidityFunction {
    pub declaration: FunctionDeclaration,
    pub identifier: Identifier,
    pub environment: Environment,
    pub caller_binding: Option<Identifier>,
    pub caller_protections: Vec<CallerProtection>,
    pub IsContractFunction: bool,
}

impl SolidityFunction {
    pub fn has_any_caller(&self) -> bool {
        let callers = self.caller_protections.clone();
        for caller in callers {
            if caller.is_any() {
                return true;
            }
        }
        return false;
    }

    pub fn generate(&self, returns: bool) -> String {
        let returns = self.declaration.head.result_type.is_some() && returns;

        let scope = self.declaration.ScopeContext.clone();
        let scope = scope.unwrap_or(Default::default());
        let mut function_context = FunctionContext {
            environment: self.environment.clone(),
            scope_context: scope,
            InStructFunction: !self.IsContractFunction,
            block_stack: vec![YulBlock { statements: vec![] }],
            enclosing_type: self.identifier.token.clone(),
            counter: 0,
        };
        let parameters = self.declaration.head.parameters.clone();
        let parameters: Vec<String> = parameters
            .into_iter()
            .map(|p| {
                SolidityIdentifier {
                    identifier: p.identifier.clone(),
                    IsLValue: false,
                }
                .generate(&mut function_context)
            })
            .map(|p| format!("{}", p))
            .collect();
        let parameters = parameters.join(", ");
        let return_var = if returns {
            format!("-> ret")
        } else {
            format!("")
        };
        let name = self.declaration.mangledIdentifier.clone();
        let name = name.unwrap_or_default();
        let signature = format!(
            "{name}({parameters}) {return_var}",
            name = name,
            parameters = parameters,
            return_var = return_var
        );

        let scope = self.declaration.ScopeContext.clone();
        let scope = scope.unwrap_or(Default::default());

        let mut function_context = FunctionContext {
            environment: self.environment.clone(),
            enclosing_type: self.identifier.token.clone(),
            block_stack: vec![YulBlock { statements: vec![] }],
            scope_context: scope,
            InStructFunction: !self.IsContractFunction,
            counter: 0,
        };

        let caller_binding = if self.caller_binding.is_some() {
            let binding = self.caller_binding.clone();
            let binding = binding.unwrap();
            let binding = mangle(binding.token);
            format!("let {binding} := caller()\n", binding = binding)
        } else {
            "".to_string()
        };

        let mut statements = self.declaration.body.clone();
        let mut emitLastBrace = false;
        while !statements.is_empty() {
            let statement = statements.remove(0);
            let yul_statement = SolidityStatement {
                statement: statement.clone(),
            }
            .generate(&mut function_context);
            function_context.emit(yul_statement);
            if let Statement::IfStatement(i) = statement {
                if i.endsWithReturn() {
                    let else_body = i.else_body.clone();
                    if else_body.is_empty() {
                        let st = YulStatement::Inline(format!("default {{"));
                        emitLastBrace = true;
                        function_context.emit(st);
                    }
                }
            }
        }
        if emitLastBrace {
            let st = YulStatement::Inline(format!("}}"));
            function_context.emit(st);
        }
        let body = function_context.generate();
        let body = format!("{binding} {body}", binding = caller_binding, body = body);
        format!(
            "function {signature} {{ \n {body} \n }}",
            signature = signature,
            body = body
        )
    }

    pub fn mangled_signature(&self) -> String {
        let name = self.declaration.head.identifier.token.clone();
        let parameters = self.declaration.head.parameters.clone();
        let parameters: Vec<String> = parameters
            .into_iter()
            .map(|p| SolidityIRType::map_to_solidity_type(p.type_assignment).generate())
            .collect();
        let parameters = parameters.join(",");

        format!("{name}({params})", name = name, params = parameters)
    }
}

pub struct SolidityWrapperFunction {
    pub function: SolidityFunction,
}

impl SolidityWrapperFunction {
    pub fn generate(&self, t: &TypeIdentifier) -> String {
        let caller_check = SolidityCallerProtectionCheck {
            caller_protections: self.function.caller_protections.clone(),
            revert: false,
            variable: format!("_QuartzCallerCheck"),
        };

        let caller_code = caller_check.generate(t, self.function.environment.clone());

        unimplemented!()
    }

    pub fn get_prefix_hard() -> String {
        format!("quartzAttemptCallWrapperHard$")
    }
}

pub struct SolidityCallerProtectionCheck {
    pub caller_protections: Vec<CallerProtection>,
    pub revert: bool,
    pub variable: String,
}

impl SolidityCallerProtectionCheck {
    pub fn generate(&self, t: &TypeIdentifier, environment: Environment) -> String {
        let checks: Vec<String> = self
            .caller_protections
            .clone()
            .into_iter()
            .filter_map(|c| {
                if !c.is_any() {
                    let caller_type = environment.get_property_type(
                        c.name(),
                        t,
                        ScopeContext {
                            parameters: vec![],
                            local_variables: vec![],
                            counter: 0,
                        },
                    );

                    let offset = environment.property_offset(c.name(), t);

                    let function_context = FunctionContext {
                        environment: environment.clone(),
                        scope_context: Default::default(),
                        InStructFunction: false,
                        block_stack: vec![YulBlock { statements: vec![] }],
                        enclosing_type: t.to_string(),
                        counter: 0,
                    };

                    match caller_type {
                        Type::Address => {
                            let address = format!("sload({offset})", offset = offset);
                            let check =
                                SolidityRuntimeFunction::is_valid_caller_protection(address);
                            return Option::from(format!(
                                "{variable} := add({variable}, {check})",
                                variable = self.variable,
                                check = check
                            ));
                        }
                        _ => unimplemented!(),
                    }
                    Some(format!(""))
                } else {
                    None
                }
            })
            .collect();

        let revert = if self.revert {
            format!(
                "if eq({variable}, 0) {{ revert(0, 0) }}",
                variable = self.variable
            )
        } else {
            format!("")
        };

        if checks.is_empty() {
            return format!("");
        } else {
            let checks = checks.join("\n");
            return format!(
                "let {var} := 0 \n {checks} {revert}",
                var = self.variable,
                checks = checks,
                revert = revert
            );
        }
    }
}

pub struct SolidityStatement {
    pub statement: Statement,
}

impl SolidityStatement {
    pub fn generate(&self, function_context: &mut FunctionContext) -> YulStatement {
        match self.statement.clone() {
            Statement::ReturnStatement(r) => {
                SolidityReturnStatement { statement: r }.generate(function_context)
            }
            Statement::Expression(e) => YulStatement::Expression(
                SolidityExpression {
                    expression: e,
                    IsLValue: false,
                }
                .generate(function_context),
            ),
            Statement::BecomeStatement(_) => panic!("Become Statement Not Currently Supported"),
            Statement::EmitStatement(_) => unimplemented!(),
            Statement::ForStatement(_) => unimplemented!(),
            Statement::IfStatement(i) => {
                SolidityIfStatement { statement: i }.generate(function_context)
            }
            Statement::DoCatchStatement(_) => panic!("Catch Statement Not Currently Supported"),
        }
    }
}

pub struct SolidityReturnStatement {
    pub statement: ReturnStatement,
}

impl SolidityReturnStatement {
    pub fn generate(&self, function_context: &mut FunctionContext) -> YulStatement {
        if self.statement.expression.is_none() {
            return YulStatement::Inline("".to_string());
        }
        let expression = self.statement.expression.clone();
        let expression = expression.unwrap();
        let expression = SolidityExpression {
            expression,
            IsLValue: false,
        }
        .generate(function_context);
        let string = format!("ret := {expression}", expression = expression);
        return YulStatement::Inline(string);
    }
}

pub struct SolidityIfStatement {
    pub statement: IfStatement,
}

impl SolidityIfStatement {
    pub fn generate(&self, function_context: &mut FunctionContext) -> YulStatement {
        let condition = SolidityExpression {
            expression: self.statement.condition.clone(),
            IsLValue: false,
        }
        .generate(function_context);

        println!("With new block");
        let count = function_context.push_block();
        for statement in self.statement.body.clone() {
            let statement = SolidityStatement { statement }.generate(function_context);
            function_context.emit(statement);
        }
        let body = function_context.with_new_block(count);

        YulStatement::Switch(YulSwitch {
            expression: condition,
            cases: vec![(YulLiteral::Num(1), body)],
            default: None,
        })
    }
}

pub struct SolidityExpression {
    pub expression: Expression,
    pub IsLValue: bool,
}

impl SolidityExpression {
    pub fn generate(&self, function_context: &mut FunctionContext) -> YulExpression {
        match self.expression.clone() {
            Expression::Identifier(i) => SolidityIdentifier {
                identifier: i,
                IsLValue: self.IsLValue,
            }
            .generate(function_context),
            Expression::BinaryExpression(b) => SolidityBinaryExpression {
                expression: b,
                IsLValue: self.IsLValue,
            }
            .generate(function_context),
            Expression::InoutExpression(i) => SolidityExpression {
                expression: *i.expression.clone(),
                IsLValue: true,
            }
            .generate(function_context),
            Expression::ExternalCall(e) => {
                SolidityExternalCall { call: e }.generate(function_context)
            }
            Expression::FunctionCall(f) => {
                SolidityFunctionCall { function_call: f }.generate(function_context)
            }
            Expression::VariableDeclaration(v) => {
                SolidityVariableDeclaration { declaration: v }.generate(function_context)
            }
            Expression::BracketedExpression(e) => SolidityExpression {
                expression: *e.expression,
                IsLValue: false,
            }
            .generate(function_context),
            Expression::AttemptExpression(_) => {
                panic!("Attempt Expression Not Currently Supported")
            }
            Expression::Literal(l) => {
                YulExpression::Literal(SolidityLiteral { literal: l }.generate())
            }
            Expression::ArrayLiteral(a) => {
                for e in a.elements {
                    if let Expression::ArrayLiteral(_) = e {
                    } else {
                        panic!("Does not support Non-empty array literals")
                    }
                }
                YulExpression::Literal(YulLiteral::Num(0))
            }
            Expression::DictionaryLiteral(_) => unimplemented!(),
            Expression::SelfExpression => SoliditySelfExpression {
                IsLValue: self.IsLValue,
            }
            .generate(function_context),
            Expression::SubscriptExpression(s) => SoliditySubscriptExpression {
                expression: s,
                IsLValue: self.IsLValue.clone(),
            }
            .generate(function_context),
            Expression::RangeExpression(_) => unimplemented!(),
            Expression::RawAssembly(a, _) => YulExpression::Inline(a),
            Expression::CastExpression(c) => {
                SolidityCastExpression { expression: c }.generate(function_context)
            }
            Expression::Sequence(s) => {
                let mut sequence = vec![];
                for expression in s {
                    let result = SolidityExpression {
                        expression,
                        IsLValue: self.IsLValue,
                    }
                    .generate(function_context);
                    sequence.push(result);
                }

                let sequence: Vec<String> =
                    sequence.into_iter().map(|s| format!("{}", s)).collect();
                let sequence = sequence.join("\n");

                YulExpression::Inline(sequence)
            }
        }
    }
}

pub struct SolidityCastExpression {
    pub expression: CastExpression,
}

impl SolidityCastExpression {
    pub fn generate(&self, function_context: &mut FunctionContext) -> YulExpression {
        let exp = *self.expression.expression.clone();
        let enclosing = if exp.enclosing_type().is_some() {
            let i = exp.enclosing_type().clone();
            i.unwrap()
        } else {
            function_context.enclosing_type.clone()
        };

        let original_type = function_context.environment.get_expression_type(
            *self.expression.expression.clone(),
            &enclosing,
            vec![],
            vec![],
            function_context.scope_context.clone(),
        );
        let target_type = self.expression.cast_type.clone();

        let original_type_info = SolidityCastExpression::get_type_info(original_type);
        let target_type_info = SolidityCastExpression::get_type_info(target_type);

        let expression_ir = SolidityExpression {
            expression: *self.expression.expression.clone(),
            IsLValue: false,
        }
        .generate(function_context);

        if original_type_info.0 <= target_type_info.0 {
            return expression_ir;
        }

        let target_max = SolidityCastExpression::maximum_value(target_type_info.0);
        SolidityRuntimeFunction::revert_if_greater(
            expression_ir,
            YulExpression::Literal(YulLiteral::Hex(target_max)),
        )
    }

    pub fn maximum_value(input: u64) -> String {
        match input {
            8 => format!("0xFF"),
            16 => format!("0xFFFF"),
            24 => format!("0xFFFFFF"),
            32 => format!("0xFFFFFFFF"),
            40 => format!("0xFFFFFFFFFF"),
            48 => format!("0xFFFFFFFFFFFF"),
            56 => format!("0xFFFFFFFFFFFFFF"),
            64 => format!("0xFFFFFFFFFFFFFFFF"),
            72 => format!("0xFFFFFFFFFFFFFFFFFF"),
            80 => format!("0xFFFFFFFFFFFFFFFFFFFF"),
            88 => format!("0xFFFFFFFFFFFFFFFFFFFFFF"),
            96 => format!("0xFFFFFFFFFFFFFFFFFFFFFFFF"),
            104 => format!("0xFFFFFFFFFFFFFFFFFFFFFFFFFF"),
            112 => format!("0xFFFFFFFFFFFFFFFFFFFFFFFFFFFF"),
            120 => format!("0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF"),
            128 => format!("0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF"),
            136 => format!("0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF"),
            144 => format!("0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF"),
            152 => format!("0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF"),
            160 => format!("0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF"),
            168 => format!("0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF"),
            176 => format!("0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF"),
            184 => format!("0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF"),
            192 => format!("0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF"),
            200 => format!("0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF"),
            208 => format!("0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF"),
            216 => format!("0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF"),
            224 => format!("0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF"),
            232 => format!("0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF"),
            240 => format!("0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF"),
            248 => format!("0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF"),
            256 => format!("0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF"),
            _ => panic!("Not Supported Value"),
        }
    }

    pub fn get_type_info(input: Type) -> (u64, bool) {
        match input {
            Type::Bool => (256, false),
            Type::Int => (256, true),
            Type::String => (256, false),
            Type::Address => (256, false),
            Type::Solidity(s) => match s.clone() {
                SolidityType::address => return (256, false),
                SolidityType::string => return (256, false),
                SolidityType::bool => return (256, false),
                SolidityType::int8 => return (8, true),
                SolidityType::int16 => return (16, true),
                SolidityType::int24 => return (24, true),
                SolidityType::int32 => return (32, true),
                SolidityType::int40 => return (40, true),
                SolidityType::int48 => return (48, true),
                SolidityType::int56 => return (56, true),
                SolidityType::int64 => return (64, true),
                SolidityType::int72 => return (72, true),
                SolidityType::int80 => return (80, true),
                SolidityType::int88 => return (88, true),
                SolidityType::int96 => return (96, true),
                SolidityType::int104 => return (104, true),
                SolidityType::int112 => return (112, true),
                SolidityType::int120 => return (120, true),
                SolidityType::int128 => return (128, true),
                SolidityType::int136 => return (136, true),
                SolidityType::int144 => return (152, true),
                SolidityType::int152 => return (152, true),
                SolidityType::int160 => return (160, true),
                SolidityType::int168 => return (168, true),
                SolidityType::int176 => return (176, true),
                SolidityType::int184 => return (184, true),
                SolidityType::int192 => return (192, true),
                SolidityType::int200 => return (200, true),
                SolidityType::int208 => return (208, true),
                SolidityType::int216 => return (216, true),
                SolidityType::int224 => return (224, true),
                SolidityType::int232 => return (232, true),
                SolidityType::int240 => return (240, true),
                SolidityType::int248 => return (248, true),
                SolidityType::int256 => return (256, true),
                SolidityType::uint8 => return (8, false),
                SolidityType::uint16 => return (16, false),
                SolidityType::uint24 => return (24, false),
                SolidityType::uint32 => return (32, false),
                SolidityType::uint40 => return (40, false),
                SolidityType::uint48 => return (48, false),
                SolidityType::uint56 => return (56, false),
                SolidityType::uint64 => return (64, false),
                SolidityType::uint72 => return (72, false),
                SolidityType::uint80 => return (80, false),
                SolidityType::uint88 => return (88, false),
                SolidityType::uint96 => return (96, false),
                SolidityType::uint104 => return (104, false),
                SolidityType::uint112 => return (112, false),
                SolidityType::uint120 => return (120, false),
                SolidityType::uint128 => return (128, false),
                SolidityType::uint136 => return (136, false),
                SolidityType::uint144 => return (152, false),
                SolidityType::uint152 => return (152, false),
                SolidityType::uint160 => return (160, false),
                SolidityType::uint168 => return (168, false),
                SolidityType::uint176 => return (176, false),
                SolidityType::uint184 => return (184, false),
                SolidityType::uint192 => return (192, false),
                SolidityType::uint200 => return (200, false),
                SolidityType::uint208 => return (208, false),
                SolidityType::uint216 => return (216, false),
                SolidityType::uint224 => return (224, false),
                SolidityType::uint232 => return (232, false),
                SolidityType::uint240 => return (240, false),
                SolidityType::uint248 => return (248, false),
                SolidityType::uint256 => return (256, false),
            },
            _ => (256, false),
        }
    }
}

pub struct SolidityExternalCall {
    pub call: ExternalCall,
}

impl SolidityExternalCall {
    pub fn generate(&self, function_context: &mut FunctionContext) -> YulExpression {
        let gas = YulExpression::Literal(YulLiteral::Num(2300));
        let value = YulExpression::Literal(YulLiteral::Num(0));

        let mut f_call: FunctionCall;
        let rhs = *self.call.function_call.rhs_expression.clone();
        if let Expression::FunctionCall(f) = rhs {
            f_call = f;
        } else {
            panic!("Solidity External Call RHS not function call")
        }

        let enclosing = if f_call.identifier.enclosing_type.is_some() {
            let i = f_call.identifier.enclosing_type.clone();
            let i = i.unwrap();
            i
        } else {
            function_context.enclosing_type.clone()
        };
        let matched = function_context.environment.match_function_call(
            f_call.clone(),
            &enclosing,
            vec![],
            function_context.scope_context.clone(),
        );

        let match_result: FunctionInformation;
        if let FunctionCallMatchResult::MatchedFunction(m) = matched.clone() {
            match_result = m;
        } else {
            panic!("Solidity External Call cannot match function call")
        }

        let function_selector = match_result.declaration.external_signature_hash().clone();
        let first_slice = &function_selector.clone()[..2];
        let second_slice = &function_selector.clone()[2..4];
        let third_slice = &function_selector.clone()[4..6];
        let fourth_slice = &function_selector.clone()[6..8];

        let address_expression = SolidityExpression {
            expression: *self.call.function_call.lhs_expression.clone(),
            IsLValue: false,
        }
        .generate(function_context);

        let mut static_slots = vec![];
        let mut dynamic_slots = vec![];
        let mut static_size = 0;

        let param_types = match_result.declaration.head.parameter_types().clone();

        for param in param_types {
            match param {
                Type::Solidity(_) => static_size += 32,
                _ => panic!("Non Solidity Type not allowed in external call"),
            }
        }

        let dynamic_size = 0;

        let param_types = match_result.declaration.head.parameter_types().clone();
        let f_args = f_call.arguments.clone();

        let pairs: Vec<(Type, FunctionArgument)> =
            param_types.into_iter().zip(f_args.into_iter()).collect();

        for (p, q) in pairs {
            match p {
                Type::String => {
                    dynamic_slots.push(YulExpression::Literal(YulLiteral::Num(32)));
                    unimplemented!()
                }
                Type::Int => {
                    let expression = q.clone();
                    let expression = SolidityExpression {
                        expression: expression.expression.clone(),
                        IsLValue: false,
                    }
                    .generate(function_context);
                    static_slots.push(expression);
                }
                Type::Address => {
                    let expression = q.clone();
                    let expression = SolidityExpression {
                        expression: expression.expression.clone(),
                        IsLValue: false,
                    }
                    .generate(function_context);
                    static_slots.push(expression);
                }
                Type::Bool => {
                    let expression = q.clone();
                    let expression = SolidityExpression {
                        expression: expression.expression.clone(),
                        IsLValue: false,
                    }
                    .generate(function_context);
                    static_slots.push(expression);
                }
                Type::Solidity(_) => {
                    let expression = q.clone();
                    let expression = SolidityExpression {
                        expression: expression.expression.clone(),
                        IsLValue: false,
                    }
                    .generate(function_context);
                    static_slots.push(expression);
                }
                _ => panic!("Can not use non basic types in external call"),
            }
        }

        let call_input = function_context.fresh_variable();

        let input_size = 4 + static_size + dynamic_size;
        let mut slots = static_slots.clone();
        slots.append(&mut dynamic_slots);

        let output_size = 32;

        let call_success = function_context.fresh_variable();
        let call_output = function_context.fresh_variable();

        let statement =
            YulStatement::Expression(YulExpression::VariableDeclaration(YulVariableDeclaration {
                declaration: call_input.clone(),
                declaration_type: YulType::Any,
                expression: Option::from(Box::new(SolidityRuntimeFunction::allocate_memory(
                    input_size,
                ))),
            }));
        function_context.emit(statement);

        let statement = YulStatement::Expression(YulExpression::FunctionCall(YulFunctionCall {
            name: "mstore8".to_string(),
            arguments: vec![
                YulExpression::Identifier(call_input.clone()),
                YulExpression::Literal(YulLiteral::Hex(format!("0x{}", first_slice))),
            ],
        }));
        function_context.emit(statement);

        let statement = YulStatement::Expression(YulExpression::FunctionCall(YulFunctionCall {
            name: "mstore8".to_string(),
            arguments: vec![
                YulExpression::FunctionCall(YulFunctionCall {
                    name: "add".to_string(),
                    arguments: vec![
                        YulExpression::Identifier(call_input.clone()),
                        YulExpression::Literal(YulLiteral::Num(1)),
                    ],
                }),
                YulExpression::Literal(YulLiteral::Hex(format!("0x{}", second_slice))),
            ],
        }));
        function_context.emit(statement);

        let statement = YulStatement::Expression(YulExpression::FunctionCall(YulFunctionCall {
            name: "mstore8".to_string(),
            arguments: vec![
                YulExpression::FunctionCall(YulFunctionCall {
                    name: "add".to_string(),
                    arguments: vec![
                        YulExpression::Identifier(call_input.clone()),
                        YulExpression::Literal(YulLiteral::Num(2)),
                    ],
                }),
                YulExpression::Literal(YulLiteral::Hex(format!("0x{}", third_slice))),
            ],
        }));
        function_context.emit(statement);
        let statement = YulStatement::Expression(YulExpression::FunctionCall(YulFunctionCall {
            name: "mstore8".to_string(),
            arguments: vec![
                YulExpression::FunctionCall(YulFunctionCall {
                    name: "add".to_string(),
                    arguments: vec![
                        YulExpression::Identifier(call_input.clone()),
                        YulExpression::Literal(YulLiteral::Num(3)),
                    ],
                }),
                YulExpression::Literal(YulLiteral::Hex(format!("0x{}", fourth_slice))),
            ],
        }));
        function_context.emit(statement);

        let mut cur_position = 4;
        for slot in slots {
            let call = YulExpression::FunctionCall(YulFunctionCall {
                name: "add".to_string(),
                arguments: vec![
                    YulExpression::Identifier(call_input.clone()),
                    YulExpression::Literal(YulLiteral::Num(cur_position.clone())),
                ],
            });
            let expresion =
                YulStatement::Expression(YulExpression::FunctionCall(YulFunctionCall {
                    name: "mstore".to_string(),
                    arguments: vec![call, slot.clone()],
                }));
            function_context.emit(expresion);
            cur_position += 32;
        }

        let statement =
            YulStatement::Expression(YulExpression::VariableDeclaration(YulVariableDeclaration {
                declaration: call_output.clone(),
                declaration_type: YulType::Any,
                expression: Option::from(Box::new(SolidityRuntimeFunction::allocate_memory(
                    output_size,
                ))),
            }));
        function_context.emit(statement);

        let call_exp = YulExpression::FunctionCall(YulFunctionCall {
            name: "call".to_string(),
            arguments: vec![
                gas,
                address_expression,
                value,
                YulExpression::Identifier(call_input.clone()),
                YulExpression::Literal(YulLiteral::Num(input_size)),
                YulExpression::Identifier(call_output.clone()),
                YulExpression::Literal(YulLiteral::Num(output_size)),
            ],
        });
        let var =
            YulStatement::Expression(YulExpression::VariableDeclaration(YulVariableDeclaration {
                declaration: call_success.clone(),
                declaration_type: YulType::Any,
                expression: Option::from(Box::new(call_exp)),
            }));

        function_context.emit(var);

        let f_call = YulExpression::FunctionCall(YulFunctionCall {
            name: "mload".to_string(),
            arguments: vec![YulExpression::Identifier(call_output.clone())],
        });
        let expression = YulStatement::Expression(YulExpression::Assignment(YulAssignment {
            identifiers: vec![call_output.clone()],
            expression: Box::new(f_call),
        }));

        function_context.emit(expression);

        return YulExpression::Identifier(call_output);
    }
}

pub struct SoliditySubscriptExpression {
    pub expression: SubscriptExpression,
    pub IsLValue: bool,
}

impl SoliditySubscriptExpression {
    pub fn generate(&self, function_context: &mut FunctionContext) -> YulExpression {
        let identifier = SoliditySubscriptExpression::base_identifier(
            Expression::SubscriptExpression(self.expression.clone()),
        );
        println!("{:?}", self.expression.clone());
        if identifier.enclosing_type.is_none() {
            panic!("Arrays not supported as local variables")
        }

        let enclosing = identifier.enclosing_type.clone();
        let enclosing = enclosing.unwrap_or_default();
        let offset = function_context
            .environment
            .property_offset(identifier.token.clone(), &enclosing);

        let memLocation = SoliditySubscriptExpression::nested_offset(
            self.expression.clone(),
            offset,
            function_context,
        );

        if self.IsLValue {
            return memLocation;
        } else {
            return YulExpression::FunctionCall(YulFunctionCall {
                name: format!("sload"),
                arguments: vec![memLocation],
            });
        }
    }

    pub fn base_identifier(expression: Expression) -> Identifier {
        if let Expression::Identifier(i) = expression {
            return i;
        }
        if let Expression::SubscriptExpression(s) = expression {
            return SoliditySubscriptExpression::base_identifier(Expression::Identifier(
                s.base_expression,
            ));
        }
        panic!("Can not find base identifier");
    }

    pub fn nested_offset(
        expression: SubscriptExpression,
        base_offset: u64,
        function_context: &mut FunctionContext,
    ) -> YulExpression {
        let index_expression = SolidityExpression {
            expression: *expression.index_expression.clone(),
            IsLValue: false,
        }
        .generate(function_context);

        let base_type = function_context.environment.get_expression_type(
            Expression::Identifier(expression.base_expression.clone()),
            &function_context.enclosing_type.clone(),
            vec![],
            vec![],
            function_context.scope_context.clone(),
        );

        println!("{:?}", expression.base_expression.clone());

        let (a, b) = (
            YulExpression::Literal(YulLiteral::Num(base_offset)),
            index_expression,
        );

        let runtime = match base_type.clone() {
            Type::ArrayType(_) => SolidityRuntimeFunction::storage_array_offset(a, b),
            Type::FixedSizedArrayType(f) => {
                let size = function_context.environment.type_size(base_type);
                SolidityRuntimeFunction::storage_fixed_array_offset(a, b, size)
            }
            Type::DictionaryType(_) => SolidityRuntimeFunction::storage_dictionary_offset_key(a, b),
            _ => panic!("Invalid Type"),
        };

        return runtime;
    }
}

pub struct SoliditySelfExpression {
    pub IsLValue: bool,
}

impl SoliditySelfExpression {
    pub fn generate(&self, function_context: &FunctionContext) -> YulExpression {
        let ident = if function_context.InStructFunction {
            format!("_QuartzSelf")
        } else {
            if self.IsLValue {
                format!("0")
            } else {
                format!("")
            }
        };
        YulExpression::Identifier(ident)
    }
}

pub struct SolidityFunctionCall {
    pub function_call: FunctionCall,
}

impl SolidityFunctionCall {
    pub fn generate(&self, function_context: &mut FunctionContext) -> YulExpression {
        let match_result = function_context.environment.match_function_call(
            self.function_call.clone(),
            &function_context.enclosing_type,
            vec![],
            function_context.scope_context.clone(),
        );

        if let FunctionCallMatchResult::MatchedInitializer(i) = match_result {
            let mut arg = self.function_call.arguments.clone();
            let arg = arg.remove(0);
            if i.declaration.generated {
                return SolidityExpression {
                    expression: arg.expression,
                    IsLValue: false,
                }
                .generate(function_context);
            }
        }

        let args = self.function_call.arguments.clone();
        let args: Vec<YulExpression> = args
            .into_iter()
            .map(|a| {
                SolidityExpression {
                    expression: a.expression,
                    IsLValue: false,
                }
                .generate(function_context)
            })
            .collect();

        let identifier = if self.function_call.mangled_identifier.is_some() {
            let ident = self.function_call.mangled_identifier.clone();
            let ident = ident.unwrap();
            ident.token
        } else {
            self.function_call.identifier.token.clone()
        };

        return YulExpression::FunctionCall(YulFunctionCall {
            name: identifier,
            arguments: args,
        });
    }
}

pub struct SolidityIdentifier {
    pub identifier: Identifier,
    pub IsLValue: bool,
}

impl SolidityIdentifier {
    pub fn generate(&self, function_context: &mut FunctionContext) -> YulExpression {
        if self.identifier.enclosing_type.is_some() {
            return SolidityPropertyAccess {
                lhs: Expression::SelfExpression,
                rhs: Expression::Identifier(self.identifier.clone()),
                IsLeft: self.IsLValue,
            }
            .generate(function_context);
        }

        return YulExpression::Identifier(mangle(self.identifier.token.clone()));
    }
}

pub struct SolidityAssignment {
    pub lhs: Expression,
    pub rhs: Expression,
}

impl SolidityAssignment {
    pub fn generate(&self, function_context: &mut FunctionContext) -> YulExpression {
        let rhs_code = SolidityExpression {
            expression: self.rhs.clone(),
            IsLValue: false,
        }
        .generate(function_context);

        match self.lhs.clone() {
            Expression::VariableDeclaration(v) => {
                let mangle = mangle(v.identifier.token);
                return YulExpression::VariableDeclaration(YulVariableDeclaration {
                    declaration: mangle,
                    declaration_type: YulType::Any,
                    expression: Some(Box::from(rhs_code)),
                });
            }
            Expression::Identifier(i) if i.enclosing_type.is_none() => {
                return YulExpression::Assignment(YulAssignment {
                    identifiers: vec![mangle(i.token)],
                    expression: Box::from(rhs_code),
                });
            }
            _ => {
                println!("HERE we drop");
                let lhs_code = SolidityExpression {
                    expression: self.lhs.clone(),
                    IsLValue: true,
                }
                .generate(function_context);

                if function_context.InStructFunction {
                    let enclosing_name = if function_context
                        .scope_context
                        .enclosing_parameter(self.lhs.clone(), &function_context.enclosing_type)
                        .is_some()
                    {
                        function_context
                            .scope_context
                            .enclosing_parameter(self.lhs.clone(), &function_context.enclosing_type)
                            .unwrap()
                    } else {
                        format!("QuartzSelf")
                    };

                    return SolidityRuntimeFunction::store(
                        lhs_code,
                        rhs_code,
                        mangle(mangle_mem(enclosing_name)),
                    );
                } else if self.lhs.enclosing_identifier().is_some() {
                    let enclosing = self.lhs.enclosing_identifier().clone();
                    let enclosing = enclosing.unwrap();
                    if function_context
                        .scope_context
                        .contains_variable_declaration(enclosing.token.clone())
                    {
                        return SolidityRuntimeFunction::store_bool(lhs_code, rhs_code, true);
                    }
                }
                return SolidityRuntimeFunction::store_bool(lhs_code, rhs_code, false);
            }
        }
        unimplemented!()
    }
}

pub struct SolidityPropertyAccess {
    pub lhs: Expression,
    pub rhs: Expression,
    pub IsLeft: bool,
}

impl SolidityPropertyAccess {
    pub fn generate(&self, function_context: &mut FunctionContext) -> YulExpression {
        let type_identifier = function_context.enclosing_type.clone();
        let scope = function_context.scope_context.clone();
        let is_mem_access = false;
        let lhs_type = function_context.environment.get_expression_type(
            self.lhs.clone(),
            &type_identifier,
            vec![],
            vec![],
            scope.clone(),
        );
        if let Expression::Identifier(li) = self.lhs.clone() {
            if let Expression::Identifier(ri) = self.rhs.clone() {
                if function_context.environment.is_enum_declared(&li.token) {
                    unimplemented!()
                }
            }
        }

        let rhs_offset = match lhs_type {
            Type::ArrayType(_) => {
                if let Expression::Identifier(i) = self.rhs.clone() {
                    if i.token == "size".to_string() {
                        YulExpression::Literal(YulLiteral::Num(0))
                    } else {
                        panic!("Unsupported identifier on array")
                    }
                } else {
                    panic!("Unsupported identifier on array")
                }
            }
            Type::FixedSizedArrayType(_) => {
                if let Expression::Identifier(i) = self.rhs.clone() {
                    if i.token == "size".to_string() {
                        YulExpression::Literal(YulLiteral::Num(0))
                    } else {
                        panic!("Unsupported identifier on array")
                    }
                } else {
                    panic!("Unsupported identifier on array")
                }
            }
            Type::DictionaryType(_) => {
                if let Expression::Identifier(i) = self.rhs.clone() {
                    if i.token == "size".to_string() {
                        YulExpression::Literal(YulLiteral::Num(0))
                    } else {
                        panic!("Unsupported identifier on dictionary")
                    }
                } else {
                    panic!("Unsupported identifier on dictionary")
                }
            }
            _ => SolidityPropertyOffset {
                expression: self.rhs.clone(),
                enclosing_type: lhs_type,
            }
            .generate(function_context),
        };

        let offset = if function_context.InStructFunction {
            let enclosing_parameter = function_context
                .scope_context
                .enclosing_parameter(self.lhs.clone(), &type_identifier);
            let enclosing_name = if enclosing_parameter.is_some() {
                enclosing_parameter.unwrap()
            } else {
                format!("QuartzSelf")
            };

            let lhs_offset = YulExpression::Identifier(mangle(enclosing_name.clone()));
            SolidityRuntimeFunction::add_offset(
                lhs_offset,
                rhs_offset,
                mangle(mangle_mem((enclosing_name))),
            )
        } else {
            let lhs_offset = if let Expression::Identifier(i) = self.lhs.clone() {
                if i.enclosing_type.is_some() {
                    let enclosing_type = i.enclosing_type.clone();
                    let enclosing_type = enclosing_type.unwrap();
                    let offset = function_context
                        .environment
                        .property_offset(i.token.clone(), &enclosing_type);
                    YulExpression::Literal(YulLiteral::Num(offset))
                } else if function_context
                    .scope_context
                    .contains_variable_declaration(format!(""))
                {
                    unimplemented!()
                } else {
                    unimplemented!()
                }
            } else {
                SolidityExpression {
                    expression: self.lhs.clone(),
                    IsLValue: true,
                }
                .generate(function_context)
            };

            SolidityRuntimeFunction::add_offset_bool(lhs_offset, rhs_offset, is_mem_access)
        };

        if self.IsLeft {
            return offset;
        }

        if function_context.InStructFunction && !is_mem_access {
            let lhs_enclosing = if self.lhs.enclosing_identifier().is_some() {
                let ident = self.lhs.enclosing_identifier().clone();
                let ident = ident.unwrap();
                mangle(ident.token)
            } else {
                mangle("QuartzSelf".to_string())
            };

            return SolidityRuntimeFunction::load(offset, mangle_mem(lhs_enclosing));
        }

        SolidityRuntimeFunction::load_bool(offset, is_mem_access)
    }
}

#[derive(Debug)]
pub struct SolidityPropertyOffset {
    pub expression: Expression,
    pub enclosing_type: Type,
}

impl SolidityPropertyOffset {
    pub fn generate(&self, function_context: &mut FunctionContext) -> YulExpression {
        if let Expression::BinaryExpression(b) = self.expression.clone() {
            return SolidityPropertyAccess {
                lhs: *b.lhs_expression,
                rhs: *b.rhs_expression,
                IsLeft: true,
            }
            .generate(function_context);
        } else if let Expression::SubscriptExpression(s) = self.expression.clone() {
            return SoliditySubscriptExpression {
                expression: s.clone(),
                IsLValue: true,
            }
            .generate(function_context);
        }

        if let Expression::Identifier(i) = self.expression.clone() {
            if let Type::UserDefinedType(t) = self.enclosing_type.clone() {
                let offset = function_context
                    .environment
                    .property_offset(i.token.clone(), &t.token);
                return YulExpression::Literal(YulLiteral::Num(offset));
            }

            panic!("Fatal Error")
        }

        panic!("Fatal Error")
    }
}

#[derive(Debug)]
pub enum SolidityRuntimeFunction {
    Selector,
    CheckNoValue,
    CallValue,
    ComputeOffset,
    DecodeAsAddress,
    DecodeAsUInt,
    Return32Bytes,
    RevertIfGreater,
    StorageArrayOffset,
    StorageFixedSizeArrayOffset,
    StorageDictionaryOffsetForKey,
    AllocateMemory,
    Load,
    Store,
    Add,
    Sub,
    Mul,
    Div,
    Power,
    IsValidCallerProtection,
}

impl SolidityRuntimeFunction {
    pub fn mangle_runtime(&self) -> String {
        format!("Quartz${}", self)
    }

    pub fn call_value() -> String {
        format!("callvalue()")
    }

    pub fn selector() -> String {
        format!("{}()", SolidityRuntimeFunction::Selector.mangle_runtime())
    }

    pub fn is_valid_caller_protection(address: String) -> String {
        format!(
            "{name}({address})",
            name = SolidityRuntimeFunction::IsValidCallerProtection.mangle_runtime(),
            address = address
        )
    }

    pub fn revert_if_greater(value: YulExpression, max: YulExpression) -> YulExpression {
        YulExpression::FunctionCall(YulFunctionCall {
            name: SolidityRuntimeFunction::RevertIfGreater.mangle_runtime(),
            arguments: vec![value, max],
        })
    }

    pub fn add_offset(
        expression: YulExpression,
        offset: YulExpression,
        in_mem: String,
    ) -> YulExpression {
        YulExpression::FunctionCall(YulFunctionCall {
            name: SolidityRuntimeFunction::ComputeOffset.mangle_runtime(),
            arguments: vec![expression, offset, YulExpression::Identifier(in_mem)],
        })
    }

    pub fn decode_as_uint(offset: u64) -> String {
        format!(
            "{func}({offset})",
            func = SolidityRuntimeFunction::DecodeAsUInt.mangle_runtime(),
            offset = offset
        )
    }

    pub fn decode_as_address(offset: u64) -> String {
        format!(
            "{func}({offset})",
            func = SolidityRuntimeFunction::DecodeAsAddress.mangle_runtime(),
            offset = offset
        )
    }

    pub fn return_32_bytes(input: String) -> String {
        format!(
            "{func}({input})",
            func = SolidityRuntimeFunction::Return32Bytes.mangle_runtime(),
            input = input
        )
    }

    pub fn add_offset_bool(
        expression: YulExpression,
        offset: YulExpression,
        in_mem: bool,
    ) -> YulExpression {
        let offset = if in_mem {
            YulExpression::FunctionCall(YulFunctionCall {
                name: "mul".to_string(),
                arguments: vec![YulExpression::Literal(YulLiteral::Num(32)), offset],
            })
        } else {
            offset
        };
        YulExpression::FunctionCall(YulFunctionCall {
            name: "add".to_string(),
            arguments: vec![expression, offset],
        })
    }

    pub fn storage_array_offset(offset: YulExpression, index: YulExpression) -> YulExpression {
        YulExpression::FunctionCall(YulFunctionCall {
            name: SolidityRuntimeFunction::StorageArrayOffset.mangle_runtime(),
            arguments: vec![offset, index],
        })
    }

    pub fn storage_fixed_array_offset(
        offset: YulExpression,
        index: YulExpression,
        size: u64,
    ) -> YulExpression {
        YulExpression::FunctionCall(YulFunctionCall {
            name: SolidityRuntimeFunction::StorageFixedSizeArrayOffset.mangle_runtime(),
            arguments: vec![offset, index, YulExpression::Literal(YulLiteral::Num(size))],
        })
    }

    pub fn storage_dictionary_offset_key(
        offset: YulExpression,
        index: YulExpression,
    ) -> YulExpression {
        YulExpression::FunctionCall(YulFunctionCall {
            name: SolidityRuntimeFunction::StorageDictionaryOffsetForKey.mangle_runtime(),
            arguments: vec![offset, index],
        })
    }

    pub fn allocate_memory(size: u64) -> YulExpression {
        YulExpression::FunctionCall(YulFunctionCall {
            name: SolidityRuntimeFunction::AllocateMemory.mangle_runtime(),
            arguments: vec![YulExpression::Literal(YulLiteral::Num(size))],
        })
    }

    pub fn load(address: YulExpression, in_mem: String) -> YulExpression {
        let identifier = YulExpression::Identifier(in_mem);
        YulExpression::FunctionCall(YulFunctionCall {
            name: SolidityRuntimeFunction::Load.mangle_runtime(),
            arguments: vec![address, identifier],
        })
    }

    pub fn load_bool(address: YulExpression, in_mem: bool) -> YulExpression {
        let name = if in_mem {
            format!("mload")
        } else {
            format!("sload")
        };
        YulExpression::FunctionCall(YulFunctionCall {
            name,
            arguments: vec![address],
        })
    }

    pub fn store(address: YulExpression, value: YulExpression, in_mem: String) -> YulExpression {
        let identifier = YulExpression::Identifier(in_mem);
        YulExpression::FunctionCall(YulFunctionCall {
            name: SolidityRuntimeFunction::Store.mangle_runtime(),
            arguments: vec![address, value, identifier],
        })
    }

    pub fn store_bool(address: YulExpression, value: YulExpression, in_mem: bool) -> YulExpression {
        let name = if in_mem {
            format!("mstore")
        } else {
            format!("sstore")
        };
        YulExpression::FunctionCall(YulFunctionCall {
            name,
            arguments: vec![address, value],
        })
    }

    pub fn mul(a: YulExpression, b: YulExpression) -> YulExpression {
        YulExpression::FunctionCall(YulFunctionCall {
            name: SolidityRuntimeFunction::Mul.mangle_runtime(),
            arguments: vec![a, b],
        })
    }

    pub fn div(a: YulExpression, b: YulExpression) -> YulExpression {
        YulExpression::FunctionCall(YulFunctionCall {
            name: SolidityRuntimeFunction::Div.mangle_runtime(),
            arguments: vec![a, b],
        })
    }

    pub fn add(a: YulExpression, b: YulExpression) -> YulExpression {
        YulExpression::FunctionCall(YulFunctionCall {
            name: SolidityRuntimeFunction::Add.mangle_runtime(),
            arguments: vec![a, b],
        })
    }

    pub fn sub(a: YulExpression, b: YulExpression) -> YulExpression {
        YulExpression::FunctionCall(YulFunctionCall {
            name: SolidityRuntimeFunction::Sub.mangle_runtime(),
            arguments: vec![a, b],
        })
    }

    pub fn power(a: YulExpression, b: YulExpression) -> YulExpression {
        YulExpression::FunctionCall(YulFunctionCall {
            name: SolidityRuntimeFunction::Power.mangle_runtime(),
            arguments: vec![a, b],
        })
    }

    pub fn get_all_functions() -> Vec<String> {
        vec![
            SolidityRuntimeFunction::add_function(),
            SolidityRuntimeFunction::sub_function(),
            SolidityRuntimeFunction::mul_function(),
            SolidityRuntimeFunction::div_function(),
            SolidityRuntimeFunction::power_function(),
            SolidityRuntimeFunction::revert_if_greater_function(),
            SolidityRuntimeFunction::fatal_error_function(),
            SolidityRuntimeFunction::send_function(),
            SolidityRuntimeFunction::decode_address_function(),
            SolidityRuntimeFunction::decode_uint_function(),
            SolidityRuntimeFunction::selector_function(),
            SolidityRuntimeFunction::store_function(),
            SolidityRuntimeFunction::storage_dictionary_keys_array_offset_function(),
            SolidityRuntimeFunction::storage_offset_for_key_function(),
            SolidityRuntimeFunction::storage_dictionary_offset_for_key_function(),
            SolidityRuntimeFunction::storage_array_offset_function(),
            SolidityRuntimeFunction::is_invalid_subscript_expression_function(),
            SolidityRuntimeFunction::return_32_bytes_function(),
            SolidityRuntimeFunction::is_caller_protection_in_dictionary_function(),
            SolidityRuntimeFunction::is_caller_protection_in_array_function(),
            SolidityRuntimeFunction::is_valid_caller_protection_function(),
            SolidityRuntimeFunction::check_no_value_function(),
            SolidityRuntimeFunction::allocate_memory_function(),
            SolidityRuntimeFunction::compute_offset_function(),
            SolidityRuntimeFunction::load_function(),
        ]
    }

    pub fn add_function() -> String {
        format!("function Quartz$Add(a, b) -> ret {{ \n let c := add(a, b) \n if lt(c, a) {{ revert(0, 0) }} \n ret := c \n }}")
    }

    pub fn sub_function() -> String {
        format!("function Quartz$Sub(a, b) -> ret {{ \n if gt(b, a) {{ revert(0, 0) }} \n ret := sub(a, b) \n }}")
    }

    pub fn mul_function() -> String {
        "function Quartz$Mul(a, b) -> ret {
            switch iszero(a)
                case 1 {
                    ret := 0
                }
                default {
                    let c := mul(a, b)
                    if iszero(eq(div(c, a), b)) {
                        revert(0, 0)
                    }
                    ret := c
                }
        }"
        .to_string()
    }

    pub fn div_function() -> String {
        "function Quartz$Div(a, b) -> ret {
            if eq(b, 0) {
                revert(0, 0)
            }
            ret := div(a, b)
        }"
        .to_string()
    }

    pub fn power_function() -> String {
        "function Quartz$Power(b, e) -> ret {
            ret := 1
            for { let i := 0 } lt(i, e) { i := add(i, 1)}{
                ret := Quartz$Mul(ret, b)
            }
        }"
        .to_string()
    }

    pub fn revert_if_greater_function() -> String {
        "function Quartz$RevertIfGreater(a, b) -> ret {
            if gt(a, b) {
                revert(0, 0)
            }
            ret := a
        }"
        .to_string()
    }

    pub fn fatal_error_function() -> String {
        "function Quartz$FatalError() {
            revert(0, 0)
        }"
        .to_string()
    }

    pub fn send_function() -> String {
        "function Quartz$Send(_value, _address) {
            let ret := call(gas(), _address, _value, 0, 0, 0, 0)
            if iszero(ret) {
                revert(0, 0)
            }
        }"
        .to_string()
    }

    pub fn storage_dictionary_keys_array_offset_function() -> String {
        "function Quartz$StorageDictionaryKeysArrayOffset(dictionaryOffset) -> ret {
            mstore(0, dictionaryOffset)
            ret := keccak256(0, 32)
        }"
        .to_string()
    }

    pub fn storage_offset_for_key_function() -> String {
        "function Quartz$StorageOffsetForKey(offset, key) -> ret {
            mstore(0, key)
            mstore(32, offset)
            ret := keccak256(0, 64)
         }"
        .to_string()
    }

    pub fn storage_dictionary_offset_for_key_function() -> String {
        "function Quartz$StorageDictionaryOffsetForKey(dictionaryOffset, key) -> ret {
            let offsetForKey := Quartz$StorageOffsetForKey(dictionaryOffset, key)
            mstore(0, offsetForKey)
            let indexOffset := keccak256(0, 32)
            switch eq(sload(indexOffset), 0)
                case 1 {
                    let keysArrayOffset := Quartz$StorageDictionaryKeysArrayOffset(dictionaryOffset)
                    let index := add(sload(dictionaryOffset), 1)
                    sstore(indexOffset, index)
                    sstore(Quartz$StorageOffsetForKey(keysArrayOffset, index), key)
                    sstore(dictionaryOffset, index)
                }
            ret := offsetForKey
        }"
        .to_string()
    }

    pub fn storage_array_offset_function() -> String {
        "function Quartz$StorageArrayOffset(arrayOffset, index) -> ret {
            let arraySize := sload(arrayOffset)

            switch eq(arraySize, index)
            case 0 {
                if Quartz$IsInvalidSubscriptExpression(index, arraySize) { revert(0, 0) }
            }
            default {
                sstore(arrayOffset, Quartz$Add(arraySize, 1))
            }
            ret := Quartz$StorageOffsetForKey(arrayOffset, index)
        }"
        .to_string()
    }

    pub fn is_invalid_subscript_expression_function() -> String {
        "function Quartz$IsInvalidSubscriptExpression(index, arraySize) -> ret {
            ret := or(iszero(arraySize), or(lt(index, 0), gt(index, Quartz$Sub(arraySize, 1))))
        }"
        .to_string()
    }

    pub fn return_32_bytes_function() -> String {
        "function Quartz$Return32Bytes(v) {
            mstore(0, v)
            return(0, 0x20)
        }"
        .to_string()
    }

    pub fn is_caller_protection_in_dictionary_function() -> String {
        "function Quartz$IsCallerProtectionInDictionary(dictionaryOffset) -> ret {
            let size := sload(dictionaryOffset)
            let arrayOffset := Quartz$StorageDictionaryKeysArrayOffset(dictionaryOffset)
            let found := 0
            let _caller := caller()
            for { let i := 0 } and(lt(i, size), iszero(found)) { i := add(i, i) } {
                let key := sload(Quartz$StorageOffsetForKey(arrayOffset, i))
                if eq(sload(Quartz$StorageOffsetForKey(dictionaryOffset, key)), _caller) {
                    found := 1
                }
            }
            ret := found
        }"
        .to_string()
    }

    pub fn is_caller_protection_in_array_function() -> String {
        "function Quartz$IsCallerProtectionInArray(arrayOffset) -> ret {
            let size := sload(arrayOffset)
            let found := 0
            let _caller := caller()
            for { let i := 0 } and(lt(i, size), iszero(found)) { i := add(i, 1) } {
                if eq(sload(Quartz$StorageOffsetForKey(arrayOffset, i)), _caller) {
                found := 1
                }
            }
            ret := found
        }"
        .to_string()
    }

    pub fn is_valid_caller_protection_function() -> String {
        "function Quartz$IsValidCallerProtection(_address) -> ret {
            ret := eq(_address, caller())
         }"
        .to_string()
    }

    pub fn check_no_value_function() -> String {
        "function Quartz$CheckNoValue(_value) {
            if iszero(iszero(_value)) {
                Quartz$FatalError()
            }
        }"
        .to_string()
    }

    pub fn allocate_memory_function() -> String {
        "function Quartz$AllocateMemory(size) -> ret {
            ret := mload(0x40)
            mstore(0x40, add(ret, size))
        }"
        .to_string()
    }

    pub fn compute_offset_function() -> String {
        "function Quartz$ComputeOffset(base, offset, mem) -> ret {
            switch iszero(mem)
            case 0 {
                ret := add(base, mul(offset, 32))
            }
            default {
                ret := add(base, offset)
            }
        }"
        .to_string()
    }

    pub fn load_function() -> String {
        "function Quartz$Load(ptr, mem) -> ret {
            switch iszero(mem)
                case 0 {
                    ret := mload(ptr)
                }
                default {
                    ret := sload(ptr)
                }
        }"
        .to_string()
    }

    pub fn decode_address_function() -> String {
        format!("function Quartz$DecodeAsAddress(offset) -> ret {{ \n ret := Quartz$DecodeAsUInt(offset) \n }}")
    }

    pub fn decode_uint_function() -> String {
        format!("function Quartz$DecodeAsUInt(offset) -> ret {{ \n ret := calldataload(add(4, mul(offset, 0x20))) \n }}")
    }

    pub fn selector_function() -> String {
        format!("function Quartz$Selector() -> ret {{ \n ret := div(calldataload(0), 0x100000000000000000000000000000000000000000000000000000000) \n }}")
    }

    pub fn store_function() -> String {
        format!("function Quartz$Store(ptr, val, mem) {{ \n switch iszero(mem) \n case 0 {{ \n mstore(ptr, val) \n }} \n default {{ \n sstore(ptr, val) \n }} \n  }}")
    }
}

impl fmt::Display for SolidityRuntimeFunction {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        write!(f, "{:?}", self)
    }
}

pub struct SolidityFunctionSelector {
    pub fallback: Option<SpecialDeclaration>,
    pub functions: Vec<SolidityFunction>,
    pub enclosing: Identifier,
    pub environment: Environment,
}

impl SolidityFunctionSelector {
    pub fn generate(&self) -> String {
        let state = Expression::Identifier(Identifier {
            token: format!("quartzState${}", self.enclosing.token.clone()),
            enclosing_type: None,
            line_info: Default::default(),
        });

        let state = Expression::BinaryExpression(BinaryExpression {
            lhs_expression: Box::new(Expression::SelfExpression),
            rhs_expression: Box::new(state),
            op: BinOp::Dot,
            line_info: Default::default(),
        });

        let mut function_context = FunctionContext {
            environment: self.environment.clone(),
            scope_context: Default::default(),
            InStructFunction: false,
            block_stack: vec![YulBlock { statements: vec![] }],
            enclosing_type: self.enclosing.token.clone(),
            counter: 0,
        };

        let state = SolidityExpression {
            expression: state,
            IsLValue: false,
        }
        .generate(&mut function_context);

        let protection = YulStatement::Inline(format!(
            "if eq({state}, 10000) {{ revert(0, 0)}}",
            state = state
        ));

        let selector = SolidityRuntimeFunction::selector();
        let cases = format!("");
        let mut hasher = Keccak256::digest(b"helo");
        let cases: Vec<String> = self
            .functions
            .clone()
            .into_iter()
            .map(|f| {
                let signature = f.mangled_signature();
                let second_sig = signature.clone();
                let hash = Keccak256::digest(signature.as_bytes());
                let mut hex = encode(hash);
                hex.truncate(8);
                let hash = format!("0x{hash}", hash = hex);
                let caller_protection_check = SolidityCallerProtectionCheck {
                    caller_protections: f.caller_protections.clone(),
                    revert: false,
                    variable: format!("_quartzCallerCheck"),
                }
                .generate(&self.enclosing.token.clone(), self.environment.clone());

                let value_check = if !f.declaration.is_payable() {
                    format!(
                        "{check}({value}) \n",
                        check = SolidityRuntimeFunction::CheckNoValue.mangle_runtime(),
                        value = SolidityRuntimeFunction::call_value()
                    )
                } else {
                    format!("")
                };

                let wrapper = if f.has_any_caller() {
                    format!("")
                } else {
                    SolidityWrapperFunction::get_prefix_hard()
                };

                let parameters = f.declaration.head.parameters.clone();
                let parameters: Vec<SolidityIRType> = parameters
                    .into_iter()
                    .map(|p| SolidityIRType::map_to_solidity_type(p.type_assignment))
                    .collect();
                let parameters: Vec<String> = parameters
                    .into_iter()
                    .enumerate()
                    .map(|(k, v)| match v {
                        SolidityIRType::uint256 => {
                            SolidityRuntimeFunction::decode_as_uint(k as u64)
                        }
                        SolidityIRType::address => {
                            SolidityRuntimeFunction::decode_as_address(k as u64)
                        }
                        SolidityIRType::bytes32 => {
                            SolidityRuntimeFunction::decode_as_uint(k as u64)
                        }
                    })
                    .collect();
                let parameters = parameters.join(", ");
                let mut call = format!(
                    "{wrapper}{name}({args})",
                    wrapper = wrapper,
                    name = f.clone().declaration.mangledIdentifier.unwrap_or_default(),
                    args = parameters
                );

                if f.declaration.get_result_type().is_some() {
                    let result = f.declaration.get_result_type().clone();
                    let result = result.unwrap();
                    if SolidityIRType::if_maps_to_solidity_type(result.clone()) {
                        let result = SolidityIRType::map_to_solidity_type(result);
                        call = SolidityRuntimeFunction::return_32_bytes(call);
                    }
                }

                let case_body = format!(
                    "{caller_protection} \n {value_check}{call}",
                    caller_protection = caller_protection_check,
                    value_check = value_check,
                    call = call
                );
                format!("case {hash} {{ {body} }}", hash = hash, body = case_body)
            })
            .collect();

        let cases = cases.join("\n");

        let fallback = if self.fallback.is_some() {
            panic!("User supplied Fallback not currently supported")
        } else {
            format!("revert(0, 0)")
        };

        format!(
            "{protection} \n \
             switch {selector} \n\
             {cases} \n\
             default {{ \n \
             {fallback} \n\
             }}",
            protection = protection,
            selector = selector,
            cases = cases,
            fallback = fallback
        )
    }
}

pub struct SolidityBinaryExpression {
    pub expression: BinaryExpression,
    pub IsLValue: bool,
}

impl SolidityBinaryExpression {
    pub fn generate(&self, function_context: &mut FunctionContext) -> YulExpression {
        if let BinOp::Dot = self.expression.op {
            if let Expression::FunctionCall(f) = *self.expression.rhs_expression.clone() {
                return SolidityFunctionCall { function_call: f }.generate(function_context);
            }

            return SolidityPropertyAccess {
                lhs: *self.expression.lhs_expression.clone(),
                rhs: *self.expression.rhs_expression.clone(),
                IsLeft: self.IsLValue,
            }
            .generate(function_context);
        }

        if let BinOp::Equal = self.expression.op {
            let lhs = self.expression.lhs_expression.clone();
            let rhs = self.expression.rhs_expression.clone();
            return SolidityAssignment {
                lhs: *lhs,
                rhs: *rhs,
            }
            .generate(function_context);
        }

        let lhs = self.expression.lhs_expression.clone();
        let rhs = self.expression.rhs_expression.clone();
        let lhs = SolidityExpression {
            expression: *lhs,
            IsLValue: self.IsLValue,
        }
        .generate(function_context);
        let rhs = SolidityExpression {
            expression: *rhs,
            IsLValue: self.IsLValue,
        }
        .generate(function_context);

        match self.expression.op {
            BinOp::Plus => SolidityRuntimeFunction::add(lhs, rhs),
            BinOp::OverflowingPlus => YulExpression::FunctionCall(YulFunctionCall {
                name: "add".to_string(),
                arguments: vec![lhs, rhs],
            }),
            BinOp::Times => SolidityRuntimeFunction::mul(lhs, rhs),
            BinOp::Divide => SolidityRuntimeFunction::div(lhs, rhs),
            BinOp::Minus => SolidityRuntimeFunction::sub(lhs, rhs),
            BinOp::OverflowingMinus => YulExpression::FunctionCall(YulFunctionCall {
                name: "sub".to_string(),
                arguments: vec![lhs, rhs],
            }),
            BinOp::OverflowingTimes => YulExpression::FunctionCall(YulFunctionCall {
                name: "mul".to_string(),
                arguments: vec![lhs, rhs],
            }),
            BinOp::Power => SolidityRuntimeFunction::power(lhs, rhs),
            BinOp::Percent => YulExpression::FunctionCall(YulFunctionCall {
                name: "mod".to_string(),
                arguments: vec![lhs, rhs],
            }),
            BinOp::DoubleEqual => YulExpression::FunctionCall(YulFunctionCall {
                name: "eq".to_string(),
                arguments: vec![lhs, rhs],
            }),
            BinOp::NotEqual => YulExpression::FunctionCall(YulFunctionCall {
                name: "iszero".to_string(),
                arguments: vec![YulExpression::FunctionCall(YulFunctionCall {
                    name: "eq".to_string(),
                    arguments: vec![lhs, rhs],
                })],
            }),
            BinOp::LessThan => YulExpression::FunctionCall(YulFunctionCall {
                name: "lt".to_string(),
                arguments: vec![lhs, rhs],
            }),
            BinOp::LessThanOrEqual => panic!("Not Supported Op Token"),
            BinOp::GreaterThan => YulExpression::FunctionCall(YulFunctionCall {
                name: "gt".to_string(),
                arguments: vec![lhs, rhs],
            }),
            BinOp::GreaterThanOrEqual => panic!("Not Supported Op Token"),
            BinOp::Or => YulExpression::FunctionCall(YulFunctionCall {
                name: "or".to_string(),
                arguments: vec![lhs, rhs],
            }),
            BinOp::And => YulExpression::FunctionCall(YulFunctionCall {
                name: "and".to_string(),
                arguments: vec![lhs, rhs],
            }),
            BinOp::Dot => panic!("Unexpected Operator"),
            BinOp::Equal => panic!("Unexpected Operator"),
            BinOp::PlusEqual => panic!("Unexpected Operator"),
            BinOp::MinusEqual => panic!("Unexpected Operator"),
            BinOp::TimesEqual => panic!("Unexpected Operator"),
            BinOp::DivideEqual => panic!("Unexpected Operator"),
            BinOp::Implies => panic!("Unexpected Operator"),
        }
    }
}

pub struct SolidityLiteral {
    pub literal: Literal,
}

impl SolidityLiteral {
    pub fn generate(&self) -> YulLiteral {
        match self.literal.clone() {
            Literal::BooleanLiteral(b) => YulLiteral::Bool(b),
            Literal::AddressLiteral(a) => YulLiteral::Hex(a),
            Literal::StringLiteral(s) => YulLiteral::String(s),
            Literal::IntLiteral(i) => YulLiteral::Num(i),
            Literal::FloatLiteral(_) => panic!("Float Literal Currently Unsupported"),
        }
    }
}

pub struct SolidityVariableDeclaration {
    pub declaration: VariableDeclaration,
}

impl SolidityVariableDeclaration {
    pub fn generate(&self, function_context: &FunctionContext) -> YulExpression {
        let allocate = SolidityRuntimeFunction::allocate_memory(
            function_context
                .environment
                .type_size(self.declaration.variable_type.clone())
                * 32,
        );
        YulExpression::VariableDeclaration(YulVariableDeclaration {
            declaration: mangle(self.declaration.identifier.token.clone()),
            declaration_type: YulType::Any,
            expression: Option::from(Box::from(allocate)),
        })
    }
}

#[derive(Debug, Clone)]
pub struct YulAssignment {
    pub identifiers: Vec<String>,
    pub expression: Box<YulExpression>,
}

impl fmt::Display for YulAssignment {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let lhs: Vec<String> = self
            .identifiers
            .clone()
            .into_iter()
            .map(|i| format!("{}", i))
            .collect();
        let lhs = lhs.join(", ");
        write!(
            f,
            "{idents} := {expression}",
            idents = lhs,
            expression = self.expression
        )
    }
}

#[derive(Debug, Clone)]
pub struct YulBlock {
    pub statements: Vec<YulStatement>,
}

impl fmt::Display for YulBlock {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let statements: Vec<String> = self
            .statements
            .clone()
            .into_iter()
            .map(|s| format!("{}", s))
            .collect();
        let statements = statements.join("\n");

        write!(f, "{{ \n {statements} \n }}", statements = statements)
    }
}

#[derive(Debug, Clone)]
pub enum YulExpression {
    FunctionCall(YulFunctionCall),
    Identifier(String),
    Literal(YulLiteral),
    Catchable(Box<YulExpression>, Box<YulExpression>),
    VariableDeclaration(YulVariableDeclaration),
    Assignment(YulAssignment),
    Noop,
    Inline(String),
}

impl fmt::Display for YulExpression {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            YulExpression::FunctionCall(fc) => write!(f, "{fc}", fc = fc),
            YulExpression::Identifier(s) => write!(f, "{s}", s = s),
            YulExpression::Literal(l) => write!(f, "{l}", l = l),
            YulExpression::Catchable(v, _) => write!(f, "{v}", v = v),
            YulExpression::VariableDeclaration(v) => write!(f, "{v}", v = v),
            YulExpression::Assignment(a) => write!(f, "{a}", a = a),
            YulExpression::Noop => write!(f, ""),
            YulExpression::Inline(i) => write!(f, "{i}", i = i),
        }
    }
}

#[derive(Debug, Clone)]
pub struct YulFunctionDefinition {
    pub identifier: String,
    pub arguments: Vec<(String, YulType)>,
    pub returns: Vec<(String, YulType)>,
    pub body: YulBlock,
}

impl fmt::Display for YulFunctionDefinition {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let args = self.arguments.clone();
        let args: Vec<String> = args
            .into_iter()
            .map(|(a, b)| format!("{a}: {b}", a = a, b = b))
            .collect();
        let args = args.join(", ");

        let ret = if !self.returns.is_empty() {
            let p = self.arguments.clone();
            let p: Vec<String> = p
                .into_iter()
                .map(|(a, b)| format!("{a}: {b}", a = a, b = b))
                .collect();
            let p = p.join(", ");
            format!("-> {p}", p = p)
        } else {
            "".to_string()
        };

        write!(
            f,
            "{identifier}({arg}) {ret} {body}",
            identifier = self.identifier,
            arg = args,
            ret = ret,
            body = self.body
        )
    }
}
#[derive(Debug, Clone)]
pub struct YulFunctionCall {
    pub name: String,
    pub arguments: Vec<YulExpression>,
}

impl fmt::Display for YulFunctionCall {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let args = self.arguments.clone();
        let args: Vec<String> = args.into_iter().map(|a| format!("{}", a)).collect();
        let args = args.join(", ");
        write!(f, "{name}({args})", name = self.name, args = args)
    }
}

#[derive(Debug, Clone)]
pub enum YulStatement {
    Block(YulBlock),
    FunctionDefinition(YulFunctionDefinition),
    If(YulIf),
    Expression(YulExpression),
    Switch(YulSwitch),
    For(YulForLoop),
    Break,
    Continue,
    Noop,
    Inline(String),
}

impl fmt::Display for YulStatement {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            YulStatement::Block(b) => write!(f, "{b}", b = b),
            YulStatement::FunctionDefinition(e) => write!(f, "{e}", e = e),
            YulStatement::If(e) => write!(f, "{e}", e = e),
            YulStatement::Expression(e) => write!(f, "{e}", e = e),
            YulStatement::Switch(s) => write!(f, "{s}", s = s),
            YulStatement::For(e) => write!(f, "{e}", e = e),
            YulStatement::Break => write!(f, "break"),
            YulStatement::Continue => write!(f, "continue"),
            YulStatement::Noop => write!(f, ""),
            YulStatement::Inline(i) => write!(f, "{i}", i = i),
        }
    }
}

#[derive(Debug, Clone)]
pub struct YulIf {
    pub expression: YulExpression,
    pub block: YulBlock,
}

impl fmt::Display for YulIf {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(
            f,
            "if {expression} {block}",
            expression = self.expression,
            block = self.block,
        )
    }
}

#[derive(Debug, Clone)]
pub struct YulSwitch {
    pub expression: YulExpression,
    pub cases: Vec<(YulLiteral, YulBlock)>,
    pub default: Option<YulBlock>,
}

impl fmt::Display for YulSwitch {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let cases: Vec<String> = self
            .cases
            .clone()
            .into_iter()
            .map(|(c, b)| format!("case {c} {b}", c = c, b = b))
            .collect();
        let cases = cases.join("\n");

        let default = if self.default.is_some() {
            format!("\n default {d}", d = self.default.clone().unwrap())
        } else {
            format!("")
        };

        write!(
            f,
            "switch {expression} \n {cases}{default}",
            expression = self.expression,
            cases = cases,
            default = default
        )
    }
}

#[derive(Debug, Clone)]
pub struct YulForLoop {
    pub initialise: YulBlock,
    pub condition: YulExpression,
    pub step: YulBlock,
    pub body: YulBlock,
}

impl fmt::Display for YulForLoop {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(
            f,
            "for {initialise} {condition} {step} {body}",
            initialise = self.initialise,
            condition = self.condition,
            step = self.step,
            body = self.body,
        )
    }
}

#[derive(Debug, Clone)]
pub enum YulLiteral {
    Num(u64),
    String(String),
    Bool(bool),
    Decimal(u64, u64),
    Hex(String),
}

impl fmt::Display for YulLiteral {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            YulLiteral::Num(n) => write!(f, "{n}", n = n),
            YulLiteral::String(s) => write!(f, "\"{n}\"", n = s),
            YulLiteral::Bool(b) => {
                let value = if *b { 1 } else { 0 };
                write!(f, "{n}", n = value)
            }
            YulLiteral::Decimal(_, _) => panic!("Float currently not supported"),
            YulLiteral::Hex(n) => write!(f, "{n}", n = n),
        }
    }
}

#[derive(Debug, Clone)]
pub struct YulVariableDeclaration {
    pub declaration: String,
    pub declaration_type: YulType,
    pub expression: Option<Box<YulExpression>>,
}

impl fmt::Display for YulVariableDeclaration {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let declarations = if let YulType::Any = self.declaration_type {
            format!("{ident}", ident = self.declaration)
        } else {
            format!(
                "{ident}: {var_type}",
                ident = self.declaration,
                var_type = self.declaration_type
            )
        };
        if self.expression.is_none() {
            write!(f, "let {declarations}", declarations = declarations);
        }
        let expression = self.expression.clone();
        let expression = expression.unwrap();
        write!(
            f,
            "let {declarations} := {expression}",
            declarations = declarations,
            expression = *expression
        )
    }
}

#[derive(Debug, Clone)]
pub enum YulType {
    Bool,
    U8,
    S8,
    U32,
    S32,
    U64,
    S64,
    U128,
    S128,
    U256,
    S256,
    Any,
}

impl fmt::Display for YulType {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            YulType::Bool => write!(f, "bool"),
            YulType::U8 => write!(f, "u8"),
            YulType::S8 => write!(f, "s8"),
            YulType::U32 => write!(f, "u32"),
            YulType::S32 => write!(f, "s32"),
            YulType::U64 => write!(f, "u64"),
            YulType::S64 => write!(f, "s64"),
            YulType::U128 => write!(f, "u128"),
            YulType::S128 => write!(f, "s128"),
            YulType::U256 => write!(f, "u256"),
            YulType::S256 => write!(f, "s256"),
            YulType::Any => write!(f, "any"),
        }
    }
}
