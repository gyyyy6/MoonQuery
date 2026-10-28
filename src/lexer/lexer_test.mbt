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
