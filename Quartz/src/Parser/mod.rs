use super::AST::*;

extern crate nom;
extern crate nom_locate;
use nom_locate::{position, LocatedSpan};

use crate::environment::Environment;
use nom::{branch::alt, bytes::complete::tag, combinator::map, multi::many0, sequence::preceded};
use std::collections::HashSet;

type ParseResult = (Option<Module>, Environment);

type Span<'a> = LocatedSpan<&'a str>;

pub fn parse_program(i: &str) -> ParseResult {
    let input = LocatedSpan::new(i);
    let result = parse_module(input);

    let module = match result {
        Ok((i, module)) => {
            if !i.fragment().is_empty() {
                panic!("Parser Error Parsing {:?}", i.fragment())
            };
            Some(module)
        }
        Err(_) => (None),
    };

    let mut environment = Environment {
        ..Default::default()
    };
    if module.is_some() {
        let module = module.unwrap();
        environment.build(module.clone());
        return (Option::from(module), environment);
    }
    (module, environment)
}

fn parse_module(i: Span) -> nom::IResult<Span, Module> {
    let (i, _) = whitespace(i)?;
    let (i, declarations) = many0(nom::sequence::terminated(
        parse_top_level_declaration,
        whitespace,
    ))(i)?;
    Ok((i, Module { declarations }))
}

fn parse_top_level_declaration(i: Span) -> nom::IResult<Span, TopLevelDeclaration> {
    let (i, top) = alt((
        parse_contract_declaration,
        map(parse_contract_behaviour_declaration, |c| {
            TopLevelDeclaration::ContractBehaviourDeclaration(c)
        }),
        parse_struct_declaration,
        parse_asset_declaration,
        parse_enum_declaration,
        parse_trait_declaration,
    ))(i)?;
    Ok((i, top))
}

fn plus_operator(i: Span) -> nom::IResult<Span, BinOp> {
    let (i, _) = tag("+")(i)?;
    Ok((i, BinOp::Plus))
}

fn parse_comment(i: Span) -> nom::IResult<Span, Span> {
    let (i, _) = tag("//")(i)?;
    let (i, _) = nom::combinator::opt(nom::bytes::complete::is_not("\n"))(i)?;
    let (i, _) = tag("\n")(i)?;
    Ok((i, i))
}

fn minus_operator(i: Span) -> nom::IResult<Span, BinOp> {
    let (i, _) = tag("-")(i)?;
    Ok((i, BinOp::Minus))
}

fn plus_equal_operator(i: Span) -> nom::IResult<Span, BinOp> {
    let (i, _) = tag("+=")(i)?;
    Ok((i, BinOp::PlusEqual))
}

fn minus_equal_operator(i: Span) -> nom::IResult<Span, BinOp> {
    let (i, _) = tag("-=")(i)?;
    Ok((i, BinOp::MinusEqual))
}

fn times_equal_operator(i: Span) -> nom::IResult<Span, BinOp> {
    let (i, _) = tag("*=")(i)?;
    Ok((i, BinOp::TimesEqual))
}

fn divide_equal_operator(i: Span) -> nom::IResult<Span, BinOp> {
    let (i, _) = tag("/=")(i)?;
    Ok((i, BinOp::DivideEqual))
}

fn equal_operator(i: Span) -> nom::IResult<Span, BinOp> {
    let (i, _) = tag("=")(i)?;
    Ok((i, BinOp::Equal))
}

fn dot_operator(i: Span) -> nom::IResult<Span, BinOp> {
    let (i, _) = tag(".")(i)?;
    Ok((i, BinOp::Dot))
}

fn less_than_operator(i: Span) -> nom::IResult<Span, BinOp> {
    let (i, _) = tag("<")(i)?;
    Ok((i, BinOp::LessThan))
}

fn greater_than_operator(i: Span) -> nom::IResult<Span, BinOp> {
    let (i, _) = tag(">")(i)?;
    Ok((i, BinOp::GreaterThan))
}

fn left_brace(i: Span) -> nom::IResult<Span, Span> {
    tag("{")(i)
}

fn right_brace(i: Span) -> nom::IResult<Span, Span> {
    tag("}")(i)
}

fn left_square_bracket(i: Span) -> nom::IResult<Span, Span> {
    tag("[")(i)
}

fn right_square_bracket(i: Span) -> nom::IResult<Span, Span> {
    tag("]")(i)
}

fn colon(i: Span) -> nom::IResult<Span, Span> {
    tag(":")(i)
}

fn double_colon(i: Span) -> nom::IResult<Span, Span> {
    tag("::")(i)
}

fn left_parens(i: Span) -> nom::IResult<Span, Span> {
    tag("(")(i)
}

fn right_parens(i: Span) -> nom::IResult<Span, Span> {
    tag(")")(i)
}

fn at(i: Span) -> nom::IResult<Span, Span> {
    tag("@")(i)
}

fn right_arrow(i: Span) -> nom::IResult<Span, Span> {
    tag("->")(i)
}

fn left_arrow(i: Span) -> nom::IResult<Span, Span> {
    tag("<-")(i)
}

fn comma(i: Span) -> nom::IResult<Span, Span> {
    tag(",")(i)
}

fn semi_colon(i: Span) -> nom::IResult<Span, Span> {
    tag(";")(i)
}

fn double_slash(i: Span) -> nom::IResult<Span, Span> {
    tag("//")(i)
}

fn percent(i: Span) -> nom::IResult<Span, Span> {
    tag("//")(i)
}

fn double_dot(i: Span) -> nom::IResult<Span, Span> {
    tag("..")(i)
}

fn ampersand(i: Span) -> nom::IResult<Span, Span> {
    tag("&")(i)
}

fn bang(i: Span) -> nom::IResult<Span, Span> {
    tag("!")(i)
}

fn question(i: Span) -> nom::IResult<Span, Span> {
    tag("?")(i)
}

fn half_open_range(i: Span) -> nom::IResult<Span, Span> {
    tag("..<")(i)
}

fn closed_range(i: Span) -> nom::IResult<Span, Span> {
    tag("...")(i)
}

fn implies(i: Span) -> nom::IResult<Span, Span> {
    tag("==>")(i)
}

fn true_literal(i: Span) -> nom::IResult<Span, Literal> {
    let (i, _) = tag("true")(i)?;
    Ok((i, Literal::BooleanLiteral(true)))
}

fn false_literal(i: Span) -> nom::IResult<Span, Literal> {
    let (i, _) = tag("false")(i)?;
    Ok((i, Literal::BooleanLiteral(false)))
}

fn address_literal(i: Span) -> nom::IResult<Span, Literal> {
    let (i, _) = tag("0x")(i)?;
    let (i, address) = nom::character::complete::hex_digit1(i)?;
    let string = format!("0x{}", address.to_string());
    Ok((i, Literal::AddressLiteral(string)))
}

fn string_literal(i: Span) -> nom::IResult<Span, Literal> {
    let (i, _) = tag("\"")(i)?;
    let (i, string) = nom::bytes::complete::take_until("\"")(i)?;
    let (i, _) = tag("\"")(i)?;
    Ok((i, Literal::StringLiteral(string.to_string())))
}

fn integer(input: Span) -> nom::IResult<Span, Literal> {
    let (i, int) = nom::combinator::map_res(nom::character::complete::digit1, |s: Span| {
        s.fragment().parse::<u64>()
    })(input)?;
    Ok((i, Literal::IntLiteral(int)))
}

fn float(input: Span) -> nom::IResult<Span, Literal> {
    let (i, float) = nom::combinator::map_res(
        nom::combinator::recognize(nom::sequence::delimited(
            nom::character::complete::digit1,
            tag("."),
            nom::character::complete::digit1,
        )),
        |s: Span| s.fragment().parse::<f64>(),
    )(input)?;
    Ok((i, Literal::FloatLiteral(float)))
}

fn parse_identifier(i: Span) -> nom::IResult<Span, Identifier> {
    let line_info = LineInfo {
        line: i.location_line(),
        offset: i.location_offset(),
    };
    let (i, head) = alt((nom::character::complete::alpha1, tag("_")))(i)?;
    let (i, tail) = nom::combinator::recognize(many0(alt((
        nom::character::complete::alphanumeric1,
        tag("_"),
        tag("$"),
    ))))(i)?;
    let head = head.to_string();
    let token = head + tail.fragment();
    let identifier = Identifier {
        token,
        enclosing_type: None,
        line_info,
    };
    Ok((i, identifier))
}

fn parse_identifier_list(i: Span) -> nom::IResult<Span, Vec<Identifier>> {
    nom::multi::separated_list(tag(","), preceded(whitespace, parse_identifier))(i)
}

fn parse_identifier_group(i: Span) -> nom::IResult<Span, Vec<Identifier>> {
    let (i, _) = left_parens(i)?;
    let (i, identifier_list) = parse_identifier_list(i)?;
    let (i, _) = right_parens(i)?;
    Ok((i, identifier_list))
}

fn parse_parameter_list(i: Span) -> nom::IResult<Span, Vec<Parameter>> {
    let (i, _) = left_parens(i)?;
    let (i, vector) =
        nom::multi::separated_list(tag(","), preceded(whitespace, parse_parameter))(i)?;
    let (i, _) = right_parens(i)?;
    Ok((i, vector))
}

fn parse_parameter(i: Span) -> nom::IResult<Span, Parameter> {
    let line_info = LineInfo {
        line: i.location_line(),
        offset: i.location_offset(),
    };
    let (i, identifier) = parse_identifier(i)?;
    let (i, type_assigned) = parse_type_annotation(i)?;
    let (i, equal) = nom::combinator::opt(preceded(whitespace, equal_operator))(i)?;
    if equal.is_none() {
        let parameter = Parameter {
            identifier,
            type_assignment: type_assigned.type_assigned,
            expression: None,
            line_info,
        };
        return Ok((i, parameter));
    }
    let (i, expression) = preceded(whitespace, parse_expression)(i)?;
    let parameter = Parameter {
        identifier,
        type_assignment: type_assigned.type_assigned,
        expression: Some(expression),
        line_info,
    };
    Ok((i, parameter))
}

fn parse_type_annotation(i: Span) -> nom::IResult<Span, TypeAnnotation> {
    let (i, colon) = colon(i)?;
    let (i, _) = whitespace(i)?;
    let (i, type_assigned) = preceded(whitespace, parse_type)(i)?;
    let type_annotation = TypeAnnotation {
        type_assigned,
        colon: colon.to_string(),
    };
    Ok((i, type_annotation))
}

fn parse_type(i: Span) -> nom::IResult<Span, Type> {
    alt((
        parse_fixed_array_type,
        parse_array_type,
        parse_dictionary_type,
        parse_self_type,
        parse_basic_type,
        parse_inout_type,
        parse_solidity_type,
        parse_identifier_type,
    ))(i)
}

fn parse_self_type(i: Span) -> nom::IResult<Span, Type> {
    let (i, _) = tag("Self")(i)?;
    Ok((i, Type::SelfType))
}

fn parse_solidity_type(i: Span) -> nom::IResult<Span, Type> {
    alt((
        parse_solidity_type_first_part,
        parse_solidity_type_second_part,
        parse_solidity_type_third_part,
        parse_solidity_type_fourth_part,
        parse_solidity_type_fifth_part,
        map(tag("address"), |_| Type::Solidity(SolidityType::address)),
        map(tag("string"), |_| Type::Solidity(SolidityType::string)),
        map(tag("bool"), |_| Type::Solidity(SolidityType::bool)),
    ))(i)
}

fn parse_solidity_type_first_part(i: Span) -> nom::IResult<Span, Type> {
    alt((
        map(tag("int8"), |_| Type::Solidity(SolidityType::int8)),
        map(tag("int16"), |_| Type::Solidity(SolidityType::int16)),
        map(tag("int24"), |_| Type::Solidity(SolidityType::int24)),
        map(tag("int32"), |_| Type::Solidity(SolidityType::int32)),
        map(tag("int40"), |_| Type::Solidity(SolidityType::int40)),
        map(tag("int48"), |_| Type::Solidity(SolidityType::int48)),
        map(tag("int56"), |_| Type::Solidity(SolidityType::int56)),
        map(tag("int64"), |_| Type::Solidity(SolidityType::int64)),
        map(tag("int72"), |_| Type::Solidity(SolidityType::int72)),
        map(tag("int80"), |_| Type::Solidity(SolidityType::int80)),
        map(tag("int88"), |_| Type::Solidity(SolidityType::int88)),
        map(tag("int96"), |_| Type::Solidity(SolidityType::int96)),
        map(tag("int104"), |_| Type::Solidity(SolidityType::int104)),
        map(tag("int112"), |_| Type::Solidity(SolidityType::int112)),
        map(tag("int120"), |_| Type::Solidity(SolidityType::int120)),
    ))(i)
}

fn parse_solidity_type_second_part(i: Span) -> nom::IResult<Span, Type> {
    alt((
        map(tag("int128"), |_| Type::Solidity(SolidityType::int128)),
        map(tag("int136"), |_| Type::Solidity(SolidityType::int136)),
        map(tag("int144"), |_| Type::Solidity(SolidityType::int144)),
        map(tag("int152"), |_| Type::Solidity(SolidityType::int152)),
        map(tag("int160"), |_| Type::Solidity(SolidityType::int160)),
        map(tag("int168"), |_| Type::Solidity(SolidityType::int168)),
        map(tag("int176"), |_| Type::Solidity(SolidityType::int176)),
        map(tag("int184"), |_| Type::Solidity(SolidityType::int184)),
        map(tag("int192"), |_| Type::Solidity(SolidityType::int192)),
        map(tag("int200"), |_| Type::Solidity(SolidityType::int200)),
        map(tag("int208"), |_| Type::Solidity(SolidityType::int208)),
        map(tag("int216"), |_| Type::Solidity(SolidityType::int216)),
        map(tag("int224"), |_| Type::Solidity(SolidityType::int224)),
        map(tag("int232"), |_| Type::Solidity(SolidityType::int232)),
    ))(i)
}

fn parse_solidity_type_third_part(i: Span) -> nom::IResult<Span, Type> {
    alt((
        map(tag("int240"), |_| Type::Solidity(SolidityType::int240)),
        map(tag("int248"), |_| Type::Solidity(SolidityType::int248)),
        map(tag("int256"), |_| Type::Solidity(SolidityType::int256)),
        map(tag("uint8"), |_| Type::Solidity(SolidityType::uint8)),
        map(tag("uint16"), |_| Type::Solidity(SolidityType::uint16)),
        map(tag("uint24"), |_| Type::Solidity(SolidityType::uint24)),
        map(tag("uint32"), |_| Type::Solidity(SolidityType::uint32)),
        map(tag("uint40"), |_| Type::Solidity(SolidityType::uint40)),
        map(tag("uint48"), |_| Type::Solidity(SolidityType::uint48)),
        map(tag("uint56"), |_| Type::Solidity(SolidityType::uint56)),
        map(tag("uint64"), |_| Type::Solidity(SolidityType::uint64)),
        map(tag("uint72"), |_| Type::Solidity(SolidityType::uint72)),
        map(tag("uint80"), |_| Type::Solidity(SolidityType::uint80)),
        map(tag("uint88"), |_| Type::Solidity(SolidityType::uint88)),
    ))(i)
}

fn parse_solidity_type_fourth_part(i: Span) -> nom::IResult<Span, Type> {
    alt((
        map(tag("uint96"), |_| Type::Solidity(SolidityType::uint96)),
        map(tag("uint104"), |_| Type::Solidity(SolidityType::uint104)),
        map(tag("uint112"), |_| Type::Solidity(SolidityType::uint112)),
        map(tag("uint120"), |_| Type::Solidity(SolidityType::uint120)),
        map(tag("uint128"), |_| Type::Solidity(SolidityType::uint128)),
        map(tag("uint136"), |_| Type::Solidity(SolidityType::uint136)),
        map(tag("uint144"), |_| Type::Solidity(SolidityType::uint144)),
        map(tag("uint152"), |_| Type::Solidity(SolidityType::uint152)),
        map(tag("uint160"), |_| Type::Solidity(SolidityType::uint160)),
        map(tag("uint168"), |_| Type::Solidity(SolidityType::uint168)),
        map(tag("uint176"), |_| Type::Solidity(SolidityType::uint176)),
        map(tag("uint184"), |_| Type::Solidity(SolidityType::uint184)),
    ))(i)
}

fn parse_solidity_type_fifth_part(i: Span) -> nom::IResult<Span, Type> {
    alt((
        map(tag("uint192"), |_| Type::Solidity(SolidityType::uint192)),
        map(tag("uint200"), |_| Type::Solidity(SolidityType::uint200)),
        map(tag("uint208"), |_| Type::Solidity(SolidityType::uint208)),
        map(tag("uint216"), |_| Type::Solidity(SolidityType::uint216)),
        map(tag("uint224"), |_| Type::Solidity(SolidityType::uint224)),
        map(tag("uint232"), |_| Type::Solidity(SolidityType::uint232)),
        map(tag("uint240"), |_| Type::Solidity(SolidityType::uint240)),
        map(tag("uint248"), |_| Type::Solidity(SolidityType::uint248)),
        map(tag("uint256"), |_| Type::Solidity(SolidityType::uint256)),
    ))(i)
}

fn parse_identifier_type(i: Span) -> nom::IResult<Span, Type> {
    let (i, identifier) = parse_identifier(i)?;
    if is_basic_type(identifier.token.as_str()) {
        let basic_type = match identifier.token.as_str() {
            "Int" => Type::Int,
            "Address" => Type::Address,
            "Bool" => Type::Bool,
            _ => Type::Address,
        };
        return Ok((i, basic_type));
    }
    Ok((i, Type::UserDefinedType(identifier)))
}

fn parse_fixed_array_type(i: Span) -> nom::IResult<Span, Type> {
    let (i, identifier) = parse_identifier_type(i)?;
    let (i, literal) =
        nom::sequence::delimited(left_square_bracket, integer, right_square_bracket)(i)?;

    let size = match literal {
        Literal::IntLiteral(i) => i,
        _ => unimplemented!(),
    };

    let fixed_sized_array_type = FixedSizedArrayType {
        key_type: Box::new(identifier),
        size: size,
    };
    Ok((i, Type::FixedSizedArrayType(fixed_sized_array_type)))
}

fn parse_inout_type(i: Span) -> nom::IResult<Span, Type> {
    let (i, _) = tag("inout")(i)?;
    let (i, _) = whitespace(i)?;
    let (i, key_type) = parse_type(i)?;
    let inout_type = InoutType {
        key_type: Box::new(key_type),
    };
    Ok((i, Type::InoutType(inout_type)))
}

fn parse_array_type(i: Span) -> nom::IResult<Span, Type> {
    let (i, key_type) =
        nom::sequence::delimited(left_square_bracket, parse_type, right_square_bracket)(i)?;
    let array_type = ArrayType {
        key_type: Box::new(key_type),
    };
    Ok((i, Type::ArrayType(array_type)))
}

fn parse_dictionary_type(i: Span) -> nom::IResult<Span, Type> {
    let (i, _) = left_square_bracket(i)?;
    let (i, key_type) = parse_type(i)?;
    let (i, _) = colon(i)?;
    let (i, _) = whitespace(i)?;
    let (i, value_type) = parse_type(i)?;
    let (i, _) = right_square_bracket(i)?;
    let dictionary_type = DictionaryType {
        key_type: Box::new(key_type),
        value_type: Box::new(value_type),
    };
    Ok((i, Type::DictionaryType(dictionary_type)))
}

fn parse_basic_type(i: Span) -> nom::IResult<Span, Type> {
    let (i, base_type) = alt((
        map(tag("Bool"), |_| Type::Bool),
        map(tag("Int"), |_| Type::Int),
        map(tag("String"), |_| Type::String),
        map(tag("Address"), |_| Type::Address),
    ))(i)?;
    Ok((i, base_type))
}
pub fn parse_expression(i: Span) -> nom::IResult<Span, Expression> {
    alt((
        map(parse_inout_expression, |inout| {
            Expression::InoutExpression(inout)
        }),
        map(parse_external_call, |e| Expression::ExternalCall(e)),
        map(parse_cast_expression, |c| Expression::CastExpression(c)),
        map(parse_binary_expression, |be| {
            Expression::BinaryExpression(be)
        }),
        map(tag("self"), |_| Expression::SelfExpression),
        map(parse_subscript_expression, |s| {
            Expression::SubscriptExpression(s)
        }),
        map(parse_function_call, |f| Expression::FunctionCall(f)),
        map(parse_variable_declaration, |v| {
            Expression::VariableDeclaration(v)
        }),
        map(parse_literal, |l| Expression::Literal(l)),
        map(parse_identifier, |i| Expression::Identifier(i)),
        map(parse_bracketed_expression, |b| {
            Expression::BracketedExpression(b)
        }),
        map(parse_array_literal, |a| Expression::ArrayLiteral(a)),
        map(parse_dictionary_literal, |d| {
            Expression::DictionaryLiteral(d)
        }),
        map(parse_dictionary_empty_literal, |d| {
            Expression::DictionaryLiteral(d)
        }),
        map(parse_range_expression, |r| Expression::RangeExpression(r)),
    ))(i)
}

fn parse_expression_left(i: Span) -> nom::IResult<Span, Expression> {
    alt((
        map(parse_inout_expression, |inout| {
            Expression::InoutExpression(inout)
        }),
        map(parse_external_call, |e| Expression::ExternalCall(e)),
        map(parse_cast_expression, |c| Expression::CastExpression(c)),
        map(tag("self"), |_| Expression::SelfExpression),
        map(parse_subscript_expression, |s| {
            Expression::SubscriptExpression(s)
        }),
        map(parse_function_call, |f| Expression::FunctionCall(f)),
        map(parse_variable_declaration, |v| {
            Expression::VariableDeclaration(v)
        }),
        map(parse_literal, |l| Expression::Literal(l)),
        map(parse_identifier, |i| Expression::Identifier(i)),
        map(parse_bracketed_expression, |b| {
            Expression::BracketedExpression(b)
        }),
        map(parse_array_literal, |a| Expression::ArrayLiteral(a)),
        map(parse_dictionary_empty_literal, |a| {
            Expression::DictionaryLiteral(a)
        }),
        map(parse_range_expression, |r| Expression::RangeExpression(r)),
    ))(i)
}

fn parse_subscript_expression(i: Span) -> nom::IResult<Span, SubscriptExpression> {
    let (i, identifier) = parse_identifier(i)?;
    let (i, _) = left_square_bracket(i)?;
    let (i, expression) = parse_expression(i)?;
    let (i, _) = right_square_bracket(i)?;
    let subscript_expression = SubscriptExpression {
        base_expression: identifier,
        index_expression: Box::new(expression),
    };
    Ok((i, subscript_expression))
}

fn parse_range_expression(i: Span) -> nom::IResult<Span, RangeExpression> {
    let (i, _) = left_parens(i)?;
    let (i, start_literal) = parse_literal(i)?;
    let (i, op) = alt((half_open_range, closed_range))(i)?;
    let (i, end_literal) = parse_literal(i)?;
    let (i, _) = right_parens(i)?;
    let range_expression = RangeExpression {
        start_expression: Box::new(Expression::Literal(start_literal)),
        end_expression: Box::new(Expression::Literal(end_literal)),
        op: op.to_string(),
    };
    Ok((i, range_expression))
}

fn parse_cast_expression(i: Span) -> nom::IResult<Span, CastExpression> {
    let (i, _) = tag("cast")(i)?;
    let (i, _) = whitespace(i)?;
    let (i, expression) = parse_expression(i)?;
    let (i, _) = whitespace(i)?;
    let (i, _) = tag("to")(i)?;
    let (i, _) = whitespace(i)?;
    let (i, cast_type) = parse_type(i)?;
    let cast_expression = CastExpression {
        expression: Box::new(expression),
        cast_type: cast_type,
    };
    Ok((i, cast_expression))
}

fn parse_dictionary_empty_literal(i: Span) -> nom::IResult<Span, DictionaryLiteral> {
    let (i, _) = left_square_bracket(i)?;
    let (i, _) = colon(i)?;
    let (i, _) = right_square_bracket(i)?;
    Ok((i, DictionaryLiteral { elements: vec![] }))
}

fn parse_dictionary_literal(i: Span) -> nom::IResult<Span, DictionaryLiteral> {
    let (i, elements) = nom::multi::separated_nonempty_list(
        tag(","),
        nom::sequence::terminated(
            preceded(nom::character::complete::space0, parse_dictionary_element),
            nom::character::complete::space0,
        ),
    )(i)?;
    Ok((i, DictionaryLiteral { elements }))
}

fn parse_dictionary_element(i: Span) -> nom::IResult<Span, (Expression, Expression)> {
    let (i, expression1) = parse_expression_left(i)?;
    let (i, _) = colon(i)?;
    let (i, expression2) = parse_expression(i)?;
    Ok((i, (expression1, expression2)))
}

pub fn parse_array_literal(i: Span) -> nom::IResult<Span, ArrayLiteral> {
    let (i, _) = left_square_bracket(i)?;
    let (i, expressions) = nom::multi::separated_list(
        tag(","),
        nom::sequence::terminated(
            preceded(nom::character::complete::space0, parse_expression),
            nom::character::complete::space0,
        ),
    )(i)?;
    let (i, _) = right_square_bracket(i)?;
    let array_literal = ArrayLiteral {
        elements: expressions,
    };
    Ok((i, array_literal))
}

fn parse_literal(i: Span) -> nom::IResult<Span, Literal> {
    alt((
        address_literal,
        parse_boolean_literal,
        integer,
        float,
        string_literal,
    ))(i)
}

fn parse_boolean_literal(i: Span) -> nom::IResult<Span, Literal> {
    alt((true_literal, false_literal))(i)
}

fn parse_external_call(i: Span) -> nom::IResult<Span, ExternalCall> {
    let (i, _) = tag("call")(i)?;
    let (i, _) = whitespace(i)?;
    let function_arguments = vec![];
    let (i, function_call) = parse_binary_expression(i)?;
    let external_call = ExternalCall {
        arguments: function_arguments,
        function_call,
        external_trait_name: None,
    };
    Ok((i, external_call))
}

pub fn parse_function_call(i: Span) -> nom::IResult<Span, FunctionCall> {
    let (i, identifier) = parse_identifier(i)?;
    let (i, arguments) = parse_function_call_arguments(i)?;
    let function_call = FunctionCall {
        identifier,
        arguments,
        mangled_identifier: None,
    };
    Ok((i, function_call))
}

pub fn parse_function_call_arguments(i: Span) -> nom::IResult<Span, Vec<FunctionArgument>> {
    let (i, _) = left_parens(i)?;
    let (i, arguments) = nom::multi::separated_list(
        tag(","),
        preceded(whitespace, parse_function_call_argument),
    )(i)?;
    let (i, _) = whitespace(i)?;
    let (i, _) = right_parens(i)?;
    Ok((i, arguments))
}

pub fn parse_function_call_argument(i: Span) -> nom::IResult<Span, FunctionArgument> {
    alt((
        map(
            nom::sequence::separated_pair(
                parse_identifier,
                colon,
                preceded(whitespace, parse_expression),
            ),
            |(i, e)| FunctionArgument {
                identifier: Some(i),
                expression: e,
            },
        ),
        map(parse_expression, |e| FunctionArgument {
            identifier: None,
            expression: e,
        }),
    ))(i)
}

pub fn whitespace(i: Span) -> nom::IResult<Span, Span> {
    let (i, _) = many0(alt((
        nom::character::complete::space1,
        nom::character::complete::line_ending,
        parse_comment,
    )))(i)?;
    Ok((i, LocatedSpan::new("")))
}

fn multi_whitespace(i: Span) -> nom::IResult<Span, Span> {
    let (i, _) = many0(alt((nom::character::complete::multispace1, parse_comment)))(i)?;
    Ok((i, LocatedSpan::new("")))
}

fn parse_inout_expression(i: Span) -> nom::IResult<Span, InoutExpression> {
    let (i, _) = ampersand(i)?;
    let (i, expression) = parse_expression(i)?;
    let inout_expression = InoutExpression {
        ampersand_token: "&".to_string(),
        expression: Box::new(expression),
    };
    Ok((i, inout_expression))
}

fn parse_bracketed_expression(i: Span) -> nom::IResult<Span, BracketedExpression> {
    let (i, _) = left_parens(i)?;
    let (i, expression) = parse_expression(i)?;
    let (i, _) = right_parens(i)?;
    let bracketed_expression = BracketedExpression {
        expression: Box::new(expression),
    };
    Ok((i, bracketed_expression))
}

fn parse_attempt_expression(i: Span) -> nom::IResult<Span, AttemptExpression> {
    let (i, _) = tag("try")(i)?;
    let (i, kind) = alt((bang, question))(i)?;
    let (i, function_call) = parse_function_call(i)?;
    let attempt_expression = AttemptExpression {
        kind: kind.fragment().to_string(),
        function_call,
    };
    Ok((i, attempt_expression))
}

fn parse_binary_expression(input: Span) -> nom::IResult<Span, BinaryExpression> {
    let (i, lhs_expression) = parse_expression_left(input)?;
    let (_, op) = preceded(whitespace, parse_binary_op)(i)?;
    let (i, expression) = parse_binary_expression_precedence(input, 0)?;
    if let Expression::BinaryExpression(b) = expression {
        return Ok((i, b));
    } else {
        unimplemented!()
    }
}

pub fn parse_binary_expression_precedence(
    i: Span,
    operator_precedence: i32,
) -> nom::IResult<Span, Expression> {
    let line_info = LineInfo {
        line: i.location_line(),
        offset: i.location_offset(),
    };
    let (i, lhs_expression) = parse_expression_left(i)?;
    let mut lhs_expression = lhs_expression;
    let mut result = lhs_expression.clone();
    let mut input = i;
    loop {
        let (i, op) = nom::combinator::opt(preceded(whitespace, parse_binary_op))(input)?;
        if op.is_none() {
            break;
        }
        let op = op.unwrap();
        let current_precedence = get_operator_precedence(&op);
        if current_precedence < operator_precedence {
            break;
        }

        let next_precedence = if op.is_left() {
            current_precedence + 1
        } else {
            current_precedence
        };
        let (i, _) = whitespace(i)?;
        let (i, rhs) = parse_binary_expression_precedence(i, next_precedence)?;
        input = i;
        let binary_expression = BinaryExpression {
            lhs_expression: Box::new(lhs_expression.clone()),
            op: op.clone(),
            rhs_expression: Box::new(rhs),
            line_info: line_info.clone(),
        };
        result = Expression::BinaryExpression(binary_expression);
        lhs_expression = result.clone();
    }
    Ok((input, result))
}

fn get_operator_precedence(op: &BinOp) -> i32 {
    return match op {
        BinOp::Plus => 20,
        BinOp::OverflowingPlus => 20,
        BinOp::Minus => 20,
        BinOp::OverflowingMinus => 20,
        BinOp::Times => 30,
        BinOp::OverflowingTimes => 30,
        BinOp::Power => 31,
        BinOp::Divide => 30,
        BinOp::Percent => 30,
        BinOp::Dot => 40,
        BinOp::Equal => 10,
        BinOp::PlusEqual => 10,
        BinOp::MinusEqual => 10,
        BinOp::TimesEqual => 10,
        BinOp::DivideEqual => 10,
        BinOp::DoubleEqual => 15,
        BinOp::NotEqual => 15,
        BinOp::LessThan => 15,
        BinOp::LessThanOrEqual => 15,
        BinOp::GreaterThan => 15,
        BinOp::GreaterThanOrEqual => 15,
        BinOp::Or => 11,
        BinOp::And => 12,
        BinOp::Implies => 10,
    };
}

fn parse_binary_op(i: Span) -> nom::IResult<Span, BinOp> {
    alt((
        double_equal_operator,
        not_equal_operator,
        plus_equal_operator,
        minus_equal_operator,
        times_equal_operator,
        divide_equal_operator,
        greater_than_equal_operator,
        less_than_equal_operator,
        plus_operator,
        minus_operator,
        power_operator,
        times_operator,
        divide_operator,
        dot_operator,
        equal_operator,
        less_than_operator,
        greater_than_operator,
        and_operator,
        or_operator,
    ))(i)
}

fn greater_than_equal_operator(i: Span) -> nom::IResult<Span, BinOp> {
    let (i, _) = tag(">=")(i)?;
    Ok((i, BinOp::GreaterThanOrEqual))
}

fn less_than_equal_operator(i: Span) -> nom::IResult<Span, BinOp> {
    let (i, _) = tag("<=")(i)?;
    Ok((i, BinOp::LessThanOrEqual))
}

fn power_operator(i: Span) -> nom::IResult<Span, BinOp> {
    let (i, _) = tag("**")(i)?;
    Ok((i, BinOp::Power))
}

fn times_operator(i: Span) -> nom::IResult<Span, BinOp> {
    let (i, _) = tag("*")(i)?;
    Ok((i, BinOp::Times))
}

fn divide_operator(i: Span) -> nom::IResult<Span, BinOp> {
    let (i, _) = tag("/")(i)?;
    Ok((i, BinOp::Divide))
}

fn and_operator(i: Span) -> nom::IResult<Span, BinOp> {
    let (i, _) = tag("&&")(i)?;
    Ok((i, BinOp::And))
}

fn or_operator(i: Span) -> nom::IResult<Span, BinOp> {
    let (i, _) = tag("||")(i)?;
    Ok((i, BinOp::Or))
}

fn double_equal_operator(i: Span) -> nom::IResult<Span, BinOp> {
    let (i, _) = tag("==")(i)?;
    Ok((i, BinOp::DoubleEqual))
}

fn not_equal_operator(i: Span) -> nom::IResult<Span, BinOp> {
    let (i, _) = tag("!=")(i)?;
    Ok((i, BinOp::NotEqual))
}

fn parse_event_declaration(i: Span) -> nom::IResult<Span, EventDeclaration> {
    let (i, _event_token) = tag("event")(i)?;
    let (i, _) = whitespace(i)?;
    let (i, identifier) = parse_identifier(i)?;
    let (i, _) = whitespace(i)?;
    let (i, parameter_list) = parse_parameter_list(i)?;
    let event_declaration = EventDeclaration {
        identifier,
        parameter_list,
    };
    Ok((i, event_declaration))
}

pub fn parse_contract_declaration(i: Span) -> nom::IResult<Span, TopLevelDeclaration> {
    let (i, _contract_token) = tag("contract")(i)?;
    let (i, identifier) = preceded(nom::character::complete::space0, parse_identifier)(i)?;
    let (i, _) = whitespace(i)?;
    let (i, conformances) = parse_conformances(i)?;
    let (i, _identifier_group) = nom::combinator::opt(parse_identifier_group)(i)?;
    let (i, _) = preceded(nom::character::complete::space0, left_brace)(i)?;
    let (i, contract_members) = many0(nom::sequence::terminated(
        preceded(whitespace, parse_contract_member),
        multi_whitespace,
    ))(i)?;
    let (i, _) = whitespace(i)?;
    let (i, _) = right_brace(i)?;
    let contract = ContractDeclaration {
        identifier,
        contract_members,
        conformances,
    };
    Ok((i, TopLevelDeclaration::ContractDeclaration(contract)))
}

pub fn parse_contract_member(i: Span) -> nom::IResult<Span, ContractMember> {
    alt((
        map(parse_event_declaration, |e| {
            ContractMember::EventDeclaration(e)
        }),
        map(parse_variable_declaration_enclosing, |v| {
            ContractMember::VariableDeclaration(v)
        }),
    ))(i)
}

pub fn parse_variable_declaration_enclosing(i: Span) -> nom::IResult<Span, VariableDeclaration> {
    let (i, _) = parse_modifiers(i)?;
    let (i, _) = whitespace(i)?;
    let (i, declaration_token) = alt((tag("var"), tag("let")))(i)?;
    let declaration_token = Some(declaration_token.fragment().to_string());
    let (i, identifier) = preceded(nom::character::complete::space0, parse_identifier)(i)?;
    let (i, type_annotation) = parse_type_annotation(i)?;
    let (i, _) = whitespace(i)?;
    let (i, equal_token) = nom::combinator::opt(equal_operator)(i)?;
    if equal_token.is_none() {
        let variable_declaration = VariableDeclaration {
            declaration_token,
            identifier,
            variable_type: type_annotation.type_assigned,
            expression: None,
        };
        return Ok((i, variable_declaration));
    }
    let (i, expression) = preceded(nom::character::complete::space0, parse_expression)(i)?;
    let variable_declaration = VariableDeclaration {
        declaration_token,
        identifier,
        variable_type: type_annotation.type_assigned,
        expression: Option::from(Box::new(expression)),
    };
    Ok((i, variable_declaration))
}

pub fn parse_variable_declaration(i: Span) -> nom::IResult<Span, VariableDeclaration> {
    let (i, _) = parse_modifiers(i)?;
    let (i, _) = whitespace(i)?;
    let (i, declaration_token) = alt((tag("var"), tag("let")))(i)?;
    let declaration_token = Some(declaration_token.fragment().to_string());
    let (i, identifier) = preceded(nom::character::complete::space0, parse_identifier)(i)?;
    let (i, type_annotation) = parse_type_annotation(i)?;
    let (i, _) = whitespace(i)?;
    let variable_declaration = VariableDeclaration {
        declaration_token,
        identifier,
        variable_type: type_annotation.type_assigned,
        expression: None,
    };
    Ok((i, variable_declaration))
}

fn parse_enum_declaration(i: Span) -> nom::IResult<Span, TopLevelDeclaration> {
    let (i, enum_token) = tag("enum")(i)?;
    let (i, identifier) = preceded(nom::character::complete::space0, parse_identifier)(i)?;
    let (i, type_annotation) = nom::combinator::opt(parse_type_annotation)(i)?;
    let type_assigned = if type_annotation.is_none() {
        None
    } else {
        Some(type_annotation.unwrap().type_assigned)
    };
    let (i, _) = preceded(nom::character::complete::space0, left_brace)(i)?;
    let (i, _) = whitespace(i)?;

    let (i, members) = nom::multi::separated_list(whitespace, parse_enum_member)(i)?;
    let mut enum_members = Vec::<EnumMember>::new();
    for member in members {
        let enum_member = EnumMember {
            case_token: member.case_token,
            identifier: member.identifier,
            hidden_value: member.hidden_value,
            enum_type: Type::UserDefinedType(identifier.clone()),
        };
        enum_members.push(enum_member);
    }
    let members = enum_members;
    let (i, _) = whitespace(i)?;
    let (i, _) = right_brace(i)?;
    let enum_declaration = EnumDeclaration {
        enum_token: enum_token.to_string(),
        identifier,
        type_assigned,
        members,
    };
    Ok((i, TopLevelDeclaration::EnumDeclaration(enum_declaration)))
}

fn parse_enum_member(i: Span) -> nom::IResult<Span, EnumMember> {
    let (i, case_token) = tag("case")(i)?;
    let (i, identifier) = preceded(nom::character::complete::space0, parse_identifier)(i)?;
    let (i, equal_token) = nom::combinator::opt(preceded(whitespace, equal_operator))(i)?;
    let enum_type = Type::UserDefinedType(Identifier {
        ..Default::default()
    });
    if equal_token.is_none() {
        let enum_member = EnumMember {
            case_token: case_token.to_string(),
            identifier,
            hidden_value: None,
            enum_type,
        };
        return Ok((i, enum_member));
    }
    let (i, expression) = parse_expression(i)?;
    let enum_member = EnumMember {
        case_token: case_token.to_string(),
        identifier,
        hidden_value: Some(expression),
        enum_type,
    };
    Ok((i, enum_member))
}

fn parse_type_states(i: Span) -> nom::IResult<Span, Vec<TypeState>> {
    let (i, identifier_group) = parse_identifier_group(i)?;
    let types_states = identifier_group
        .into_iter()
        .map(|identifier| TypeState { identifier })
        .collect();
    Ok((i, types_states))
}

pub fn parse_contract_behaviour_declaration(
    i: Span,
) -> nom::IResult<Span, ContractBehaviourDeclaration> {
    let (i, identifier) = parse_identifier(i)?;
    let (i, _) = whitespace(i)?;
    let (i, at_token) = nom::combinator::opt(at)(i)?;
    let (i, type_states) = if at_token.is_none() {
        (i, Vec::new())
    } else {
        parse_type_states(i)?
    };
    let (i, _) = nom::character::complete::space0(i)?;
    let (i, _) = double_colon(i)?;
    let (i, _) = whitespace(i)?;
    let (i, caller_binding) = nom::combinator::opt(parse_caller_binding)(i)?;
    let (i, _) = whitespace(i)?;
    let (i, caller_protections) = parse_caller_protection_group(i)?;
    let (i, _) = whitespace(i)?;
    let (i, _) = left_brace(i)?;
    let (i, members) = many0(nom::sequence::terminated(
        preceded(whitespace, parse_contract_behaviour_member),
        multi_whitespace,
    ))(i)?;
    let (i, _) = right_brace(i)?;
    let contract_behaviour_declaration = ContractBehaviourDeclaration {
        members,
        identifier,
        states: type_states,
        caller_protections,
        caller_binding,
    };
    Ok((i, contract_behaviour_declaration))
}

fn parse_caller_binding(i: Span) -> nom::IResult<Span, Identifier> {
    let (i, identifier) = parse_identifier(i)?;
    let (i, _) = whitespace(i)?;
    let (i, _) = left_arrow(i)?;
    Ok((i, identifier))
}

fn parse_contract_behaviour_member(i: Span) -> nom::IResult<Span, ContractBehaviourMember> {
    alt((
        map(parse_function_declaration, |f| {
            ContractBehaviourMember::FunctionDeclaration(f)
        }),
        map(parse_special_declaration, |s| {
            ContractBehaviourMember::SpecialDeclaration(s)
        }),
        map(parse_special_signature_declaration, |s| {
            ContractBehaviourMember::SpecialSignatureDeclaration(s)
        }),
        map(parse_function_signature_declaration, |f| {
            ContractBehaviourMember::FunctionSignatureDeclaration(f)
        }),
    ))(i)
}

fn parse_special_declaration(i: Span) -> nom::IResult<Span, SpecialDeclaration> {
    let (i, signature) = parse_special_signature_declaration(i)?;
    let (i, _) = whitespace(i)?;
    let (i, statements) = parse_code_block(i)?;
    let special_declaration = SpecialDeclaration {
        head: signature,
        body: statements,
        ScopeContext: Default::default(),
        generated: false,
    };

    Ok((i, special_declaration))
}
fn parse_special_signature_declaration(i: Span) -> nom::IResult<Span, SpecialSignatureDeclaration> {
    let (i, attributes) = parse_attributes(i)?;
    let (i, modifiers) = parse_modifiers(i)?;
    let (i, special_token) = alt((tag("init"), tag("fallback")))(i)?;
    let (i, parameters) = parse_parameter_list(i)?;
    let (i, _) = whitespace(i)?;
    let (i, mutates) = parse_mutates(i)?;
    let special_signature_declaration = SpecialSignatureDeclaration {
        attributes,
        modifiers,
        mutates,
        parameters,
        special_token: special_token.to_string(),
    };
    Ok((i, special_signature_declaration))
}

pub fn parse_function_declaration(i: Span) -> nom::IResult<Span, FunctionDeclaration> {
    let (i, signature) = parse_function_signature_declaration(i)?;
    let (i, _) = whitespace(i)?;
    let (i, statements) = parse_code_block(i)?;

    let function_declaration = FunctionDeclaration {
        head: signature,
        body: statements,
        ScopeContext: None,
        tags: vec![],
        mangledIdentifier: None,
        is_external: false,
    };
    Ok((i, function_declaration))
}

fn parse_function_signature_declaration(
    i: Span,
) -> nom::IResult<Span, FunctionSignatureDeclaration> {
    let (i, attributes) = parse_attributes(i)?;
    let mut payable = false;
    for attribute in &attributes {
        if attribute.identifier_token == "payable".to_string() {
            payable = true;
        }
    }
    let (i, _) = whitespace(i)?;
    let (i, modifiers) = parse_modifiers(i)?;
    let (i, _) = nom::character::complete::space0(i)?;
    let (i, func_token) = tag("func")(i)?;
    let (i, _) = nom::character::complete::space0(i)?;
    let (i, identifier) = parse_identifier(i)?;
    let (i, parameters) = parse_parameter_list(i)?;
    let (i, _) = nom::character::complete::space0(i)?;
    let (i, result_type) = parse_result(i)?;
    let (i, _) = whitespace(i)?;
    let (i, mutates) = parse_mutates(i)?;
    let function_signature_declaration = FunctionSignatureDeclaration {
        func_token: func_token.to_string(),
        attributes,
        modifiers,
        identifier,
        mutates,
        parameters,
        result_type,
        payable,
    };
    Ok((i, function_signature_declaration))
}

fn parse_code_block(i: Span) -> nom::IResult<Span, Vec<Statement>> {
    let (i, _) = left_brace(i)?;
    let (i, _) = multi_whitespace(i)?;
    let (i, statements) = parse_statements(i)?;
    let (i, _) = multi_whitespace(i)?;
    let (i, _) = right_brace(i)?;

    Ok((i, statements))
}

fn parse_statements(i: Span) -> nom::IResult<Span, Vec<Statement>> {
    let (i, statements) = many0(nom::sequence::terminated(
        preceded(whitespace, parse_statement),
        whitespace,
    ))(i)?;
    Ok((i, statements))
}

pub fn parse_statement(i: Span) -> nom::IResult<Span, Statement> {
    alt((
        parse_return_statement,
        parse_become_statement,
        parse_emit_statement,
        parse_for_statement,
        parse_if_statement,
        parse_docatch_statement,
        map(parse_expression, |e| Statement::Expression(e)),
    ))(i)
}

fn parse_docatch_statement(i: Span) -> nom::IResult<Span, Statement> {
    let (i, _) = tag("do")(i)?;
    let (i, _) = nom::character::complete::space0(i)?;
    let (i, do_body) = parse_code_block(i)?;
    let (i, _) = nom::character::complete::space0(i)?;
    let (i, _) = tag("catch")(i)?;
    let (i, _) = nom::character::complete::space0(i)?;
    let (i, _) = tag("is")(i)?;
    let (i, _) = nom::character::complete::space0(i)?;
    let (i, error) = parse_expression(i)?;
    let (i, _) = nom::character::complete::space0(i)?;
    let (i, catch_body) = parse_code_block(i)?;
    let do_catch_statement = DoCatchStatement {
        error,
        do_body,
        catch_body,
    };
    Ok((i, Statement::DoCatchStatement(do_catch_statement)))
}

fn parse_if_statement(i: Span) -> nom::IResult<Span, Statement> {
    let (i, _) = tag("if")(i)?;
    let (i, _) = whitespace(i)?;
    let (i, condition) = parse_expression(i)?;
    let (i, _) = whitespace(i)?;
    let (i, statements) = parse_code_block(i)?;
    let (i, _) = whitespace(i)?;
    let (i, else_token) = nom::combinator::opt(tag("else"))(i)?;
    if else_token.is_some() {
        let (i, _) = whitespace(i)?;
        let (i, else_statements) = parse_code_block(i)?;
        let if_statement = IfStatement {
            condition,
            body: statements,
            else_body: else_statements,
            IfBodyScopeContext: None,
            ElseBodyScopeContext: None,
        };
        return Ok((i, Statement::IfStatement(if_statement)));
    }
    let if_statement = IfStatement {
        condition,
        body: statements,
        else_body: Vec::new(),
        IfBodyScopeContext: None,
        ElseBodyScopeContext: None,
    };
    Ok((i, Statement::IfStatement(if_statement)))
}

fn parse_for_statement(i: Span) -> nom::IResult<Span, Statement> {
    let (i, _) = tag("for")(i)?;
    let (i, _) = nom::character::complete::space0(i)?;
    let (i, variable) = parse_variable_declaration(i)?;
    let (i, _) = nom::character::complete::space0(i)?;
    let (i, _) = tag("in")(i)?;
    let (i, _) = nom::character::complete::space0(i)?;
    let (i, iterable) = parse_expression(i)?;
    let (i, _) = nom::character::complete::space0(i)?;
    let (i, _) = left_brace(i)?;
    let (i, statements) = parse_code_block(i)?;
    let (i, _) = right_brace(i)?;
    let for_statement = ForStatement {
        variable,
        iterable,
        body: statements,
        ForBodyScopeContext: None,
    };
    Ok((i, Statement::ForStatement(for_statement)))
}

pub fn parse_emit_statement(i: Span) -> nom::IResult<Span, Statement> {
    let (i, _) = tag("emit")(i)?;
    let (i, _) = nom::character::complete::space0(i)?;
    let (i, function_call) = parse_function_call(i)?;
    let emit_statement = EmitStatement { function_call };
    Ok((i, Statement::EmitStatement(emit_statement)))
}

fn parse_become_statement(i: Span) -> nom::IResult<Span, Statement> {
    let line_info = LineInfo {
        line: i.location_line(),
        offset: i.location_offset(),
    };
    let (i, _) = tag("become")(i)?;
    let (i, _) = nom::character::complete::space0(i)?;
    let (i, expression) = parse_expression(i)?;
    let become_statement = BecomeStatement {
        expression,
        line_info,
    };
    Ok((i, Statement::BecomeStatement(become_statement)))
}

fn parse_return_statement(i: Span) -> nom::IResult<Span, Statement> {
    let line_info = LineInfo {
        line: i.location_line(),
        offset: i.location_offset(),
    };
    let (i, _) = tag("return")(i)?;
    let (i, _) = nom::character::complete::space0(i)?;
    let (i, expression) = nom::combinator::opt(parse_expression)(i)?;
    let return_statement = ReturnStatement {
        expression,
        line_info,
        ..Default::default()
    };
    return Ok((i, Statement::ReturnStatement(return_statement)));
}

fn parse_mutates(i: Span) -> nom::IResult<Span, Vec<Identifier>> {
    let identifiers = Vec::new();
    let (i, mutates) = nom::combinator::opt(tag("mutates"))(i)?;
    if mutates.is_none() {
        return Ok((i, identifiers));
    }
    let (i, _) = whitespace(i)?;
    let (i, _) = left_parens(i)?;
    let (i, identifiers) = nom::multi::separated_nonempty_list(
        tag(","),
        nom::sequence::terminated(
            preceded(
                whitespace,
                alt((parse_enclosing_identifier, parse_identifier)),
            ),
            whitespace,
        ),
    )(i)?;
    let (i, _) = right_parens(i)?;
    Ok((i, identifiers))
}

fn parse_enclosing_identifier(i: Span) -> nom::IResult<Span, Identifier> {
    let line_info = LineInfo {
        line: i.location_line(),
        offset: i.location_offset(),
    };
    let (i, enclosing_type) = parse_identifier(i)?;
    let (i, _) = dot_operator(i)?;
    let (i, identifier) = parse_identifier(i)?;
    let identifier = Identifier {
        token: identifier.token,
        enclosing_type: Some(enclosing_type.token),
        line_info,
    };
    Ok((i, identifier))
}

fn parse_result(i: Span) -> nom::IResult<Span, Option<Type>> {
    let (i, token) = nom::combinator::opt(right_arrow)(i)?;
    if token.is_none() {
        return Ok((i, None));
    }
    let (i, _) = nom::character::complete::space0(i)?;
    let (i, identifier) = parse_identifier_type(i)?;
    Ok((i, Some(identifier)))
}

fn parse_modifiers(i: Span) -> nom::IResult<Span, Vec<std::string::String>> {
    many0(nom::sequence::terminated(
        parse_modifier,
        nom::character::complete::space0,
    ))(i)
}

fn parse_modifier(i: Span) -> nom::IResult<Span, std::string::String> {
    alt((public, visible))(i)
}

fn public(i: Span) -> nom::IResult<Span, std::string::String> {
    let (i, public) = tag("public")(i)?;
    Ok((i, public.to_string()))
}

fn visible(i: Span) -> nom::IResult<Span, std::string::String> {
    let (i, visible) = tag("visible")(i)?;
    Ok((i, visible.to_string()))
}

fn parse_attributes(i: Span) -> nom::IResult<Span, Vec<Attribute>> {
    many0(nom::sequence::terminated(parse_attribute, whitespace))(i)
}

fn parse_attribute(i: Span) -> nom::IResult<Span, Attribute> {
    let (i, at) = at(i)?;
    let (i, identifier) = parse_identifier(i)?;
    let attribute = Attribute {
        at_token: at.to_string(),
        identifier_token: identifier.token,
    };
    Ok((i, attribute))
}

fn parse_protection_binding(i: Span) -> nom::IResult<Span, Identifier> {
    let (i, identifier) = parse_identifier(i)?;
    let (i, _) = left_arrow(i)?;
    Ok((i, identifier))
}

fn parse_caller_protection_group(i: Span) -> nom::IResult<Span, Vec<CallerProtection>> {
    let (i, identifiers) = parse_identifier_group(i)?;
    let caller_protections = identifiers
        .into_iter()
        .map(|identifier| CallerProtection { identifier })
        .collect();
    Ok((i, caller_protections))
}

fn parse_asset_declaration(i: Span) -> nom::IResult<Span, TopLevelDeclaration> {
    let (i, _struct_token) = tag("asset")(i)?;
    let (i, _) = nom::character::complete::space0(i)?;
    let (i, identifier) = parse_identifier(i)?;
    let (i, _) = nom::character::complete::space0(i)?;
    let (i, _) = left_brace(i)?;
    let (i, members) = many0(nom::sequence::terminated(
        preceded(whitespace, parse_asset_member),
        nom::character::complete::multispace0,
    ))(i)?;
    let (i, _) = whitespace(i)?;
    let (i, _) = right_brace(i)?;
    let asset_declaration = AssetDeclaration {
        identifier,
        members,
    };
    Ok((i, TopLevelDeclaration::AssetDeclaration(asset_declaration)))
}

fn parse_struct_declaration(i: Span) -> nom::IResult<Span, TopLevelDeclaration> {
    let (i, _struct_token) = tag("struct")(i)?;
    let (i, _) = nom::character::complete::space0(i)?;
    let (i, identifier) = parse_identifier(i)?;
    let (i, conformances) = parse_conformances(i)?;
    let (i, _) = nom::character::complete::space0(i)?;
    let (i, _) = left_brace(i)?;
    let (i, members) = many0(nom::sequence::terminated(
        preceded(whitespace, parse_struct_member),
        nom::character::complete::multispace0,
    ))(i)?;
    let (i, _) = whitespace(i)?;
    let (i, _) = right_brace(i)?;
    let struct_declaration = StructDeclaration {
        identifier,
        conformances,
        members,
    };
    Ok((
        i,
        TopLevelDeclaration::StructDeclaration(struct_declaration),
    ))
}

fn parse_struct_member(i: Span) -> nom::IResult<Span, StructMember> {
    alt((
        map(parse_function_declaration, |f| {
            StructMember::FunctionDeclaration(f)
        }),
        map(parse_special_declaration, |s| {
            StructMember::SpecialDeclaration(s)
        }),
        map(parse_variable_declaration_enclosing, |v| {
            StructMember::VariableDeclaration(v)
        }),
    ))(i)
}

fn parse_asset_member(i: Span) -> nom::IResult<Span, AssetMember> {
    alt((
        map(parse_function_declaration, |f| {
            AssetMember::FunctionDeclaration(f)
        }),
        map(parse_special_declaration, |s| {
            AssetMember::SpecialDeclaration(s)
        }),
        map(parse_variable_declaration_enclosing, |v| {
            AssetMember::VariableDeclaration(v)
        }),
    ))(i)
}

fn parse_conformances(i: Span) -> nom::IResult<Span, Vec<Conformance>> {
    let (i, colon_token) = nom::combinator::opt(colon)(i)?;
    if colon_token.is_none() {
        return Ok((i, Vec::new()));
    }
    let (i, _) = whitespace(i)?;
    let (i, identifier_list) = parse_identifier_list(i)?;
    let conformances = identifier_list
        .into_iter()
        .map(|identifier| Conformance { identifier })
        .collect();
    Ok((i, conformances))
}

fn parse_trait_declaration(i: Span) -> nom::IResult<Span, TopLevelDeclaration> {
    let (i, modifiers) = many0(nom::sequence::terminated(
        preceded(whitespace, parse_trait_modifier),
        whitespace,
    ))(i)?;
    let (i, trait_kind) = tag("external")(i)?;
    let (i, _) = nom::character::complete::space0(i)?;
    let (i, _) = tag("trait")(i)?;
    let (i, _) = nom::character::complete::space0(i)?;
    let (i, identifier) = parse_identifier(i)?;
    let (i, _) = nom::character::complete::space0(i)?;
    let (i, _) = left_brace(i)?;
    let (i, members) = many0(nom::sequence::terminated(
        preceded(whitespace, parse_trait_member),
        nom::character::complete::multispace0,
    ))(i)?;
    let (i, _) = right_brace(i)?;
    let trait_declaration = TraitDeclaration {
        trait_kind: trait_kind.to_string(),
        identifier,
        members,
        modifiers: modifiers,
    };
    Ok((i, TopLevelDeclaration::TraitDeclaration(trait_declaration)))
}

fn parse_trait_modifier(i: Span) -> nom::IResult<Span, FunctionCall> {
    let (i, _) = tag("@")(i)?;
    let (i, fc) = nom::combinator::opt(parse_function_call)(i)?;
    if fc.is_some() {
        let fc = fc.clone();
        let fc = fc.unwrap();
        return Ok((i, fc));
    }
    let (i, identifier) = parse_identifier(i)?;
    let fc = FunctionCall {
        identifier,
        arguments: vec![],
        mangled_identifier: None,
    };

    Ok((i, fc))
}

fn parse_trait_member(i: Span) -> nom::IResult<Span, TraitMember> {
    alt((
        map(parse_function_declaration, |f| {
            TraitMember::FunctionDeclaration(f)
        }),
        map(parse_special_declaration, |s| {
            TraitMember::SpecialDeclaration(s)
        }),
        map(parse_function_signature_declaration, |f| {
            TraitMember::FunctionSignatureDeclaration(f)
        }),
        map(parse_special_signature_declaration, |s| {
            TraitMember::SpecialSignatureDeclaration(s)
        }),
        map(parse_event_declaration, |e| {
            TraitMember::EventDeclaration(e)
        }),
        map(parse_contract_behaviour_declaration, |c| {
            TraitMember::ContractBehaviourDeclaration(c)
        }),
    ))(i)
}

fn is_basic_type(basic_type: &str) -> bool {
    let basic_types: HashSet<&'static str> = ["Address", "Int", "String", "Void", "Bool", "Event"]
        .iter()
        .cloned()
        .collect();
    return basic_types.contains(basic_type);
}

#[cfg(test)]
mod tests {

    use super::nom::error::ErrorKind;
    use crate::Parser::{parse_caller_binding, parse_return_statement, parse_type};
    use crate::AST::{Identifier, ReturnStatement, Statement, Type};
    use nom_locate::{position, LocatedSpan};
    use sha3::Digest;

    #[test]
    fn test_parse_int_type() {
        let input = "Int";
        let input = LocatedSpan::new(input);
        let result = parse_type(input);
        match result {
            Ok((c, b)) => assert_eq!(b, Type::Int),
            Err(_) => assert_eq!(1, 0),
        }
    }

    #[test]
    fn test_parse_address_type() {
        let input = "Address";
        let input = LocatedSpan::new(input);
        let result = parse_type(input);
        match result {
            Ok((c, b)) => assert_eq!(b, Type::Address),
            Err(_) => assert_eq!(1, 0),
        }
    }

    #[test]
    fn test_parse_bool_type() {
        let input = "Bool";
        let input = LocatedSpan::new(input);
        let result = parse_type(input);
        match result {
            Ok((c, b)) => assert_eq!(b, Type::Bool),
            Err(_) => assert_eq!(1, 0),
        }
    }

    #[test]
    fn test_parse_string_type() {
        let input = "String";
        let input = LocatedSpan::new(input);
        let result = parse_type(input);
        match result {
            Ok((c, b)) => assert_eq!(b, Type::String),
            Err(_) => assert_eq!(1, 0),
        }
    }

    #[test]
    fn test_parse_caller_binding() {
        let input = "caller <-";
        let input = LocatedSpan::new(input);
        let result = parse_caller_binding(input);
        match result {
            Ok((c, b)) => assert_eq!(
                b,
                Identifier {
                    token: "caller".to_string(),
                    enclosing_type: None,
                    line_info: Default::default()
                }
            ),
            Err(_) => assert_eq!(1, 0),
        }
    }
}
