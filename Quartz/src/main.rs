mod AST;
mod AstProcessor;
mod MoveCodeGen;
mod Parser;
mod SemanticAnalysis;
mod SolidityCodeGen;
mod TypeAssigner;
mod TypeChecker;
mod context;
mod environment;
mod visitor;
use crate::AstProcessor::Target;
use nom_locate::LocatedSpan;
use std::env;
use std::fs::File;
use std::io::prelude::*;
use AST::Visitable;

fn main() {
    let args: Vec<String> = env::args().collect();
    println!("{:?}", args);

    if args.len() < 3 {
        panic!("Incorrect number of Arguments supplied, Expecting 2 arguments");
    }

    let target = &args[1];
    let target = if target == "libra" {
        Target::Move
    } else if target == "ether" {
        Target::Ether
    } else {
        panic!("Incorrect Target Argument specified, expecting \"ether\" or \"libra\"");
    };

    let filename = &args[2];

    let mut file =
        File::open(filename).expect(&*format!("Unable to open file at path {} ", filename));

    let mut contents = String::new();
    file.read_to_string(&mut contents)
        .expect("Unable to read the file");
    let mut program = contents.clone();

    if let Target::Move = target {
        let mut file =
            File::open("src/stdlib/libra/libra.quartz").expect("Unable to open libra stdlib file ");
        let mut libra = String::new();
        file.read_to_string(&mut libra)
            .expect("Unable to read the stdlib Libra file");

        let mut file = File::open("src/stdlib/libra/global.quartz")
            .expect("Unable to open libra stdlib file ");
        let mut global = String::new();
        file.read_to_string(&mut global)
            .expect("Unable to read the stdlib global file");

        program = format!(
            "{libra} \n {global} \n {program}",
            libra = libra,
            global = global,
            program = program
        )
    } else {
        let mut file =
            File::open("src/stdlib/ether/wei.quartz").expect("Unable to open libra stdlib file ");
        let mut ether = String::new();
        file.read_to_string(&mut ether)
            .expect("Unable to read the stdlib Libra file");

        let mut file = File::open("src/stdlib/ether/global.quartz")
            .expect("Unable to open quartz stdlib file ");
        let mut global = String::new();
        file.read_to_string(&mut global)
            .expect("Unable to read the stdlib global file");

        program = format!(
            "{ether} \n {global} \n {program}",
            ether = ether,
            global = global,
            program = program
        )
    }
    let (module, environment) = Parser::parse_program(&program);

    if module.is_none() {
        println!("Parse Error");
    }

    if module.is_some() {
        let module = module.unwrap();
        let process_result = AstProcessor::process_ast(module, environment, target);
    }
}
