///|
test "tokenize select query" {
  let actual = @lexer.tokenize("select name, age where age > 18")
  let expected : Array[@lexer.Token] = [
    @lexer.Token::Select,
    @lexer.Token::Identifier("name"),
    @lexer.Token::Comma,
    @lexer.Token::Identifier("age"),
    @lexer.Token::Where,
    @lexer.Token::Identifier("age"),
    @lexer.Token::GT,
    @lexer.Token::Number(18.0),
    @lexer.Token::EOF,
  ]
  assert_eq(actual, expected)
}

///|
test "tokenize comparison operators" {
  let actual = @lexer.tokenize("a < 1 b <= 2 c == 3 d != 4 e >= 5 f > 6")
  let expected : Array[@lexer.Token] = [
    @lexer.Token::Identifier("a"),
    @lexer.Token::LT,
    @lexer.Token::Number(1.0),
    @lexer.Token::Identifier("b"),
    @lexer.Token::LE,
    @lexer.Token::Number(2.0),
    @lexer.Token::Identifier("c"),
    @lexer.Token::EQ,
    @lexer.Token::Number(3.0),
    @lexer.Token::Identifier("d"),
    @lexer.Token::NE,
    @lexer.Token::Number(4.0),
    @lexer.Token::Identifier("e"),
    @lexer.Token::GE,
    @lexer.Token::Number(5.0),
    @lexer.Token::Identifier("f"),
    @lexer.Token::GT,
    @lexer.Token::Number(6.0),
    @lexer.Token::EOF,
  ]
  assert_eq(actual, expected)
}

///|
test "tokenize comparison operators without spaces" {
  let actual = @lexer.tokenize("a<1 b<=2 c==3 d!=4 e>=5")
  let expected : Array[@lexer.Token] = [
    @lexer.Token::Identifier("a"),
    @lexer.Token::LT,
    @lexer.Token::Number(1.0),
    @lexer.Token::Identifier("b"),
    @lexer.Token::LE,
    @lexer.Token::Number(2.0),
    @lexer.Token::Identifier("c"),
    @lexer.Token::EQ,
    @lexer.Token::Number(3.0),
    @lexer.Token::Identifier("d"),
    @lexer.Token::NE,
    @lexer.Token::Number(4.0),
    @lexer.Token::Identifier("e"),
    @lexer.Token::GE,
    @lexer.Token::Number(5.0),
    @lexer.Token::EOF,
  ]
  assert_eq(actual, expected)
}

///|
test "tokenize one-character comparison operators at end of input" {
  let actual = @lexer.tokenize("< >")
  let expected : Array[@lexer.Token] = [
    @lexer.Token::LT,
    @lexer.Token::GT,
    @lexer.Token::EOF,
  ]
  assert_eq(actual, expected)
}

///|
test "tokenize ignores incomplete comparison operators" {
  // A lone `=` or `!` is not a valid operator; like other unknown
  // characters it is skipped, leaving the parser to report the error.
  let actual = @lexer.tokenize("a = b ! c")
  let expected : Array[@lexer.Token] = [
    @lexer.Token::Identifier("a"),
    @lexer.Token::Identifier("b"),
    @lexer.Token::Identifier("c"),
    @lexer.Token::EOF,
  ]
  assert_eq(actual, expected)
}
