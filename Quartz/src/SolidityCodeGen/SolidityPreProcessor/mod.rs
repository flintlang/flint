use crate::context::*;
use crate::environment::*;
use crate::visitor::Visitor;
use crate::AST::Expression::SelfExpression;
use crate::AST::*;

pub(crate) struct SolidityPreProcessor {}

impl Visitor for SolidityPreProcessor {
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

        let param_types = _t.head.parameter_types().clone();
        let mangled_name = mangle_solidity_function_name(
            _t.head.identifier.token.clone(),
            param_types,
            &enclosing_identifier,
        );
        _t.mangledIdentifier = Some(mangled_name);

        if _ctx.StructDeclarationContext.is_some() {
            let s_ctx = _ctx.StructDeclarationContext.clone();
            let s_ctx = s_ctx.unwrap();

            if enclosing_identifier != "Quartz_Global".to_string() {
                let param = construct_parameter(
                    "QuartzSelf".to_string(),
                    Type::InoutType(InoutType {
                        key_type: Box::new(Type::UserDefinedType(Identifier {
                            token: s_ctx.identifier.token.clone(),
                            enclosing_type: None,
                            line_info: Default::default(),
                        })),
                    }),
                );

                _t.head.parameters.insert(0, param);
            }
        }

        let dynamic_params = _t.head.parameters.clone();
        let dynamic_params: Vec<Parameter> = dynamic_params
            .into_iter()
            .filter(|p| p.is_dynamic())
            .collect();

        let mut offset = 0;
        let mut index = 0;
        for p in dynamic_params {
            let ismem_param =
                construct_parameter(mangle_mem(p.identifier.token.clone()), Type::Bool);
            _t.head.parameters.insert(index + offset + 1, ismem_param);
            offset += 1;
            index += 1;
        }

        Ok(())
    }

    fn start_expression(&mut self, _t: &mut Expression, _ctx: &mut Context) -> VResult {
        let expression = _t.clone();
        if let Expression::BinaryExpression(b) = expression {
            if let BinOp::Dot = b.op {
                if let Expression::Identifier(lhs) = *b.lhs_expression.clone() {
                    if let Expression::Identifier(rhs) = *b.rhs_expression.clone() {
                        if _ctx.environment.is_enum_declared(&lhs.token) {
                            unimplemented!()
                        }
                    }
                }
            } else if let BinOp::Equal = b.op {
                if let Expression::FunctionCall(f) = *b.rhs_expression.clone() {
                    let mut function_call = f.clone();
                    if _ctx.environment.is_initiliase_call(f) {
                        let inout = Expression::InoutExpression(InoutExpression {
                            ampersand_token: "&".to_string(),
                            expression: b.lhs_expression.clone(),
                        });
                        function_call.arguments.insert(
                            0,
                            FunctionArgument {
                                identifier: None,
                                expression: inout,
                            },
                        );

                        *_t = Expression::FunctionCall(function_call.clone());

                        if let Expression::VariableDeclaration(v) = *b.lhs_expression.clone() {
                            if v.variable_type.is_dynamic_type() {
                                let function_arg = Expression::Identifier(v.identifier.clone());
                                let function_arg = Expression::InoutExpression(InoutExpression {
                                    ampersand_token: "".to_string(),
                                    expression: Box::new(function_arg),
                                });

                                let mut call = function_call.clone();
                                call.arguments.remove(0);
                                call.arguments.insert(
                                    0,
                                    FunctionArgument {
                                        identifier: None,
                                        expression: function_arg,
                                    },
                                );

                                *_t = Expression::Sequence(vec![
                                    Expression::VariableDeclaration(v.clone()),
                                    Expression::FunctionCall(call.clone()),
                                ]);
                            }
                        }
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
        }

        let op = _t.op.clone();

        if let BinOp::LessThanOrEqual = op {
            let lhs = Expression::BinaryExpression(BinaryExpression {
                lhs_expression: _t.lhs_expression.clone(),
                rhs_expression: _t.rhs_expression.clone(),
                op: BinOp::LessThan,
                line_info: _t.line_info.clone(),
            });
            let rhs = Expression::BinaryExpression(BinaryExpression {
                lhs_expression: _t.lhs_expression.clone(),
                rhs_expression: _t.rhs_expression.clone(),
                op: BinOp::DoubleEqual,
                line_info: _t.line_info.clone(),
            });
            _t.lhs_expression = Box::from(lhs);

            _t.rhs_expression = Box::from(rhs);
            _t.op = BinOp::Or;
        } else if let BinOp::GreaterThanOrEqual = op {
            let lhs = Expression::BinaryExpression(BinaryExpression {
                lhs_expression: _t.lhs_expression.clone(),
                rhs_expression: _t.rhs_expression.clone(),
                op: BinOp::GreaterThan,
                line_info: _t.line_info.clone(),
            });
            let rhs = Expression::BinaryExpression(BinaryExpression {
                lhs_expression: _t.lhs_expression.clone(),
                rhs_expression: _t.rhs_expression.clone(),
                op: BinOp::DoubleEqual,
                line_info: _t.line_info.clone(),
            });
            _t.lhs_expression = Box::from(lhs);

            _t.rhs_expression = Box::from(rhs);
            _t.op = BinOp::Or;
        }

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

    fn start_function_call(&mut self, _t: &mut FunctionCall, _ctx: &mut Context) -> VResult {
        if is_ether_runtime_function_call(_t) {
            return Ok(());
        }

        if _ctx.FunctionCallReceiverTrail.is_empty() {
            _ctx.FunctionCallReceiverTrail = vec![Expression::SelfExpression];
        }

        let mut f_call = _t.clone();
        if _ctx.environment.is_initiliase_call(f_call.clone()) {
            let mut temp = f_call.clone();
            if _ctx.FunctionDeclarationContext.is_some() || _ctx.SpecialDeclarationContext.is_some()
            {
                if !temp.arguments.is_empty() {
                    temp.arguments.remove(0);
                }
            }
            let mangled = mangle_function_call_name(&temp, _ctx);
            if mangled.is_some() {
                println!("Mangled");
                let mangled = mangled.unwrap();
                _t.mangled_identifier = Option::from(Identifier {
                    token: mangled.clone(),
                    enclosing_type: None,
                    line_info: Default::default(),
                });
                f_call.mangled_identifier = Option::from(Identifier {
                    token: mangled,
                    enclosing_type: None,
                    line_info: Default::default(),
                });
            }
        } else {
            let enclosing_type = if is_global_function_call(f_call.clone(), _ctx) {
                format!("Quartz_Global")
            } else {
                let trail_last = _ctx
                    .FunctionCallReceiverTrail
                    .get(_ctx.FunctionCallReceiverTrail.len() - 1);
                let trail_last = trail_last.clone();
                let trail_last = trail_last.unwrap();
                let trail_last = trail_last.clone();

                let enclosing_ident = _ctx.enclosing_type_identifier().clone();
                let enclosing_ident = enclosing_ident.unwrap_or_default();
                let enclosing_ident = enclosing_ident.token;

                let scope = _ctx.ScopeContext.clone();
                let scope = scope.unwrap_or(ScopeContext {
                    parameters: vec![],
                    local_variables: vec![],
                    counter: 0,
                });

                let d_type = _ctx.environment.get_expression_type(
                    trail_last,
                    &enclosing_ident,
                    vec![],
                    vec![],
                    scope.clone(),
                );

                d_type.name()
            };

            let mangled = mangle_function_call_name(&f_call, _ctx);
            if mangled.is_some() {
                let mangled = mangled.unwrap();
                println!("MAngled is");
                println!("{:?}", mangled.clone());
                println!("{:?}", f_call.identifier.line_info.clone());
                _t.mangled_identifier = Option::from(Identifier {
                    token: mangled.clone(),
                    enclosing_type: None,
                    line_info: Default::default(),
                });
                f_call.mangled_identifier = Option::from(Identifier {
                    token: mangled,
                    enclosing_type: None,
                    line_info: Default::default(),
                });
            }

            if _ctx.environment.is_struct_declared(&enclosing_type) {
                if !is_global_function_call(f_call.clone(), _ctx) {
                    let receiver = construct_expression(_ctx.FunctionCallReceiverTrail.clone());
                    let inout_expression = InoutExpression {
                        ampersand_token: "".to_string(),
                        expression: Box::new(receiver),
                    };
                    f_call.arguments.insert(
                        0,
                        FunctionArgument {
                            identifier: None,
                            expression: Expression::InoutExpression(inout_expression),
                        },
                    );
                    *_t = f_call.clone();
                }
            }
        }

        println!("{:?}", _ctx.environment.is_initiliase_call(f_call.clone()));
        println!("{:?}", f_call.mangled_identifier);
        let scope = _ctx.ScopeContext.clone();
        let scope = scope.unwrap_or(ScopeContext {
            parameters: vec![],
            local_variables: vec![],
            counter: 0,
        });

        let enclosing = if f_call.identifier.enclosing_type.is_some() {
            let i = f_call.identifier.enclosing_type.clone();
            i.unwrap()
        } else {
            let i = _ctx.enclosing_type_identifier().clone();
            let i = i.unwrap_or_default();
            i.token
        };

        let match_result =
            _ctx.environment
                .match_function_call(f_call.clone(), &enclosing, vec![], scope.clone());

        let mut is_external = false;
        if let FunctionCallMatchResult::MatchedFunction(m) = match_result.clone() {
            is_external = m.declaration.is_external;
        }

        println!("{:?}", f_call.mangled_identifier);
        let mut f_call = f_call.clone();
        println!("{:?}", f_call.mangled_identifier);
        if !is_external {
            let mut offset = 0;
            let mut index = 0;
            let args = f_call.arguments.clone();
            for arg in args {
                let mut is_mem = SelfExpression;
                let param_name = scope.enclosing_parameter(arg.expression.clone(), &enclosing);

                if param_name.is_some() {
                    let param_name = param_name.unwrap();
                    unimplemented!()
                }

                let arg_type = _ctx.environment.get_expression_type(
                    arg.expression.clone(),
                    &enclosing,
                    vec![],
                    vec![],
                    scope.clone(),
                );

                if let Type::Error = arg_type.clone() {
                    panic!("Can not handle Type Error")
                }

                if !arg_type.is_dynamic_type() {
                    continue;
                }

                if arg.expression.enclosing_identifier().is_some() {
                    let arg_enclosing = arg.expression.enclosing_identifier().clone();
                    let arg_enclosing = arg_enclosing.unwrap();

                    if scope.contains_variable_declaration(arg_enclosing.token.clone()) {
                        is_mem = Expression::Literal(Literal::BooleanLiteral(true));
                    } else if scope.contains_parameter_declaration(arg_enclosing.token.clone()) {
                        is_mem = Expression::Identifier(Identifier {
                            token: mangle_mem(arg_enclosing.token.clone()),
                            enclosing_type: None,
                            line_info: Default::default(),
                        });
                    }
                } else if let Expression::InoutExpression(i) = arg.expression.clone() {
                    if let Expression::SelfExpression = *i.expression.clone() {
                        is_mem = Expression::Identifier(Identifier {
                            token: mangle_mem("QuartzSelf".to_string()),
                            enclosing_type: None,
                            line_info: Default::default(),
                        });
                    }
                } else {
                    is_mem = Expression::Literal(Literal::BooleanLiteral(false));
                }

                f_call.arguments.insert(
                    (index + offset + 1),
                    FunctionArgument {
                        identifier: None,
                        expression: is_mem,
                    },
                );
                offset += 1;
                index += 1;
            }
            println!("{:?}", _t.mangled_identifier);
            *_t = f_call;
            println!("{:?}", _t.mangled_identifier);
        }

        _ctx.FunctionCallReceiverTrail = vec![];

        println!("{:?}", _t.mangled_identifier);

        Ok(())
    }

    fn start_struct_member(&mut self, _t: &mut StructMember, _ctx: &mut Context) -> VResult {
        let member = _t.clone();

        if let StructMember::SpecialDeclaration(s) = member {
            if s.is_init() {
                let mut new_s = s.clone();
                let default_assignments = default_assignments(_ctx);
                for d in default_assignments {
                    new_s.body.insert(0, d);
                }
                let new_init = new_s.as_function_declaration();
                *_t = StructMember::FunctionDeclaration(new_init);
            }
        }
        Ok(())
    }
}

pub fn mangle_solidity_function_name(
    string: String,
    param_type: Vec<Type>,
    t: &TypeIdentifier,
) -> String {
    let parameters: Vec<String> = param_type.into_iter().map(|p| p.name()).collect();
    let dollar = if parameters.is_empty() {
        format!("")
    } else {
        format!("$")
    };
    let parameters = parameters.join("_");

    format!(
        "{t}${name}{dollar}{parameters}",
        t = t,
        name = string,
        dollar = dollar,
        parameters = parameters
    )
}

pub fn mangle_function_call_name(function_call: &FunctionCall, ctx: &Context) -> Option<String> {
    if !is_ether_runtime_function_call(function_call) {
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

        match match_result.clone() {
            FunctionCallMatchResult::MatchedFunction(fi) => {
                let declaration = fi.declaration.clone();
                let param_types = fi.get_parameter_types().clone();

                Some(mangle_solidity_function_name(
                    declaration.head.identifier.token.clone(),
                    param_types,
                    &enclosing_type,
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
                let declaration = i.declaration.clone();
                let param_types = declaration.head.parameters.clone();
                let param_types: Vec<Type> =
                    param_types.into_iter().map(|p| p.type_assignment).collect();

                Some(mangle_solidity_function_name(
                    "init".to_string(),
                    param_types,
                    &function_call.identifier.token.clone(),
                ))
            }
            FunctionCallMatchResult::MatchedFallback(_) => unimplemented!(),
            FunctionCallMatchResult::MatchedGlobalFunction(fi) => {
                let param_types = fi.get_parameter_types().clone();

                Some(mangle_solidity_function_name(
                    function_call.identifier.token.clone(),
                    param_types,
                    &"Quartz_Global".to_string(),
                ))
            }
            FunctionCallMatchResult::Failure(lol) => None,
        }
    } else {
        Some(function_call.identifier.token.clone())
    }
}

pub fn is_ether_runtime_function_call(function_call: &FunctionCall) -> bool {
    let ident = function_call.identifier.token.clone();
    ident.starts_with("Quartz$")
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

pub fn construct_parameter(name: String, t: Type) -> Parameter {
    let identifier = Identifier {
        token: name,
        enclosing_type: None,
        line_info: Default::default(),
    };
    Parameter {
        identifier,
        type_assignment: t,
        expression: None,
        line_info: Default::default(),
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

    println!("MATCH THE GLOBAL TING");
    let result =
        ctx.environment
            .match_function_call(function_call, &enclosing, caller_protections, scope);
    println!("AFTER MATCHING ");
    println!("{:?}", result.clone());

    if let FunctionCallMatchResult::MatchedGlobalFunction(_) = result {
        return true;
    }

    return false;
}

pub fn default_assignments(ctx: &Context) -> Vec<Statement> {
    let enclosing = ctx.enclosing_type_identifier().clone();
    let enclosing = enclosing.unwrap_or_default();
    let enclosing = enclosing.token;

    let properties_in_enclosing = ctx.environment.property_declarations(&enclosing);
    let properties_in_enclosing: Vec<Property> = properties_in_enclosing
        .into_iter()
        .filter(|p| p.get_value().is_some())
        .collect();

    let statements = properties_in_enclosing
        .into_iter()
        .map(|p| {
            let mut identifier = p.get_identifier();
            identifier.enclosing_type = Some(enclosing.clone());
            Statement::Expression(Expression::BinaryExpression(BinaryExpression {
                lhs_expression: Box::new(Expression::Identifier(identifier)),
                rhs_expression: Box::new(p.get_value().unwrap()),
                op: BinOp::Equal,
                line_info: Default::default(),
            }))
        })
        .collect();

    return statements;
}
