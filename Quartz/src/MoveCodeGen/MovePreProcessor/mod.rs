
use crate::context::*;
use crate::environment::*;
use crate::visitor::Visitor;
use crate::MoveCodeGen::{FunctionContext, MoveExpression, MoveIRBlock, MoveStatement};
use crate::AST::*;
use std::env::var;

pub(crate) struct MovePreProcessor {}

impl Visitor for MovePreProcessor {
    fn start_contract_behaviour_declaration(
        &mut self,
        _t: &mut ContractBehaviourDeclaration,
        _ctx: &mut Context,
    ) -> VResult {
        _t.members = _t
            .members
            .clone()
            .into_iter()
            .flat_map(|f| {
                if let ContractBehaviourMember::FunctionDeclaration(fd) = f {
                    let functions =
                        convert_default_parameter_functions(fd, &_t.identifier.token, _ctx);
                    functions
                        .into_iter()
                        .map(|f| ContractBehaviourMember::FunctionDeclaration(f))
                        .collect()
                } else {
                    vec![f]
                }
            })
            .collect();
        Ok(())
    }

    fn finish_contract_behaviour_declaration(
        &mut self,
        _t: &mut ContractBehaviourDeclaration,
        _ctx: &mut Context,
    ) -> VResult {
        _t.members = _t
            .members
            .clone()
            .into_iter()
            .flat_map(|m| {
                if let ContractBehaviourMember::FunctionDeclaration(f) = m.clone() {
                    let wrapper = generate_contract_wrapper(f.clone(), _t, _ctx);
                    let wrapper = ContractBehaviourMember::FunctionDeclaration(wrapper);
                    let mut function = f.clone();
                    function.head.modifiers.retain(|x| *x != "public");
                    let function = ContractBehaviourMember::FunctionDeclaration(function);
                    return vec![function, wrapper.clone()];
                } else {
                    return vec![m.clone()];
                }
            })
            .collect();
        Ok(())
    }

    fn start_struct_declaration(
        &mut self,
        _t: &mut StructDeclaration,
        _ctx: &mut Context,
    ) -> VResult {
        _t.members = _t
            .members
            .clone()
            .into_iter()
            .flat_map(|f| {
                if let StructMember::FunctionDeclaration(fd) = f {
                    let functions =
                        convert_default_parameter_functions(fd, &_t.identifier.token, _ctx);
                    functions
                        .into_iter()
                        .map(|f| StructMember::FunctionDeclaration(f))
                        .collect()
                } else {
                    vec![f]
                }
            })
            .collect();
        Ok(())
    }

    fn start_asset_declaration(
        &mut self,
        _t: &mut AssetDeclaration,
        _ctx: &mut Context,
    ) -> VResult {
        _t.members = _t
            .members
            .clone()
            .into_iter()
            .flat_map(|f| {
                if let AssetMember::FunctionDeclaration(fd) = f {
                    let functions =
                        convert_default_parameter_functions(fd, &_t.identifier.token, _ctx);
                    functions
                        .into_iter()
                        .map(|f| AssetMember::FunctionDeclaration(f))
                        .collect()
                } else {
                    vec![f]
                }
            })
            .collect();
        Ok(())
    }

    fn start_variable_declaration(
        &mut self,
        _t: &mut VariableDeclaration,
        _ctx: &mut Context,
    ) -> VResult {
        if _ctx.in_function_or_special() {
            if _ctx.scope_context().is_some() {
                let context_ref = _ctx.ScopeContext.as_mut().unwrap();
                context_ref.local_variables.push(_t.clone());
            }

            if _ctx.is_function_declaration_context() {
                let context_ref = _ctx.FunctionDeclarationContext.as_mut().unwrap();
                context_ref.local_variables.push(_t.clone());
            }

            if _ctx.is_special_declaration_context() {
                let context_ref = _ctx.SpecialDeclarationContext.as_mut().unwrap();
                context_ref.local_variables.push(_t.clone());
            }
        }
        Ok(())
    }

    fn start_function_declaration(
        &mut self,
        _t: &mut FunctionDeclaration,
        _ctx: &mut Context,
    ) -> VResult {
        let enclosing_identifier = _ctx
            .enclosing_type_identifier()
            .unwrap_or(Identifier {
                token: "".to_string(),
                enclosing_type: None,
                line_info: Default::default(),
            })
            .token
            .clone();

        let mangled_name = mangle_function_move(
            _t.head.identifier.token.clone(),
            &enclosing_identifier,
            false,
        );
        _t.mangledIdentifier = Some(mangled_name);

        if _t.is_payable() {
            let payable_param = _t.first_payable_param().clone();

            if payable_param.is_none() {
                panic!("lol")
            }
            let mut payable_param = payable_param.unwrap();
            let payable_param_name = payable_param.identifier.token.clone();
            let new_param_type = Type::UserDefinedType(Identifier {
                token: "LibraCoin.T".to_string(),
                enclosing_type: None,
                line_info: Default::default(),
            });
            payable_param.type_assignment = new_param_type;
            let mut ident = payable_param.identifier.clone();
            ident.token = mangle(payable_param_name.clone());
            payable_param.identifier = ident;
            let parameters = _t.head.parameters.clone();
            let parameters = parameters
                .into_iter()
                .map(|p| {
                    if p.identifier.token.clone() == payable_param_name {
                        payable_param.clone()
                    } else {
                        p
                    }
                })
                .collect();

            _t.head.parameters = parameters;

            let lhs = VariableDeclaration {
                declaration_token: None,
                identifier: Identifier {
                    token: "amount".to_string(),
                    enclosing_type: None,
                    line_info: Default::default(),
                },
                variable_type: Type::UserDefinedType(Identifier {
                    token: "Libra".to_string(),
                    enclosing_type: None,
                    line_info: Default::default(),
                }),
                expression: None,
            };

            let lhs_expression = Expression::VariableDeclaration(lhs.clone());

            let lhs = Expression::Identifier(Identifier {
                token: "amount".to_string(),
                enclosing_type: None,
                line_info: Default::default(),
            });


            let rhs = Expression::FunctionCall(FunctionCall {
                identifier: Identifier {
                    token: "Quartz_Self_Create_Libra".to_string(),
                    enclosing_type: None,
                    line_info: Default::default(),
                },
                arguments: vec![FunctionArgument {
                    identifier: None,
                    expression: Expression::Identifier(payable_param.identifier),
                }],
                mangled_identifier: None,
            });
            let assignment = BinaryExpression {
                lhs_expression: Box::new(lhs_expression),
                rhs_expression: Box::new(rhs),
                op: BinOp::Equal,
                line_info: Default::default(),
            };
            _t.body.insert(
                0,
                Statement::Expression(Expression::BinaryExpression(assignment)),
            );
        }

        if _ctx.AssetContext.is_some() {
            if enclosing_identifier != format!("Quartz$Global") {
                let asset_ctx = _ctx.AssetContext.clone();
                let asset_ctx = asset_ctx.unwrap();
                let asset_ctx_identifier = asset_ctx.identifier.clone();
                let param_type = Type::UserDefinedType(asset_ctx_identifier);
                let param_type = Type::InoutType(InoutType {
                    key_type: Box::new(param_type),
                });
                let param_self_identifier = Identifier {
                    token: "self".to_string(),
                    enclosing_type: None,
                    line_info: Default::default(),
                };

                let parameter = Parameter {
                    identifier: param_self_identifier,
                    type_assignment: param_type,
                    expression: None,
                    line_info: Default::default(),
                };

                _t.head.parameters.insert(0, parameter.clone());
                if _ctx.ScopeContext.is_some() {
                    let scope = _ctx.ScopeContext.clone();
                    let mut scope = scope.unwrap();
                    scope.parameters.insert(0, parameter);

                    _ctx.ScopeContext = Some(scope);
                }
            }
        }

        if _ctx.StructDeclarationContext.is_some() {
            if enclosing_identifier != format!("Quartz_Global") {
                let struct_ctx = _ctx.StructDeclarationContext.clone();
                let struct_ctx = struct_ctx.unwrap();
                let struct_ctx_identifier = struct_ctx.identifier.clone();
                let param_type = Type::UserDefinedType(struct_ctx_identifier);
                let param_type = Type::InoutType(InoutType {
                    key_type: Box::new(param_type),
                });
                let param_self_identifier = Identifier {
                    token: "self".to_string(),
                    enclosing_type: None,
                    line_info: Default::default(),
                };

                let parameter = Parameter {
                    identifier: param_self_identifier,
                    type_assignment: param_type,
                    expression: None,
                    line_info: Default::default(),
                };

                _t.head.parameters.insert(0, parameter.clone());
                if _ctx.ScopeContext.is_some() {
                    let scope = _ctx.ScopeContext.clone();
                    let mut scope = scope.unwrap();
                    scope.parameters.insert(0, parameter);

                    _ctx.ScopeContext = Some(scope);
                }
            }
        }

        if _ctx.is_contract_behaviour_declaration_context() {
            let contract = _ctx.ContractBehaviourDeclarationContext.clone();
            let contract = contract.unwrap();
            let identifier = contract.identifier.clone();
            let parameter_type = Type::UserDefinedType(identifier);
            let parameter_type = Type::InoutType(InoutType {
                key_type: Box::new(parameter_type),
            });
            let parameter = Parameter {
                identifier: Identifier {
                    token: "self".to_string(),
                    enclosing_type: None,
                    line_info: Default::default(),
                },
                type_assignment: parameter_type,
                expression: None,
                line_info: Default::default(),
            };

            _t.head.parameters.insert(0, parameter.clone());

            if _ctx.scope_context().is_some() {
                let scope = _ctx.ScopeContext.clone();
                let mut scope = scope.unwrap();
                scope.parameters.insert(0, parameter.clone());
                _ctx.ScopeContext = Some(scope);
            }

            if contract.caller.is_some() {
                let caller = contract.caller.unwrap();

                _t.body.insert(0, generate_caller_statement(caller))
            }
        }

        let scope = _t.ScopeContext.clone();
        if scope.is_some() {
            let mut scope = scope.unwrap();
            scope.parameters = _t.head.parameters.clone();
            _t.ScopeContext = Some(scope);
        }
        Ok(())
    }

    fn finish_function_declaration(
        &mut self,
        _t: &mut FunctionDeclaration,
        _ctx: &mut Context,
    ) -> VResult {
        let function_declaration = _t;
        let body = function_declaration.body.clone();
        let mut statements = get_declaration(_ctx);


        let mut deletions = delete_declarations(function_declaration.body.clone());

        statements.append(&mut deletions);
        function_declaration.body = statements;


        if function_declaration.is_void() {
            let statement = function_declaration.body.last();
            if !function_declaration.body.is_empty() {
                if let Statement::ReturnStatement(r) = statement.unwrap() {
                } else {
                    function_declaration
                        .body
                        .push(Statement::ReturnStatement(ReturnStatement {
                            expression: None,
                            ..Default::default()
                        }));
                }
            } else {
                function_declaration
                    .body
                    .push(Statement::ReturnStatement(ReturnStatement {
                        expression: None,
                        ..Default::default()
                    }));
            }
        } else {

            let variable_declaration = VariableDeclaration {
                declaration_token: None,
                identifier: Identifier {
                    token: "ret".to_string(),
                    enclosing_type: None,
                    line_info: Default::default(),
                },
                variable_type: function_declaration
                    .head
                    .result_type
                    .as_ref()
                    .unwrap()
                    .clone(),
                expression: None,
            };
            function_declaration.body.insert(
                0,
                Statement::Expression(Expression::VariableDeclaration(variable_declaration)),
            )
        }

        Ok(())
    }

    fn start_special_declaration(
        &mut self,
        _t: &mut SpecialDeclaration,
        _ctx: &mut Context,
    ) -> VResult {
        let members = _t.body.clone();

        let members = members
            .into_iter()
            .filter_map(|m| {
                if let Statement::Expression(e) = m.clone() {
                    if let Expression::BinaryExpression(b) = e {
                        if let BinOp::Equal = b.op.clone() {
                            if let Expression::DictionaryLiteral(_) = *b.rhs_expression {
                                None
                            } else {
                                Some(m)
                            }
                        } else {
                            Some(m)
                        }
                    } else {
                        Some(m)
                    }
                } else {
                    Some(m)
                }
            })
            .collect();

        _t.body = members;
        if _ctx.ContractBehaviourDeclarationContext.is_some() {
            let b_ctx = _ctx.ContractBehaviourDeclarationContext.clone();
            let b_ctx = b_ctx.unwrap();
            let caller_binding = b_ctx.caller.clone();
            if caller_binding.is_some() {
                let caller_binding = caller_binding.unwrap();
                _t.body.insert(0, generate_caller_statement(caller_binding))
            }
        }
        Ok(())
    }

    fn finish_special_declaration(
        &mut self,
        _t: &mut SpecialDeclaration,
        _ctx: &mut Context,
    ) -> VResult {
        let function_declaration = _t;
        let body = function_declaration.body.clone();
        let mut statements = get_declaration(_ctx);
        if statements.is_empty() {}
        for statement in body {
            statements.push(statement.clone())
        }
        function_declaration.body = statements;

        Ok(())
    }

    fn start_expression(&mut self, _t: &mut Expression, _ctx: &mut Context) -> VResult {
        if let Expression::BinaryExpression(b) = _t {
            if let BinOp::Dot = b.op {
                if let Expression::Identifier(lhs) = &*b.lhs_expression {
                    if let Expression::Identifier(rhs) = &*b.rhs_expression {
                        if _ctx.environment.is_enum_declared(&lhs.token) {
                            let property = _ctx.environment.property_declarations(&lhs.token);
                            let property: Vec<Property> = property
                                .into_iter()
                                .filter(|p| p.get_identifier().token == rhs.token)
                                .collect();

                            if !property.is_empty() {
                                let property = property.first().unwrap();
                                if property.get_type() != Type::Error {
                                    *_t = property.get_value().unwrap()
                                }
                            }
                        }
                    }
                }
            } else if let BinOp::Equal = b.op {
                if let Expression::VariableDeclaration(v) = &*b.lhs_expression {
                    let variable = v.clone();
                    let identifier = if v.identifier.is_self() {
                        Expression::SelfExpression
                    } else {
                        Expression::Identifier(v.identifier.clone())
                    };
                    let expression = Expression::BinaryExpression(BinaryExpression {
                        lhs_expression: Box::new(identifier),
                        rhs_expression: b.rhs_expression.clone(),
                        op: BinOp::Equal,
                        line_info: b.line_info.clone(),
                    });
                    *_t = expression.clone();
                    if _ctx.is_function_declaration_context() {
                        let context = _ctx.FunctionDeclarationContext.clone();
                        let mut context = context.unwrap();
                        context.local_variables.push(variable.clone());

                        let scope = context.declaration.ScopeContext.clone();
                        let mut scope = scope.unwrap();
                        scope.local_variables.push(variable.clone());

                        context.declaration.ScopeContext = Some(scope);
                        _ctx.FunctionDeclarationContext = Some(context)
                    }

                    if _ctx.is_special_declaration_context() {
                        let context = _ctx.SpecialDeclarationContext.clone();
                        let mut context = context.unwrap();
                        context.local_variables.push(variable.clone());

                        let scope = context.declaration.ScopeContext.clone();
                        let mut scope = scope;
                        scope.local_variables.push(variable.clone());

                        context.declaration.ScopeContext = scope;
                        _ctx.SpecialDeclarationContext = Some(context);
                    }

                    if _ctx.has_scope_context() {
                        let scope = _ctx.ScopeContext.clone();
                        let mut scope = scope.unwrap();
                        scope.local_variables.push(variable.clone());

                        _ctx.ScopeContext = Some(scope)
                    }
                }
            }
        }
        Ok(())
    }

    fn start_binary_expression(
        &mut self,
        _t: &mut BinaryExpression,
        _ctx: &mut Context,
    ) -> VResult {
        let f = _t.clone();
        if _t.op.is_assignment_shorthand() {
            let op = _t.op.clone();
            let op = op.get_assignment_shorthand();
            _t.op = BinOp::Equal;

            let rhs = BinaryExpression {
                lhs_expression: _t.lhs_expression.clone(),
                rhs_expression: _t.rhs_expression.clone(),
                op,
                line_info: _t.line_info.clone(),
            };
            _t.rhs_expression = Box::from(Expression::BinaryExpression(rhs));
        } else if let BinOp::Dot = _t.op {
            let mut trail = _ctx.FunctionCallReceiverTrail.clone();
            trail.push(*_t.lhs_expression.clone());

            _ctx.FunctionCallReceiverTrail = trail;
            match *_t.lhs_expression.clone() {
                Expression::Identifier(i) => {
                    if let Expression::FunctionCall(_) = *_t.rhs_expression {
                    } else {
                        let lhs = _t.lhs_expression.clone();
                        let lhs = *lhs;
                        let lhs = expand_properties(lhs, _ctx, false);
                        _t.lhs_expression = Box::from(lhs);
                    }
                }
                Expression::BinaryExpression(b) => {
                    if let BinOp::Dot = b.op {
                        let lhs = _t.lhs_expression.clone();
                        let lhs = *lhs;
                        let lhs = expand_properties(lhs, _ctx, false);
                        _t.lhs_expression = Box::from(lhs);
                    }
                }
                (_) => {}
            }
        }

        Ok(())
    }

    fn finish_return_statement(&mut self, _t: &mut ReturnStatement, _ctx: &mut Context) -> VResult {
        _t.cleanup = _ctx.PostStatements.clone();
        _ctx.PostStatements = vec![];
        Ok(())
    }

    fn start_external_call(&mut self, _t: &mut ExternalCall, _ctx: &mut Context) -> VResult {
        if _ctx.ScopeContext.is_none() {
            panic!("Not Enough Information To Workout External Trait name")
        }

        if _ctx.enclosing_type_identifier().is_none() {
            panic!("Not Enough Information To Workout External Trait name")
        }
        let scope = _ctx.ScopeContext.clone();
        let scope = scope.unwrap();
        let enclosing = _ctx.enclosing_type_identifier().clone();
        let enclosing = enclosing.unwrap();
        let enclosing = enclosing.token;
        let receiver = _t.function_call.lhs_expression.clone();
        let receiver = *receiver;
        let receiver_type =
            _ctx.environment
                .get_expression_type(receiver, &enclosing, vec![], vec![], scope);
        _t.external_trait_name = Option::from(receiver_type.name());
        Ok(())
    }

    fn start_function_call(&mut self, _t: &mut FunctionCall, _ctx: &mut Context) -> VResult {
        let mut receiver_trail = _ctx.FunctionCallReceiverTrail.clone();


        if Environment::is_runtime_function_call(_t) {
            return Ok(());
        }

        if receiver_trail.is_empty() {
            receiver_trail = vec![Expression::SelfExpression]
        }

        let mangled = mangle_function_call_name(_t, _ctx);
        if mangled.is_some() {
            let mangled = mangled.unwrap();
            _t.mangled_identifier = Option::from(Identifier {
                token: mangled,
                enclosing_type: None,
                line_info: Default::default(),
            });
        }

        let function_call = _t.clone();
        if !_ctx.environment.is_initiliase_call(function_call.clone())
            && !_ctx
                .environment
                .is_trait_declared(&function_call.identifier.token)
        {
            let is_global_function_call = is_global_function_call(function_call, _ctx);

            let enclosing_type = _ctx.enclosing_type_identifier();
            let enclosing_type = enclosing_type.unwrap_or_default();
            let enclosing_type = enclosing_type.token;

            let caller_protections = if _ctx.ContractBehaviourDeclarationContext.is_some() {
                let behaviour = _ctx.ContractBehaviourDeclarationContext.clone();
                let behaviour = behaviour.unwrap();
                behaviour.caller_protections
            } else {
                vec![]
            };

            let scope = _ctx.ScopeContext.clone();
            let scope = scope.unwrap_or_default();

            let declared_enclosing = if is_global_function_call {
                format!("Quartz_Global")
            } else {
                let receiver = receiver_trail.get(receiver_trail.len() - 1);
                let receiver = receiver.unwrap();
                let receivier = receiver.clone();
                _ctx.environment
                    .get_expression_type(
                        receivier,
                        &enclosing_type,
                        vec![],
                        caller_protections,
                        scope.clone(),
                    )
                    .name()
            };

            if _ctx.environment.is_struct_declared(&declared_enclosing)
                || _ctx.environment.is_contract_declared(&declared_enclosing)
                || _ctx.environment.is_trait_declared(&declared_enclosing)
                || _ctx.environment.is_asset_declared(&declared_enclosing)
            {
                if !is_global_function_call {
                    let mut expresssions = receiver_trail.clone();

                    let mut expression = construct_expression(expresssions);

                    if expression.enclosing_type().is_some() {
                        expression = expand_properties(expression, _ctx, false);
                    } else if let Expression::BinaryExpression(b) = expression.clone() {
                        expression = expand_properties(expression, _ctx, false);
                    }

                    let enclosing_type = _ctx.enclosing_type_identifier();
                    let enclosing_type = enclosing_type.unwrap_or_default();
                    let enclosing_type = enclosing_type.token;

                    let result_type = match expression.clone() {
                        Expression::Identifier(i) => {
                            if scope.type_for(i.token.clone()).is_some() {
                                let result = scope.type_for(i.token).clone();
                                result.unwrap()
                            } else {
                                _ctx.environment.get_expression_type(
                                    expression.clone(),
                                    &enclosing_type,
                                    vec![],
                                    vec![],
                                    scope.clone(),
                                )
                            }
                        }
                        _ => _ctx.environment.get_expression_type(
                            expression.clone(),
                            &enclosing_type,
                            vec![],
                            vec![],
                            scope.clone(),
                        ),
                    };

                    if !result_type.is_inout_type() {
                        let inout = InoutExpression {
                            ampersand_token: "".to_string(),
                            expression: Box::new(expression.clone()),
                        };
                        expression = Expression::InoutExpression(inout)
                    }

                    let mut arguments = _t.arguments.clone();
                    arguments.insert(
                        0,
                        FunctionArgument {
                            identifier: None,
                            expression,
                        },
                    );

                    _t.arguments = arguments;
                }
            }
        }

        _ctx.FunctionCallReceiverTrail = vec![];

        Ok(())
    }

    fn start_function_argument(
        &mut self,
        _t: &mut FunctionArgument,
        _ctx: &mut Context,
    ) -> VResult {
        let mut borrow_local = false;
        let function_argument = _t.clone();
        let mut expression = function_argument.expression.clone();
        if let Expression::InoutExpression(i) = function_argument.expression.clone() {
            expression = *i.expression.clone();

            if _ctx.ScopeContext.is_some() {
                let scope = _ctx.ScopeContext.clone();
                let scope = scope.unwrap();

                if _ctx.enclosing_type_identifier().is_some() {
                    let enclosing = _ctx.enclosing_type_identifier().clone();
                    let enclosing = enclosing.unwrap();
                    let enclosing = enclosing.token;
                    let caller_protections = if _ctx.ContractBehaviourDeclarationContext.is_some() {
                        let behaviour = _ctx.ContractBehaviourDeclarationContext.clone();
                        let behaviour = behaviour.unwrap();
                        behaviour.caller_protections
                    } else {
                        vec![]
                    };
                    let expression_type = _ctx.environment.get_expression_type(
                        expression.clone(),
                        &enclosing,
                        vec![],
                        caller_protections,
                        scope,
                    );

                    if !expression_type.is_currency_type()
                        && !expression_type.is_external_resource(_ctx.environment.clone())
                    {
                        borrow_local = true;
                    }
                } else {
                    borrow_local = true;
                }
            } else {
                borrow_local = true;
            }
        } else {
            expression = function_argument.expression.clone();
        }

        match expression.clone() {
            Expression::Identifier(ident) => {
                if ident.enclosing_type.is_some() {
                    let ident_enclosing = ident.enclosing_type.clone();
                    expression = pre_assign(expression, _ctx, borrow_local, true);
                }
            }
            Expression::BinaryExpression(b) => {
                if let BinOp::Dot = b.op {
                    expression = expand_properties(expression, _ctx, borrow_local)
                }
            }
            _ => {
                if let Expression::InoutExpression(i) = function_argument.expression.clone() {
                    expression = function_argument.expression.clone()
                }
            }
        }

        _t.expression = expression;
        Ok(())
    }

    fn start_type(&mut self, _t: &mut Type, _ctx: &mut Context) -> VResult {
        if _t.is_external_contract(_ctx.environment.clone()) {
            *_t = Type::Address
        }
        Ok(())
    }
}

pub fn convert_default_parameter_functions(
    base: FunctionDeclaration,
    t: &TypeIdentifier,
    _ctx: &mut Context,
) -> Vec<FunctionDeclaration> {
    let default_parameters: Vec<Parameter> = base
        .clone()
        .head
        .parameters
        .into_iter()
        .filter(|p| p.expression.is_some())
        .rev()
        .collect();
    let mut functions = vec![base];

    for parameter in default_parameters {
        let mut processed = Vec::new();
        for f in &functions {
            let mut assigned_function = f.clone();
            let mut removed = f.clone();

            assigned_function.head.parameters = assigned_function
                .head
                .parameters
                .into_iter()
                .filter(|p| p.identifier.token != f.head.identifier.token)
                .collect();

            removed.head.parameters = removed
                .head
                .parameters
                .into_iter()
                .map(|p| {
                    if p.identifier.token == parameter.identifier.token {
                        let mut param = p;
                        param.expression = None;
                        param
                    } else {
                        p
                    }
                })
                .collect();

            if assigned_function.ScopeContext.is_some() {
                let scope = ScopeContext {
                    parameters: assigned_function.head.parameters.clone(),
                    local_variables: vec![],
                    ..Default::default()
                };
                assigned_function.ScopeContext = Some(scope);
            }

            _ctx.environment.remove_function(f, t);

            let protections = if _ctx.ContractBehaviourDeclarationContext.is_some() {
                let temp = _ctx.ContractBehaviourDeclarationContext.clone();
                let temp = temp.unwrap();
                temp.caller_protections.clone()
            } else {
                vec![]
            };
            _ctx.environment
                .add_function(&removed, t, protections.clone());

            processed.push(removed);


            let arguments: Vec<FunctionArgument> = f
                .head
                .parameters
                .clone()
                .into_iter()
                .map(|p| {
                    if p.identifier.token == parameter.identifier.token {
                        let mut expression = parameter.expression.as_ref().unwrap().clone();
                        expression.assign_enclosing_type(t);
                        FunctionArgument {
                            identifier: Some(p.identifier.clone()),
                            expression,
                        }
                    } else {
                        FunctionArgument {
                            identifier: Some(p.identifier.clone()),
                            expression: Expression::Identifier(p.identifier.clone()),
                        }
                    }
                })
                .collect();

            if assigned_function.head.result_type.is_some() {
                let function_call = FunctionCall {
                    identifier: f.head.identifier.clone(),
                    arguments,
                    mangled_identifier: None,
                };
                let return_statement = ReturnStatement {
                    expression: Option::from(Expression::FunctionCall(function_call)),
                    cleanup: vec![],
                    line_info: parameter.line_info.clone(),
                };
                let return_statement = Statement::ReturnStatement(return_statement);
                assigned_function.body = vec![return_statement];
            } else {
                let function_call = FunctionCall {
                    identifier: f.head.identifier.clone(),
                    arguments,
                    mangled_identifier: None,
                };
                let function_call = Statement::Expression(Expression::FunctionCall(function_call));
                assigned_function.body = vec![function_call];
            }

            _ctx.environment
                .add_function(&assigned_function, t, protections);

            processed.push(assigned_function);
        }
        functions = processed.clone();
    }
    return functions;
}

pub fn get_declaration(ctx: &mut Context) -> Vec<Statement> {
    let scope = ctx.ScopeContext.clone();
    if scope.is_some() {
        let declarations = scope
            .unwrap()
            .local_variables
            .into_iter()
            .map(|v| {
                let mut declaration = v.clone();
                if !declaration.identifier.is_self() {
                    let name = declaration.identifier.token.clone();
                    declaration.identifier = Identifier {
                        token: mangle(name),
                        enclosing_type: None,
                        line_info: Default::default(),
                    };
                }
                return Statement::Expression(Expression::VariableDeclaration(declaration));
            })
            .collect();
        return declarations;
    }
    return vec![];
}

pub fn delete_declarations(statements: Vec<Statement>) -> Vec<Statement> {
    let statements = statements
        .clone()
        .into_iter()
        .filter_map(|s| {
            if let Statement::Expression(e) = s.clone() {
                if let Expression::VariableDeclaration(v) = e {
                    None
                } else {
                    Some(s)
                }
            } else {
                Some(s)
            }
        })
        .collect();
    return statements;
}

pub fn generate_contract_wrapper(
    function: FunctionDeclaration,
    contract_behaviour_declaration: &ContractBehaviourDeclaration,
    context: &mut Context,
) -> FunctionDeclaration{
    let mut wrapper = function.clone();
    let name = function.head.identifier.token.clone();
    wrapper.mangledIdentifier = Option::from(mangle_function_move(name, &"".to_string(), true));

    wrapper.body = vec![];
    wrapper.tags.push("acquires T".to_string());

    if !function.is_void() && !function.body.is_empty() {
        let mut func = function.clone();
        wrapper.body.push(func.body.remove(0));
    }

    let contract_address_parameter = Parameter {
        identifier: Identifier {
            token: "_address_this".to_string(),
            enclosing_type: None,
            line_info: Default::default(),
        },
        type_assignment: Type::Address,
        expression: None,
        line_info: Default::default(),
    };

    let original_parameter = wrapper.head.parameters.remove(0);

    wrapper
        .head
        .parameters
        .insert(0, contract_address_parameter.clone());
    let original_parameter = original_parameter;

    let self_declaration = VariableDeclaration {
        declaration_token: None,
        identifier: Identifier {
            token: "self".to_string(),
            enclosing_type: None,
            line_info: Default::default(),
        },
        variable_type: original_parameter.type_assignment.clone(),
        expression: None,
    };
    wrapper
        .body
        .push(Statement::Expression(Expression::VariableDeclaration(
            self_declaration,
        )));

    let self_assignment = BinaryExpression {
        lhs_expression: Box::new(Expression::SelfExpression),
        rhs_expression: Box::new(Expression::RawAssembly(
            format!(
                "borrow_global_mut<T>(move({param}))",
                param = mangle(contract_address_parameter.identifier.token.clone())
            ),
            Some(original_parameter.type_assignment.clone()),
        )),
        op: BinOp::Equal,
        line_info: Default::default(),
    };
    wrapper
        .body
        .push(Statement::Expression(Expression::BinaryExpression(
            self_assignment,
        )));

    let caller_protections: Vec<CallerProtection> = contract_behaviour_declaration
        .caller_protections
        .clone()
        .into_iter()
        .filter(|c| c.is_any())
        .collect();
    if !contract_behaviour_declaration.caller_protections.is_empty()
        && caller_protections.is_empty()
    {
        let caller = Identifier {
            token: "_caller".to_string(),
            enclosing_type: None,
            line_info: Default::default(),
        };

        wrapper.body.insert(
            0,
            Statement::Expression(Expression::VariableDeclaration(VariableDeclaration {
                declaration_token: None,
                identifier: Identifier {
                    token: mangle(caller.token.clone()),
                    enclosing_type: None,
                    line_info: Default::default(),
                },
                variable_type: Type::Address,
                expression: None,
            })),
        );

        wrapper.body.push(generate_caller_statement(caller.clone()));

        let predicates = contract_behaviour_declaration.caller_protections.clone();

        let predicates: Vec<Expression> = predicates
            .into_iter()
            .map(|c| {
                let mut ident = c.identifier.clone();
                ident.enclosing_type =
                    Option::from(contract_behaviour_declaration.identifier.token.clone());
                let en_ident = contract_behaviour_declaration.identifier.clone();
                let c_type = context.environment.get_expression_type(
                    Expression::Identifier(ident.clone()),
                    &en_ident.token,
                    vec![],
                    vec![],
                    ScopeContext {
                        parameters: vec![],
                        local_variables: vec![],
                        counter: 0,
                    },
                );

                match c_type {
                    Type::Address => Expression::BinaryExpression(BinaryExpression {
                        lhs_expression: Box::new(Expression::Identifier(ident.clone())),
                        rhs_expression: Box::new(Expression::Identifier(caller.clone())),
                        op: BinOp::DoubleEqual,
                        line_info: Default::default(),
                    }),
                    _ => unimplemented!(),
                }
            })
            .collect();

        let assertion = generate_assertion(
            predicates,
            FunctionContext {
                environment: context.environment.clone(),
                ScopeContext: function.ScopeContext.clone().unwrap_or_default(),
                enclosing_type: contract_behaviour_declaration.identifier.token.clone(),
                block_stack: vec![MoveIRBlock { statements: vec![] }],
                in_struct_function: false,
                is_constructor: false,
            },
        );

        wrapper.body.push(assertion)
    }

    let arguments = function
        .head
        .parameters
        .clone()
        .into_iter()
        .map(|p| FunctionArgument {
            identifier: None,
            expression: Expression::Identifier(p.identifier.clone()),
        })
        .collect();

    let name = function.mangledIdentifier.clone();
    let function_call = Expression::FunctionCall(FunctionCall {
        identifier: Identifier {
            token: name.unwrap_or_default(),
            enclosing_type: None,
            line_info: Default::default(),
        },
        arguments,
        mangled_identifier: None,
    });

    if function.is_void() {
        wrapper
            .body
            .push(Statement::Expression(function_call.clone()))
    }

    wrapper
        .body
        .push(Statement::ReturnStatement(ReturnStatement {
            expression: {
                if function.is_void() {
                    None
                } else {
                    Some(function_call.clone())
                }
            },
            ..Default::default()
        }));

    return wrapper;
}

pub fn expand_properties(expression: Expression, ctx: &mut Context, borrow: bool) -> Expression {
    match expression.clone() {
        Expression::Identifier(i) => {
            if ctx.has_scope_context() {
                let scope = ctx.ScopeContext.clone();
                let scope = scope.unwrap();
                let identifier_type = scope.type_for(i.token);
                if identifier_type.is_some() {
                    let identifier_type = identifier_type.unwrap();
                    if !identifier_type.is_inout_type() {
                        return pre_assign(expression, ctx, borrow, false);
                    }
                }

                if i.enclosing_type.is_some() {
                    return pre_assign(expression, ctx, borrow, true);
                }
            }
        }
        Expression::BinaryExpression(b) => {
            return if let BinOp::Dot = b.op {
                let mut binary = b.clone();
                let lhs = b.lhs_expression.clone();
                let lhs = expand_properties(*lhs, ctx, borrow);
                binary.lhs_expression = Box::from(lhs);
                pre_assign(Expression::BinaryExpression(binary), ctx, borrow, true)
            } else {
                let mut binary = b.clone();
                let lhs = b.lhs_expression.clone();
                let lhs = expand_properties(*lhs, ctx, borrow);
                binary.lhs_expression = Box::from(lhs);
                let rhs = b.rhs_expression.clone();
                let rhs = expand_properties(*rhs, ctx, borrow);
                binary.lhs_expression = Box::from(rhs);
                pre_assign(Expression::BinaryExpression(binary), ctx, borrow, true)
            }
        }
        (_) => return expression,
    };
    return expression;
}

pub fn pre_assign(
    expression: Expression,
    ctx: &mut Context,
    borrow: bool,
    is_reference: bool,
) -> Expression {
    let enclosing_type = ctx.enclosing_type_identifier().unwrap();
    let scope = ctx.ScopeContext.clone();
    let mut scope = scope.unwrap();
    let mut expression_type = ctx.environment.get_expression_type(
        expression.clone(),
        &enclosing_type.token,
        vec![],
        vec![],
        scope.clone(),
    );

    if expression_type.is_external_contract(ctx.environment.clone()) {
        expression_type = Type::Address
    }

    let expression = if borrow || !is_reference || expression_type.is_built_in_type() {
        expression.clone()
    } else {
        Expression::InoutExpression(InoutExpression {
            ampersand_token: "".to_string(),
            expression: Box::new(expression.clone()),
        })
    };

    let mut temp_identifier = Identifier {
        token: "LOL".to_string(),
        enclosing_type: None,
        line_info: Default::default(),
    };

    let statements = ctx.PreStatements.clone();
    let statements: Vec<Expression> = statements
        .into_iter()
        .filter_map(|s| match s {
            Statement::Expression(e) => Some(e),
            (_) => None,
        })
        .collect();
    let statements: Vec<BinaryExpression> = statements
        .into_iter()
        .filter_map(|s| match s {
            Expression::BinaryExpression(e) => Some(e),
            (_) => None,
        })
        .collect();
    let statements: Vec<BinaryExpression> = statements
        .into_iter()
        .filter(|b| {
            if let BinOp::Equal = b.op {
                if let Expression::Identifier(_) = *b.lhs_expression {
                    return expression == *b.rhs_expression;
                }
            }
            return false;
        })
        .collect();
    let mut declaration = VariableDeclaration {
        declaration_token: None,
        identifier: Default::default(),
        variable_type: Type::Bool,
        expression: None,
    };
    if statements.is_empty() {
        temp_identifier = scope.fresh_identifier(expression.clone().get_line_info());
        declaration = if expression_type.is_built_in_type() || borrow {
            VariableDeclaration {
                declaration_token: None,
                identifier: temp_identifier.clone(),
                variable_type: expression_type,
                expression: None,
            }
        } else {
            let var = VariableDeclaration {
                declaration_token: None,
                identifier: temp_identifier.clone(),
                variable_type: Type::InoutType(InoutType {
                    key_type: Box::new(expression_type.clone()),
                }),
                expression: None,
            };
            let mut post_statement = ctx.PostStatements.clone();
            post_statement.push(release(
                Expression::Identifier(temp_identifier.clone()),
                Type::InoutType(InoutType {
                    key_type: Box::new(expression_type),
                }),
            ));
            ctx.PostStatements = post_statement;
            var
        };

        let mut pre_statement = ctx.PreStatements.clone();
        pre_statement.push(Statement::Expression(Expression::BinaryExpression(
            BinaryExpression {
                lhs_expression: Box::new(Expression::Identifier(temp_identifier.clone())),
                rhs_expression: Box::new(expression),
                op: BinOp::Equal,
                line_info: temp_identifier.line_info.clone(),
            },
        )));
        ctx.PreStatements = pre_statement;

        if ctx.is_function_declaration_context() {
            let context = ctx.FunctionDeclarationContext.clone();
            let mut context = context.unwrap();
            context.local_variables.push(declaration.clone());

            if context.declaration.ScopeContext.is_some() {
                let scope_ctx = context.declaration.ScopeContext.clone();
                let mut scope_ctx = scope_ctx.unwrap();
                scope_ctx.local_variables.push(declaration.clone());

                context.declaration.ScopeContext = Some(scope_ctx);
            }

            ctx.FunctionDeclarationContext = Option::from(context);
        }

        if ctx.is_special_declaration_context() {
            let context = ctx.SpecialDeclarationContext.clone();
            let mut context = context.unwrap();
            context.local_variables.push(declaration.clone());

            let scope_ctx = context.declaration.ScopeContext.clone();
            let mut scope_ctx = scope_ctx;
            scope_ctx.local_variables.push(declaration.clone());

            context.declaration.ScopeContext = scope_ctx;

            ctx.SpecialDeclarationContext = Option::from(context);
        }
        scope.local_variables.push(declaration);
    } else {
        let statement = statements.first();
        let statement = statement.unwrap();
        if let Expression::Identifier(i) = &*statement.lhs_expression {
            temp_identifier = i.clone()
        }
    }

    ctx.ScopeContext = Option::from(scope);
    if borrow {
        return Expression::InoutExpression(InoutExpression {
            ampersand_token: "&".to_string(),
            expression: Box::new(Expression::Identifier(temp_identifier)),
        });
    }
    return Expression::Identifier(temp_identifier);
}

pub fn generate_caller_statement(caller: Identifier) -> Statement {
    let assignment = BinaryExpression {
        lhs_expression: Box::new(Expression::Identifier(caller.clone())),
        rhs_expression: Box::new(Expression::RawAssembly(
            "get_txn_sender()".to_string(),
            Option::from(Type::Address),
        )),
        op: BinOp::Equal,
        line_info: caller.line_info.clone(),
    };

    return Statement::Expression(Expression::BinaryExpression(assignment));
}

pub fn generate_assertion(
    predicate: Vec<Expression>,
    function_context: FunctionContext,
) -> Statement {
    let mut predicates = predicate.clone();
    if predicates.len() >= 2 {
        let or_expression = Expression::BinaryExpression(BinaryExpression {
            lhs_expression: Box::new(predicates.remove(0)),
            rhs_expression: Box::new(predicates.remove(0)),
            op: BinOp::Or,
            line_info: Default::default(),
        });
        while !predicates.is_empty() {
            unimplemented!()
        }
        let expression = MoveExpression {
            expression: or_expression,
            position: Default::default(),
        }
        .generate(&function_context);
        let string = format!("assert({ex}, 1)", ex = expression);
        return Statement::Expression(Expression::RawAssembly(string, Option::from(Type::Error)));
    }

    if predicates.is_empty() {
        unimplemented!()
    }
    let expression = predicates.remove(0);
    let expression = MoveExpression {
        expression,
        position: Default::default(),
    }
    .generate(&function_context);
    let string = format!("assert({ex}, 1)", ex = expression);
    return Statement::Expression(Expression::RawAssembly(string, Option::from(Type::Error)));
}

pub fn release(expression: Expression, expression_type: Type) -> Statement {
    return Statement::Expression(Expression::BinaryExpression(BinaryExpression {
        lhs_expression: Box::new(Expression::RawAssembly(
            "_".to_string(),
            Option::from(expression_type),
        )),
        rhs_expression: Box::new(expression.clone()),
        op: BinOp::Equal,
        line_info: expression.get_line_info().clone(),
    }));
}

pub fn mangle_function_call_name(function_call: &FunctionCall, ctx: &Context) -> Option<String> {
    if !Environment::is_runtime_function_call(function_call) && !ctx.IsExternalFunctionCall {
        let enclosing_type = if function_call.identifier.enclosing_type.is_some() {
            let enclosing = function_call.identifier.enclosing_type.clone();
            let enclosing = enclosing.unwrap();
            enclosing
        } else {
            let enclosing = ctx.enclosing_type_identifier().clone();
            let enclosing = enclosing.unwrap();
            enclosing.token.clone()
        };


        let call = function_call.clone();

        let caller_protections = if ctx.ContractBehaviourDeclarationContext.is_some() {
            let behaviour = ctx.ContractBehaviourDeclarationContext.clone();
            let behaviour = behaviour.unwrap();
            behaviour.caller_protections
        } else {
            vec![]
        };

        let scope = ctx.ScopeContext.clone();
        let scope = scope.unwrap_or_default();

        let match_result = ctx.environment.match_function_call(
            call,
            &enclosing_type,
            caller_protections,
            scope.clone(),
        );

        match match_result {
            FunctionCallMatchResult::MatchedFunction(fi) => {
                let declaration = fi.declaration;
                let param_types = declaration.head.parameters;
                let param_types: Vec<Type> = param_types
                    .clone()
                    .into_iter()
                    .map(|p| p.type_assignment)
                    .collect();
                Some(mangle_function_move(
                    declaration.head.identifier.token,
                    &enclosing_type,
                    false,
                ))
            }
            FunctionCallMatchResult::MatchedFunctionWithoutCaller(c) => {
                if c.candidates.len() != 1 {
                    panic!("Unable to find function declaration")
                }

                let candidate = c.candidates.clone().remove(0);

                if let CallableInformation::FunctionInformation(fi) = candidate {
                    let declaration = fi.declaration;
                    let param_types = declaration.head.parameters;
                    let param_types: Vec<Type> = param_types
                        .clone()
                        .into_iter()
                        .map(|p| p.type_assignment)
                        .collect();

                    return Some(mangle_function_move(
                        declaration.head.identifier.token,
                        &enclosing_type,
                        false,
                    ));
                } else {
                    panic!("Non-function CallableInformation where function expected")
                }
            }
            FunctionCallMatchResult::MatchedInitializer(i) => {

                Some(mangle_function_move(
                    "init".to_string(),
                    &function_call.identifier.token,
                    false,
                ))
            }
            FunctionCallMatchResult::MatchedFallback(_) => unimplemented!(),
            FunctionCallMatchResult::MatchedGlobalFunction(fi) => {
                let declaration = fi.declaration;

                Some(mangle_function_move(
                    declaration.head.identifier.token,
                    &"Quartz_Global".to_string(),
                    false,
                ))
            }
            FunctionCallMatchResult::Failure(lol) => None,
        }
    } else {
        let lol = !Environment::is_runtime_function_call(function_call);
        let lol2 = !ctx.IsExternalFunctionCall;
        Some(function_call.identifier.token.clone())
    }
}

pub fn is_global_function_call(function_call: FunctionCall, ctx: &Context) -> bool {
    let enclosing = ctx.enclosing_type_identifier().clone();
    let enclosing = enclosing.unwrap();
    let enclosing = enclosing.token.clone();
    let caller_protections = if ctx.ContractBehaviourDeclarationContext.is_some() {
        let behaviour = ctx.ContractBehaviourDeclarationContext.clone();
        let behaviour = behaviour.unwrap();
        behaviour.caller_protections
    } else {
        vec![]
    };

    let scope = ctx.ScopeContext.clone();
    let scope = scope.unwrap_or_default();

    let result =
        ctx.environment
            .match_function_call(function_call, &enclosing, caller_protections, scope);

    if let FunctionCallMatchResult::MatchedGlobalFunction(_) = result {
        return true;
    }

    return false;
}

pub fn construct_expression(expressions: Vec<Expression>) -> Expression {
    let mut expression = expressions.clone();
    if expression.len() > 1 {
        let first = expression.remove(0);
        return Expression::BinaryExpression(BinaryExpression {
            lhs_expression: Box::new(first),
            rhs_expression: Box::new(construct_expression(expression)),
            op: BinOp::Dot,
            line_info: Default::default(),
        });
    } else {
        return expression.remove(0);
    };
}
