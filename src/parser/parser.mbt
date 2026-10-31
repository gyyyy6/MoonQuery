///|
pub(all) enum Expr {
  Gt(String, Double)
  Ge(String, Double)
  Lt(String, Double)
  Le(String, Double)
  Eq(String, Double)
  Ne(String, Double)
} derive(Eq, Debug)

///|
pub extend Expr with Eq::{not_equal, equal}

///|
pub extend Expr with Debug::{to_repr}

///|
pub(all) struct Query {
  fields : Array[String]
  filter : Expr?
  limit : Int32?
} derive(Eq, Debug)

///|
pub extend Query with Eq::{not_equal, equal}

///|
pub extend Query with Debug::{to_repr}

///|
/// Whether `token` is one of the comparison operators accepted in a filter.
fn is_comparison_operator(token : @lexer.Token) -> Bool {
  match token {
    @lexer.Token::GT
    | @lexer.Token::GE
    | @lexer.Token::LT
    | @lexer.Token::LE
    | @lexer.Token::EQ
    | @lexer.Token::NE => true
    _ => false
  }
}

///|
/// Build the AST node for a comparison operator applied to `field` and `value`.
fn comparison_expr(
  token : @lexer.Token,
  field : String,
  value : Double,
) -> Expr? {
  match token {
    @lexer.Token::GT => Some(Gt(field, value))
    @lexer.Token::GE => Some(Ge(field, value))
    @lexer.Token::LT => Some(Lt(field, value))
    @lexer.Token::LE => Some(Le(field, value))
    @lexer.Token::EQ => Some(Eq(field, value))
    @lexer.Token::NE => Some(Ne(field, value))
    _ => None
  }
}

///|
pub fn parse(tokens : Array[@lexer.Token]) -> Result[Query, String] {
  if tokens.length() == 0 {
    return Err("empty token stream")
  }
  match tokens[0] {
    @lexer.Token::Select => ()
    _ => return Err("expected 'select'")
  }
  let fields : Array[String] = []
  let mut index = 1
  let mut parsing_fields = true
  while parsing_fields {
    if index >= tokens.length() {
      return Err("expected field name")
    }
    match tokens[index] {
      @lexer.Token::Identifier(name) => {
        fields.push(name)
        index = index + 1
      }
      _ => return Err("expected field name")
    }
    if index < tokens.length() {
      match tokens[index] {
        @lexer.Token::Comma => index = index + 1
        _ => parsing_fields = false
      }
    } else {
      parsing_fields = false
    }
  }
  let mut filter : Expr? = None
  if index < tokens.length() {
    match tokens[index] {
      @lexer.Token::Where => {
        index = index + 1
        if index >= tokens.length() {
          return Err("expected filter field")
        }
        let field = match tokens[index] {
          @lexer.Token::Identifier(name) => {
            index = index + 1
            name
          }
          _ => return Err("expected filter field")
        }
        if index >= tokens.length() {
          return Err("expected comparison operator")
        }
        let operator = tokens[index]
        if !is_comparison_operator(operator) {
          return Err("expected comparison operator")
        }
        index = index + 1
        if index >= tokens.length() {
          return Err("expected filter number")
        }
        match tokens[index] {
          @lexer.Token::Number(value) => {
            index = index + 1
            match comparison_expr(operator, field, value) {
              Some(expr) => filter = Some(expr)
              None => return Err("expected comparison operator")
            }
          }
          _ => return Err("expected filter number")
        }
      }
      _ => ()
    }
  }
  let mut limit : Int32? = None
  if index < tokens.length() {
    match tokens[index] {
      @lexer.Token::Limit => {
        index = index + 1
        if index >= tokens.length() {
          return Err("expected limit number")
        }
        match tokens[index] {
          @lexer.Token::Number(value) => {
            index = index + 1
            limit = Some(Double::to_int(value))
          }
          _ => return Err("expected limit number")
        }
      }
      _ => ()
    }
  }
  if index >= tokens.length() {
    return Err("expected EOF")
  }
  match tokens[index] {
    @lexer.Token::EOF => Ok(Query::{ fields, filter, limit, })
    _ => Err("unexpected token after query")
  }
}
