use super::context::*;
use super::environment::*;
use super::visitor::*;
use super::AST::*;
use std::env::var;

pub struct SemanticAnalysis {}

impl Visitor for SemanticAnalysis {
    fn start_contract_declaration(
        &mut self,
        _t: &mut ContractDeclaration,
        _ctx: &mut Context,
    ) -> VResult {
        if !_ctx
            .environment
            .has_public_initialiser(&_t.identifier.token)
        {
            println!("No Public Initialiser");
            return Err(Box::from("".to_owned()));
        }

        if _ctx.environment.is_conflicting(&_t.identifier) {
            let i = _t.identifier.token.clone();
            let err = format!("Conflicting Declarations for {i}", i = i);
            println!("{}", err);
            return Err(Box::from("".to_owned()));
        }

        if is_conformance_repeated(_t.conformances.clone()) {
            println!("Conformances are repeated");
            return Err(Box::from("".to_owned()));
        }

        if _ctx
            .environment
            .conflicting_trait_signatures(&_t.identifier.token)
        {
            println!("Conflicting Traits");
            return Err(Box::from("".to_owned()));
        }
        Ok(())
    }

    fn start_contract_behaviour_declaration(
        &mut self,
        _t: &mut ContractBehaviourDeclaration,
        _ctx: &mut Context,
    ) -> VResult {
        if !_ctx.environment.is_contract_declared(&_t.identifier.token) {
            println!("No Contract Declared");
            return Err(Box::from("".to_owned()));
        }

        let statefull = _ctx.environment.is_contract_stateful(&_t.identifier.token);
        let states = _t.states.clone();
        if statefull != (!states.is_empty()) {
            println!("Contract Behaviour Declaration has mismatched states");
            return Err(Box::from("".to_owned()));
        }

        if !_ctx.is_trait_declaration_context() {
            let members = _t.members.clone();
            for member in members {
                match member {
                    ContractBehaviourMember::FunctionSignatureDeclaration(_) => {
                        println!("Signature Declaration in Contract");
                        return Err(Box::from("".to_owned()));
                    }
                    ContractBehaviourMember::SpecialSignatureDeclaration(_) => {
                        println!("Signature Declaration in Contract");
                        return Err(Box::from("".to_owned()));
                    }
                    _ => continue,
                }
            }
        }

        //TODO Update the context to be contractBehaviourContext
        Ok(())
    }

    fn start_struct_declaration(
        &mut self,
        _t: &mut StructDeclaration,
        _ctx: &mut Context,
    ) -> VResult {
        if _ctx.environment.is_conflicting(&_t.identifier) {
            let i = _t.identifier.token.clone();
            let err = format!("Conflicting Declarations for {i}", i = i);
            println!("{}", err);
            return Err(Box::from("".to_owned()));
        }

        if _ctx.environment.is_recursive_struct(&_t.identifier.token) {
            println!("Recusive Struct Definition");
            return Err(Box::from("".to_owned()));
        }

        if is_conformance_repeated(_t.conformances.clone()) {
            println!("Conformances are repeated");
            return Err(Box::from("".to_owned()));
        }

        if _ctx
            .environment
            .conflicting_trait_signatures(&_t.identifier.token)
        {
            println!("Conflicting Traits");
            return Err(Box::from("".to_owned()));
        }
        Ok(())
    }

    fn start_asset_declaration(
        &mut self,
        _t: &mut AssetDeclaration,
        _ctx: &mut Context,
    ) -> VResult {
        if _ctx.environment.is_conflicting(&_t.identifier) {
            let i = _t.identifier.token.clone();
            let err = format!("Conflicting Declarations for {i}", i = i);
            println!("{}", err);
            return Err(Box::from("".to_owned()));
        }

        Ok(())
    }

    fn start_trait_declaration(
        &mut self,
        _t: &mut TraitDeclaration,
        _ctx: &mut Context,
    ) -> VResult {
        Ok(())
    }

    fn start_variable_declaration(
        &mut self,
        _t: &mut VariableDeclaration,
        _ctx: &mut Context,
    ) -> VResult {
        let type_declared = match &_t.variable_type {
            Type::UserDefinedType(t) => _ctx.environment.is_type_declared(&t.token.clone()),
            _ => true,
        };

        if !type_declared {
            println!("Type not Declared");
            return Err(Box::from("".to_owned()));
        }

        if _ctx.in_function_or_special() {
            if _ctx.has_scope_context() {
                let scope_context = _ctx.ScopeContext.as_mut().unwrap();

                let redeclaration = scope_context.declaration(_t.identifier.token.clone());
                if redeclaration.is_some() {
                    println!("Redeclaration of identifier");
                    return Err(Box::from("".to_owned()));
                }
                scope_context.local_variables.push(_t.clone());
            }
        } else if _ctx.enclosing_type_identifier().is_some() {
            let identifier = &_ctx.enclosing_type_identifier().unwrap().token.clone();
            if _ctx
                .environment
                .conflicting_property_declaration(&_t.identifier, identifier)
            {
                println!("Conflicting property declarations");
                return Err(Box::from("".to_owned()));
            }
        }

        Ok(())
    }

    fn start_function_declaration(
        &mut self,
        _t: &mut FunctionDeclaration,
        _ctx: &mut Context,
    ) -> VResult {
        if _ctx.enclosing_type_identifier().is_some() {
            let identifier = &_ctx.enclosing_type_identifier().unwrap().token.clone();
            if _ctx
                .environment
                .is_conflicting_function_declaration(&_t, identifier)
            {
                println!("Conflicting Function Declarations");
                return Err(Box::from("".to_owned()));
            }

            if identifier == "Libra" || identifier == "Wei" {
                return Ok(());
            }
        }

        let parameters: Vec<String> = _t
            .head
            .parameters
            .clone()
            .into_iter()
            .map(|p| p.identifier.token)
            .collect();
        let duplicates =
            (1..parameters.len()).any(|i| parameters[i..].contains(&parameters[i - 1]));

        if duplicates {
            println!("Function has duplicate parameters");
            return Err(Box::from("".to_owned()));
        }

        let payable_parameters = _t.head.parameters.clone();
        let remaining_parameters: Vec<Parameter> = payable_parameters
            .into_iter()
            .filter(|p| p.is_payable())
            .collect();
        if _t.is_payable() {
            if remaining_parameters.is_empty() {
                println!("Payable Function does not have payable paramter");
                return Err(Box::from("".to_owned()));
            } else if remaining_parameters.len() > 1 {
                println!("Payable parameter is ambiguous");
                return Err(Box::from("".to_owned()));
            }
        } else {
            if !remaining_parameters.is_empty() {
                let params = remaining_parameters.clone();
                println!("{:?}", params);
                println!("Function not marked payable but has payable parameter");
                return Err(Box::from("".to_owned()));
            }
        }

        if _t.is_public() {
            let parameters: Vec<Parameter> = _t
                .head
                .parameters
                .clone()
                .into_iter()
                .filter(|p| p.is_dynamic() && !p.is_payable())
                .collect();
            if !parameters.is_empty() {
                println!("Public Function has dynamic parameters");
                return Err(Box::from("".to_owned()));
            }
        }

        let return_type = &_t.head.result_type;
        if return_type.is_some() {
            match return_type.as_ref().unwrap() {
                Type::UserDefinedType(_) => {
                    println!("Not allowed to return struct in function");
                    return Err(Box::from("".to_owned()));
                }
                _ => (),
            }
        }

        let statements = _t.body.clone();
        let mut return_statements = Vec::new();
        let mut become_statements = Vec::new();

        let remaining = statements
            .into_iter()
            .skip_while(|s| !isReturnOrBecomeStatement(s.clone()));

        for statement in _t.body.clone() {
            match statement {
                Statement::ReturnStatement(ret) => return_statements.push(ret),
                Statement::BecomeStatement(bec) => become_statements.push(bec),
                _ => continue,
            }
        }

        let remainingAfterEnd = remaining.filter(|s| !isReturnOrBecomeStatement(s.clone()));
        if remainingAfterEnd.count() > 0 {
            println!("Statements after Return");
            return Err(Box::from("".to_owned()));
        }

        if _t.head.result_type.is_some() {
            if return_statements.is_empty() {
                let err = _t.head.identifier.token.clone();
                let err = format!("Missing Return in Function {}", err);
                println!("{}", err);
                return Err(Box::from("".to_owned()));
            }
        }

        if return_statements.len() > 1 {
            println!("Multiple Returns");
            return Err(Box::from("".to_owned()));
        }

        if become_statements.len() > 1 {
            println!("Multiple Become Statements");
            return Err(Box::from("".to_owned()));
        }

        for become_statement in &become_statements {
            for return_statement in &return_statements {
                if return_statement.line_info.line > become_statement.line_info.line {
                    println!("Return statement after Become");
                    return Err(Box::from("".to_owned()));
                }
            }
        }

        Ok(())
    }

    fn finish_function_declaration(
        &mut self,
        _t: &mut FunctionDeclaration,
        _ctx: &mut Context,
    ) -> VResult {
        _t.ScopeContext = _ctx.ScopeContext.clone();
        Ok(())
    }

    fn start_special_declaration(
        &mut self,
        _t: &mut SpecialDeclaration,
        _ctx: &mut Context,
    ) -> VResult {
        if _t.is_fallback() {
            if _t.head.has_parameters() {
                println!("fallback declared with arguments");
                return Err(Box::from("".to_owned()));
            }

            //TODO check body only has simple statements bit long
        }

        Ok(())
    }

    fn start_identifier(&mut self, _t: &mut Identifier, _ctx: &mut Context) -> VResult {
        let token = _t.token.clone();
        if token.contains('@') {
            println!("Invalid @ character used in Identifier");
            return Err(Box::from("".to_owned()));
        }

        if _ctx.IsPropertyDefaultAssignment
            && !_ctx.environment.is_struct_declared(&_t.token)
            && !_ctx.environment.is_asset_declared(&_t.token)
        {
            if _ctx.enclosing_type_identifier().is_some() {
                if _ctx.environment.is_property_defined(
                    _t.token.clone(),
                    &_ctx.enclosing_type_identifier().unwrap().token,
                ) {
                    println!("State property used withing property initiliaser");
                    return Err(Box::from("".to_owned()));
                } else {
                    println!("Use of undeclared identifier");
                    return Err(Box::from("".to_owned()));
                }
            }
        }

        if _ctx.IsFunctionCallContext || _ctx.IsFunctionCallArgumentLabel {
        } else if _ctx.in_function_or_special() && !_ctx.InBecome && !_ctx.InEmit {
            let is_l_value = _ctx.IsLValue;
            if _t.enclosing_type.is_none() {
                let scope = _ctx.ScopeContext.is_some();
                if scope {
                    let variable_declaration =
                        _ctx.scope_context().unwrap().declaration(_t.token.clone());
                    if variable_declaration.is_some() {
                        let variable_declaration = _ctx
                            .scope_context()
                            .unwrap()
                            .declaration(_t.token.clone())
                            .unwrap();
                        if variable_declaration.is_constant()
                            && !variable_declaration.variable_type.is_inout_type()
                            && is_l_value
                            && _ctx.InSubscript
                        {
                            println!("Reassignment to constant");
                        }
                    } else if !_ctx.environment.is_enum_declared(&_t.token) {
                        let enclosing = _ctx.enclosing_type_identifier();
                        let enclosing = enclosing.unwrap();
                        _t.enclosing_type = Option::from(enclosing.token);
                    } else if !_ctx.IsEnclosing {
                        println!("Invalid Reference");
                    }
                }
            }

            if _t.enclosing_type.is_some()
                && _t.enclosing_type.as_ref().unwrap() != "Quartz$ErrorType"
            {
                let enclosing = _t.enclosing_type.clone();
                let enclosing = enclosing.unwrap();
                if enclosing == format!("Libra") || enclosing == format!("Wei") {
                    return Ok(());
                }
                if !_ctx
                    .environment
                    .is_property_defined(_t.token.clone(), &_t.enclosing_type.as_ref().unwrap())
                {
                    let identifier = _t.token.clone();
                    let error = format!("Use of Undeclared Identifier {ident}", ident = identifier);
                    println!("{}", error);
                    return Err(Box::from("".to_owned()));
                //TODO add add used undefined variable to env
                } else if is_l_value && !_ctx.InSubscript {
                    if _ctx.environment.is_property_constant(
                        _t.token.clone(),
                        &_t.enclosing_type.as_ref().unwrap(),
                    ) {}

                    if _ctx.is_special_declaration_context() {}

                    if _ctx.is_function_declaration_context() {
                        let mutated = _ctx
                            .FunctionDeclarationContext
                            .as_ref()
                            .unwrap()
                            .mutates()
                            .clone();
                        let mutated: Vec<String> = mutated.into_iter().map(|i| i.token).collect();
                        if !mutated.contains(&_t.token) {
                            let i = _t.token.clone();
                            let i = format!(
                                "Mutating {i} identifier that is declared non mutating in {f}",
                                i = i,
                                f = enclosing
                            );
                            println!("{}", i);
                            println!(
                                "{}",
                                _ctx.FunctionDeclarationContext
                                    .as_ref()
                                    .unwrap()
                                    .declaration
                                    .head
                                    .identifier
                                    .token
                                    .clone()
                            );
                            return Err(Box::from("".to_owned()));
                        }
                    }
                }
            }
        } else if _ctx.InBecome {
        }

        Ok(())
    }

    fn start_range_expression(&mut self, _t: &mut RangeExpression, _ctx: &mut Context) -> VResult {
        let start = _t.start_expression.clone();
        let end = _t.end_expression.clone();

        if is_literal(start.as_ref()) && is_literal(end.as_ref()) {
        } else {
            println!("Invalid Range Declaration");
            return Err(Box::from("".to_owned()));
        }

        Ok(())
    }

    fn start_caller_protection(
        &mut self,
        _t: &mut CallerProtection,
        _ctx: &mut Context,
    ) -> VResult {
        if _ctx.enclosing_type_identifier().is_some() {
            if !_t.is_any()
                && !_ctx.environment.contains_caller_protection(
                    _t,
                    &_ctx.enclosing_type_identifier().unwrap().token,
                )
            {
                println!("Undeclared Caller Protection");
                return Err(Box::from("".to_owned()));
            }
        }

        Ok(())
    }

    fn start_conformance(&mut self, _t: &mut Conformance, _ctx: &mut Context) -> VResult {
        if !_ctx.environment.is_trait_declared(&_t.name()) {
            println!("Undeclared Trait Used");
            return Err(Box::from("".to_owned()));
        }
        Ok(())
    }

    fn start_attempt_expression(
        &mut self,
        _t: &mut AttemptExpression,
        _ctx: &mut Context,
    ) -> VResult {
        if _t.is_soft() {}

        Ok(())
    }

    fn start_binary_expression(
        &mut self,
        _t: &mut BinaryExpression,
        _ctx: &mut Context,
    ) -> VResult {
        match _t.op {
            BinOp::Dot => {}
            BinOp::Equal => {
                let rhs = _t.rhs_expression.clone();
                match *rhs {
                    Expression::ExternalCall(_) => {}
                    _ => {}
                }
            }
            _ => {}
        }
        Ok(())
    }

    fn start_function_call(&mut self, _t: &mut FunctionCall, _ctx: &mut Context) -> VResult {
        Ok(())
    }

    fn finish_if_statement(&mut self, _t: &mut IfStatement, _ctx: &mut Context) -> VResult {
        let condition = _t.condition.clone();

        match condition {
            Expression::BinaryExpression(b) => {
                let lhs = *b.lhs_expression.clone();

                if let Expression::VariableDeclaration(v) = lhs {
                    if !v.is_constant() {
                        println!("Invalid Condition Type in If statement");
                        return Err(Box::from("".to_owned()));
                    }
                }
            }
            _ => {}
        }

        let expression_type = Type::Int;
        //TODO expression type

        if expression_type.is_bool_type() {
            println!("Invalid Condition Type in If statement");
            return Err(Box::from("".to_owned()));
        }
        Ok(())
    }

    fn finish_statement(&mut self, _t: &mut Statement, _ctx: &mut Context) -> VResult {
        //TODO make recevier call trail empty
        Ok(())
    }
}

fn is_conformance_repeated(conformances: Vec<Conformance>) -> bool {
    let slice: Vec<String> = conformances
        .into_iter()
        .map(|c| c.identifier.token)
        .collect();
    return (1..slice.len()).any(|i| slice[i..].contains(&slice[i - 1]));
}
