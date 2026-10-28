///|
pub(all) enum Expr {
  Gt(String, Double)
} derive(Eq, Debug)

///|
pub(all) struct Query {
  fields : Array[String]
  filter : Expr?
  limit : Int32?
} derive(Eq, Debug)

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
          return Err("expected '>'")
        }
        match tokens[index] {
          @lexer.Token::GT => index = index + 1
          _ => return Err("expected '>'")
        }
        if index >= tokens.length() {
          return Err("expected filter number")
        }
        match tokens[index] {
          @lexer.Token::Number(value) => {
            index = index + 1
            filter = Some(Gt(field, value))
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
