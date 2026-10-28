///|
test "parse complete query" {
  let tokens = @lexer.tokenize("select name, age where age > 18 limit 10")
  let result = @parser.parse(tokens)
  let expected_query : @parser.Query = {
    fields: ["name", "age"],
    filter: Some(@parser.Expr::Gt("age", 18.0)),
    limit: Some(10),
  }
  let expected : Result[@parser.Query, String] = Ok(expected_query)
  assert_eq(result, expected)
}
