use super::context::*;
use super::AST::*;

pub trait Visitor {
    fn start_module(&mut self, _t: &mut Module, _ctx: &mut Context) -> VResult {
        Ok(())
    }

    fn finish_module(&mut self, _t: &mut Module, _ctx: &mut Context) -> VResult {
        Ok(())
    }

    fn start_top_level_declaration(
        &mut self,
        _t: &mut TopLevelDeclaration,
        _ctx: &mut Context,
    ) -> VResult {
        Ok(())
    }

    fn finish_top_level_declaration(
        &mut self,
        _t: &mut TopLevelDeclaration,
        _ctx: &mut Context,
    ) -> VResult {
        Ok(())
    }

    fn start_contract_declaration(
        &mut self,
        _t: &mut ContractDeclaration,
        _ctx: &mut Context,
    ) -> VResult {
        Ok(())
    }

    fn finish_contract_declaration(
        &mut self,
        _t: &mut ContractDeclaration,
        _ctx: &mut Context,
    ) -> VResult {
        Ok(())
    }

    fn start_contract_member(&mut self, _t: &mut ContractMember, _ctx: &mut Context) -> VResult {
        Ok(())
    }

    fn finish_contract_member(&mut self, _t: &mut ContractMember, _ctx: &mut Context) -> VResult {
        Ok(())
    }

    fn start_contract_behaviour_declaration(
        &mut self,
        _t: &mut ContractBehaviourDeclaration,
        _ctx: &mut Context,
    ) -> VResult {
        Ok(())
    }

    fn finish_contract_behaviour_declaration(
        &mut self,
        _t: &mut ContractBehaviourDeclaration,
        _ctx: &mut Context,
    ) -> VResult {
        Ok(())
    }

    fn start_contract_behaviour_member(
        &mut self,
        _t: &mut ContractBehaviourMember,
        _ctx: &mut Context,
    ) -> VResult {
        Ok(())
    }

    fn finish_contract_behaviour_member(
        &mut self,
        _t: &mut ContractBehaviourMember,
        _ctx: &mut Context,
    ) -> VResult {
        Ok(())
    }

    fn start_struct_declaration(
        &mut self,
        _t: &mut StructDeclaration,
        _ctx: &mut Context,
    ) -> VResult {
        Ok(())
    }

    fn finish_struct_declaration(
        &mut self,
        _t: &mut StructDeclaration,
        _ctx: &mut Context,
    ) -> VResult {
        Ok(())
    }

    fn start_struct_member(&mut self, _t: &mut StructMember, _ctx: &mut Context) -> VResult {
        Ok(())
    }

    fn finish_struct_member(&mut self, _t: &mut StructMember, _ctx: &mut Context) -> VResult {
        Ok(())
    }

    fn start_asset_declaration(
        &mut self,
        _t: &mut AssetDeclaration,
        _ctx: &mut Context,
    ) -> VResult {
        Ok(())
    }

    fn finish_asset_declaration(
        &mut self,
        _t: &mut AssetDeclaration,
        _ctx: &mut Context,
    ) -> VResult {
        Ok(())
    }

    fn start_trait_declaration(
        &mut self,
        _t: &mut TraitDeclaration,
        _ctx: &mut Context,
    ) -> VResult {
        Ok(())
    }

    fn finish_trait_declaration(
        &mut self,
        _t: &mut TraitDeclaration,
        _ctx: &mut Context,
    ) -> VResult {
        Ok(())
    }

    fn start_enum_declaration(&mut self, _t: &mut EnumDeclaration, _ctx: &mut Context) -> VResult {
        Ok(())
    }

    fn finish_enum_declaration(&mut self, _t: &mut EnumDeclaration, _ctx: &mut Context) -> VResult {
        Ok(())
    }

    fn start_enum_member(&mut self, _t: &mut EnumMember, _ctx: &mut Context) -> VResult {
        Ok(())
    }

    fn finish_enum_member(&mut self, _t: &mut EnumMember, _ctx: &mut Context) -> VResult {
        Ok(())
    }

    fn start_variable_declaration(
        &mut self,
        _t: &mut VariableDeclaration,
        _ctx: &mut Context,
    ) -> VResult {
        Ok(())
    }

    fn finish_variable_declaration(
        &mut self,
        _t: &mut VariableDeclaration,
        _ctx: &mut Context,
    ) -> VResult {
        Ok(())
    }

    fn start_function_declaration(
        &mut self,
        _t: &mut FunctionDeclaration,
        _ctx: &mut Context,
    ) -> VResult {
        Ok(())
    }

    fn finish_function_declaration(
        &mut self,
        _t: &mut FunctionDeclaration,
        _ctx: &mut Context,
    ) -> VResult {
        Ok(())
    }

    fn start_function_signature_declaration(
        &mut self,
        _t: &mut FunctionSignatureDeclaration,
        _ctx: &mut Context,
    ) -> VResult {
        Ok(())
    }

    fn finish_function_signature_declaration(
        &mut self,
        _t: &mut FunctionSignatureDeclaration,
        _ctx: &mut Context,
    ) -> VResult {
        Ok(())
    }

    fn start_special_declaration(
        &mut self,
        _t: &mut SpecialDeclaration,
        _ctx: &mut Context,
    ) -> VResult {
        Ok(())
    }

    fn finish_special_declaration(
        &mut self,
        _t: &mut SpecialDeclaration,
        _ctx: &mut Context,
    ) -> VResult {
        Ok(())
    }

    fn start_special_signature_declaration(
        &mut self,
        _t: &mut SpecialSignatureDeclaration,
        _ctx: &mut Context,
    ) -> VResult {
        Ok(())
    }

    fn finish_special_signature_declaration(
        &mut self,
        _t: &mut SpecialSignatureDeclaration,
        _ctx: &mut Context,
    ) -> VResult {
        Ok(())
    }

    fn start_statement(&mut self, _t: &mut Statement, _ctx: &mut Context) -> VResult {
        Ok(())
    }

    fn finish_statement(&mut self, _t: &mut Statement, _ctx: &mut Context) -> VResult {
        Ok(())
    }

    fn start_do_catch_statement(
        &mut self,
        _t: &mut DoCatchStatement,
        _ctx: &mut Context,
    ) -> VResult {
        Ok(())
    }

    fn finish_do_catch_statement(
        &mut self,
        _t: &mut DoCatchStatement,
        _ctx: &mut Context,
    ) -> VResult {
        Ok(())
    }

    fn start_if_statement(&mut self, _t: &mut IfStatement, _ctx: &mut Context) -> VResult {
        Ok(())
    }

    fn finish_if_statement(&mut self, _t: &mut IfStatement, _ctx: &mut Context) -> VResult {
        Ok(())
    }

    fn start_for_statement(&mut self, _t: &mut ForStatement, _ctx: &mut Context) -> VResult {
        Ok(())
    }

    fn finish_for_statement(&mut self, _t: &mut ForStatement, _ctx: &mut Context) -> VResult {
        Ok(())
    }

    fn start_emit_statement(&mut self, _t: &mut EmitStatement, _ctx: &mut Context) -> VResult {
        Ok(())
    }

    fn finish_emit_statement(&mut self, _t: &mut EmitStatement, _ctx: &mut Context) -> VResult {
        Ok(())
    }

    fn start_identifier(&mut self, _t: &mut Identifier, _ctx: &mut Context) -> VResult {
        Ok(())
    }

    fn finish_identifier(&mut self, _t: &mut Identifier, _ctx: &mut Context) -> VResult {
        Ok(())
    }

    fn start_range_expression(&mut self, _t: &mut RangeExpression, _ctx: &mut Context) -> VResult {
        Ok(())
    }

    fn finish_range_expression(&mut self, _t: &mut RangeExpression, _ctx: &mut Context) -> VResult {
        Ok(())
    }

    fn start_caller_protection(
        &mut self,
        _t: &mut CallerProtection,
        _ctx: &mut Context,
    ) -> VResult {
        Ok(())
    }

    fn finish_caller_protection(
        &mut self,
        _t: &mut CallerProtection,
        _ctx: &mut Context,
    ) -> VResult {
        Ok(())
    }

    fn start_conformance(&mut self, _t: &mut Conformance, _ctx: &mut Context) -> VResult {
        Ok(())
    }

    fn finish_conformance(&mut self, _t: &mut Conformance, _ctx: &mut Context) -> VResult {
        Ok(())
    }

    fn start_expression(&mut self, _t: &mut Expression, _ctx: &mut Context) -> VResult {
        Ok(())
    }

    fn finish_expression(&mut self, _t: &mut Expression, _ctx: &mut Context) -> VResult {
        Ok(())
    }

    fn start_subscript_expression(
        &mut self,
        _t: &mut SubscriptExpression,
        _ctx: &mut Context,
    ) -> VResult {
        Ok(())
    }

    fn finish_subscript_expression(
        &mut self,
        _t: &mut SubscriptExpression,
        _ctx: &mut Context,
    ) -> VResult {
        Ok(())
    }

    fn start_attempt_expression(
        &mut self,
        _t: &mut AttemptExpression,
        _ctx: &mut Context,
    ) -> VResult {
        Ok(())
    }

    fn finish_attempt_expression(
        &mut self,
        _t: &mut AttemptExpression,
        _ctx: &mut Context,
    ) -> VResult {
        Ok(())
    }

    fn start_binary_expression(
        &mut self,
        _t: &mut BinaryExpression,
        _ctx: &mut Context,
    ) -> VResult {
        Ok(())
    }

    fn finish_binary_expression(
        &mut self,
        _t: &mut BinaryExpression,
        _ctx: &mut Context,
    ) -> VResult {
        Ok(())
    }

    fn start_cast_expression(&mut self, _t: &mut CastExpression, _ctx: &mut Context) -> VResult {
        Ok(())
    }

    fn finish_cast_expression(&mut self, _t: &mut CastExpression, _ctx: &mut Context) -> VResult {
        Ok(())
    }

    fn start_inout_expression(&mut self, _t: &mut InoutExpression, _ctx: &mut Context) -> VResult {
        Ok(())
    }

    fn finish_inout_expression(&mut self, _t: &mut InoutExpression, _ctx: &mut Context) -> VResult {
        Ok(())
    }

    fn start_function_call(&mut self, _t: &mut FunctionCall, _ctx: &mut Context) -> VResult {
        Ok(())
    }

    fn finish_function_call(&mut self, _t: &mut FunctionCall, _ctx: &mut Context) -> VResult {
        Ok(())
    }

    fn start_external_call(&mut self, _t: &mut ExternalCall, _ctx: &mut Context) -> VResult {
        Ok(())
    }

    fn finish_external_call(&mut self, _t: &mut ExternalCall, _ctx: &mut Context) -> VResult {
        Ok(())
    }

    fn start_return_statement(&mut self, _t: &mut ReturnStatement, _ctx: &mut Context) -> VResult {
        Ok(())
    }

    fn finish_return_statement(&mut self, _t: &mut ReturnStatement, _ctx: &mut Context) -> VResult {
        Ok(())
    }

    fn start_parameter(&mut self, _t: &mut Parameter, _ctx: &mut Context) -> VResult {
        Ok(())
    }

    fn finish_parameter(&mut self, _t: &mut Parameter, _ctx: &mut Context) -> VResult {
        Ok(())
    }

    fn start_function_argument(
        &mut self,
        _t: &mut FunctionArgument,
        _ctx: &mut Context,
    ) -> VResult {
        Ok(())
    }

    fn finish_function_argument(
        &mut self,
        _t: &mut FunctionArgument,
        _ctx: &mut Context,
    ) -> VResult {
        Ok(())
    }

    fn start_type(&mut self, _t: &mut Type, _ctx: &mut Context) -> VResult {
        Ok(())
    }

    fn finish_type(&mut self, _t: &mut Type, _ctx: &mut Context) -> VResult {
        Ok(())
    }

    fn start_array_literal(&mut self, _t: &mut ArrayLiteral, _ctx: &mut Context) -> VResult {
        Ok(())
    }

    fn finish_array_literal(&mut self, _t: &mut ArrayLiteral, _ctx: &mut Context) -> VResult {
        Ok(())
    }

    fn start_dictionary_literal(
        &mut self,
        _t: &mut DictionaryLiteral,
        _ctx: &mut Context,
    ) -> VResult {
        Ok(())
    }

    fn finish_dictionary_literal(
        &mut self,
        _t: &mut DictionaryLiteral,
        _ctx: &mut Context,
    ) -> VResult {
        Ok(())
    }
}
