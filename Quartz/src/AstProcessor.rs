use super::context::*;
use super::environment::*;
use super::MoveCodeGen;
use super::SemanticAnalysis::*;
use super::SolidityCodeGen;
use super::TypeAssigner::*;
use super::TypeChecker::*;
use super::AST::*;
use crate::MoveCodeGen::MovePreProcessor;
use crate::SolidityCodeGen::{generate, SolidityPreProcessor};

pub fn process_ast(mut module: Module, environment: Environment, target: Target) {
    let type_assigner = &mut TypeAssigner {};
    let semantic_analysis = &mut SemanticAnalysis {};
    let type_checker = &mut TypeChecker {};
    let solidity_preprocessor = &mut SolidityPreProcessor::SolidityPreProcessor {};
    let move_preprocessor = &mut MovePreProcessor::MovePreProcessor {};
    let context = &mut Context {
        environment,
        ..Default::default()
    };

    let result = module.visit(type_assigner, context);

    match result {
        Ok(_) => {}
        Err(e) => return,
    }

    let result = module.visit(semantic_analysis, context);

    match result {
        Ok(_) => {}
        Err(e) => return,
    }

    let result = module.visit(type_checker, context);

    match result {
        Ok(_) => {}
        Err(e) => return,
    }

    if let Target::Move = target {
        let result = module.visit(move_preprocessor, context);

        match result {
            Ok(_) => {}
            Err(e) => return,
        }

        let result = MoveCodeGen::generate(module, context);
    } else {
        let result = module.visit(solidity_preprocessor, context);

        match result {
            Ok(_) => {}
            Err(e) => return,
        }

        let result = SolidityCodeGen::generate(module, context);
    }
}

pub enum Target {
    Move,
    Ether,
}
