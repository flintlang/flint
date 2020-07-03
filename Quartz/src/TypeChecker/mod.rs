use super::context::*;
use super::environment::*;
use super::visitor::*;
use super::AST::*;

pub struct TypeChecker {}

impl Visitor for TypeChecker {
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

    fn start_contract_behaviour_declaration(
        &mut self,
        _t: &mut ContractBehaviourDeclaration,
        _ctx: &mut Context,
    ) -> VResult {
        let states = _t.states.clone();
        for state in states {
            if _ctx
                .environment
                .is_state_declared(&state.identifier.token, &_t.identifier.token)
                || state.is_any()
            {
            } else {
                println!("Invalid state used")
            }
        }

        Ok(())
    }

    fn start_binary_expression(
        &mut self,
        _t: &mut BinaryExpression,
        _ctx: &mut Context,
    ) -> VResult {
        let enclosing = _ctx.enclosing_type_identifier().unwrap_or_default();
        let enclosing = enclosing.token;
        let lhs_type = _ctx.environment.get_expression_type(
            *_t.lhs_expression.clone(),
            &enclosing,
            vec![],
            vec![],
            _ctx.ScopeContext.clone().unwrap_or_default(),
        );
        match _t.op {
            BinOp::Dot => _t.rhs_expression.assign_enclosing_type(&lhs_type.name()),
            BinOp::Equal => {}
            _ => {}
        }
        Ok(())
    }
}
