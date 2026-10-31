///|
pub(all) enum Expr {
  Gt(String, Double)
  Ge(String, Double)
  Lt(String, Double)
  Le(String, Double)
  Eq(String, Double)
  Ne(String, Double)
  EqStr(String, String)
  NeStr(String, String)
  Contains(String, String)
  StartsWith(String, String)
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
/// Whether `token` can start a filter expression after the field name.
fn is_filter_operator(token : @lexer.Token) -> Bool {
  match token {
    @lexer.Token::GT
    | @lexer.Token::GE
    | @lexer.Token::LT
    | @lexer.Token::LE
    | @lexer.Token::EQ
    | @lexer.Token::NE
    | @lexer.Token::Contains
    | @lexer.Token::StartsWith => true
    _ => false
  }
}

///|
/// Build a numeric comparison node for `field` and `value`.
fn numeric_expr(token : @lexer.Token, field : String, value : Double) -> Expr? {
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
/// Build a string equality node for `field` and `value`.
fn string_equality_expr(
  token : @lexer.Token,
  field : String,
  value : String,
) -> Expr? {
  match token {
    @lexer.Token::EQ => Some(EqStr(field, value))
    @lexer.Token::NE => Some(NeStr(field, value))
    _ => None
  }
}

///|
pub fn parse(tokens : Array[@lexer.Token]) -> Result[Query, String] {
  if tokens.length() == 0 {
    return Err("empty token stream")
  }
  // Lexer errors travel through the token stream; surface them before the
  // parser tries to interpret the surrounding tokens.
  for token in tokens {
    match token {
      @lexer.Token::LexError(message) => return Err(message)
      _ => ()
    }
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
        if !is_filter_operator(operator) {
          return Err("expected comparison operator")
        }
        index = index + 1
        if index >= tokens.length() {
          return Err("expected filter value")
        }
        let value_token = tokens[index]
        index = index + 1
        let expr = match operator {
          @lexer.Token::GT
          | @lexer.Token::GE
          | @lexer.Token::LT
          | @lexer.Token::LE =>
            match value_token {
              @lexer.Token::Number(value) =>
                match numeric_expr(operator, field, value) {
                  Some(expr) => expr
                  None => return Err("expected comparison operator")
                }
              _ => return Err("expected filter number")
            }
          @lexer.Token::EQ | @lexer.Token::NE =>
            match value_token {
              @lexer.Token::Number(value) =>
                match numeric_expr(operator, field, value) {
                  Some(expr) => expr
                  None => return Err("expected comparison operator")
                }
              @lexer.Token::StringLit(value) =>
                match string_equality_expr(operator, field, value) {
                  Some(expr) => expr
                  None => return Err("expected comparison operator")
                }
              _ => return Err("expected filter number or string")
            }
          @lexer.Token::Contains =>
            match value_token {
              @lexer.Token::StringLit(value) => Contains(field, value)
              _ => return Err("expected filter string")
            }
          @lexer.Token::StartsWith =>
            match value_token {
              @lexer.Token::StringLit(value) => StartsWith(field, value)
              _ => return Err("expected filter string")
            }
          _ => return Err("expected comparison operator")
        }
        filter = Some(expr)
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
