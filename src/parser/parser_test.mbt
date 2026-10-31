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

///|
fn assert_filter_parse(input : String, expected : @parser.Expr) -> Unit raise {
  let result = @parser.parse(@lexer.tokenize(input))
  let expected_query : @parser.Query = {
    fields: ["name"],
    filter: Some(expected),
    limit: None,
  }
  let expected_result : Result[@parser.Query, String] = Ok(expected_query)
  assert_eq(result, expected_result)
}

///|
test "parse < filter" {
  assert_filter_parse(
    "select name where age < 18",
    @parser.Expr::Lt("age", 18.0),
  )
}

///|
test "parse <= filter" {
  assert_filter_parse(
    "select name where age <= 18",
    @parser.Expr::Le("age", 18.0),
  )
}

///|
test "parse == filter" {
  assert_filter_parse(
    "select name where age == 18",
    @parser.Expr::Eq("age", 18.0),
  )
}

///|
test "parse != filter" {
  assert_filter_parse(
    "select name where age != 18",
    @parser.Expr::Ne("age", 18.0),
  )
}

///|
test "parse >= filter" {
  assert_filter_parse(
    "select name where age >= 18",
    @parser.Expr::Ge("age", 18.0),
  )
}

///|
test "parse new comparison operator followed by limit" {
  let result = @parser.parse(
    @lexer.tokenize("select name where age < 18 limit 3"),
  )
  let expected_query : @parser.Query = {
    fields: ["name"],
    filter: Some(@parser.Expr::Lt("age", 18.0)),
    limit: Some(3),
  }
  let expected : Result[@parser.Query, String] = Ok(expected_query)
  assert_eq(result, expected)
}

///|
test "parse rejects a filter without a comparison operator" {
  let result = @parser.parse(@lexer.tokenize("select name where age = 18"))
  let expected : Result[@parser.Query, String] = Err(
    "expected comparison operator",
  )
  assert_eq(result, expected)
}

///|
test "parse string equality filter" {
  assert_filter_parse(
    "select name where city == \"Beijing\"",
    @parser.Expr::EqStr("city", "Beijing"),
  )
}

///|
test "parse string inequality filter" {
  assert_filter_parse(
    "select name where city != \"Beijing\"",
    @parser.Expr::NeStr("city", "Beijing"),
  )
}

///|
test "parse contains filter" {
  assert_filter_parse(
    "select name where name contains \"li\"",
    @parser.Expr::Contains("name", "li"),
  )
}

///|
test "parse startsWith filter" {
  assert_filter_parse(
    "select name where name startsWith \"Al\"",
    @parser.Expr::StartsWith("name", "Al"),
  )
}

///|
test "parse contains filter followed by limit" {
  let result = @parser.parse(
    @lexer.tokenize("select name where name contains \"li\" limit 2"),
  )
  let expected_query : @parser.Query = {
    fields: ["name"],
    filter: Some(@parser.Expr::Contains("name", "li")),
    limit: Some(2),
  }
  let expected : Result[@parser.Query, String] = Ok(expected_query)
  assert_eq(result, expected)
}

///|
test "parse propagates an unterminated string literal error" {
  let result = @parser.parse(
    @lexer.tokenize("select name where city == \"Beijing"),
  )
  let expected : Result[@parser.Query, String] = Err(
    "unterminated string literal",
  )
  assert_eq(result, expected)
}

///|
test "parse rejects matching operators without a string operand" {
  let contains_result = @parser.parse(
    @lexer.tokenize("select name where name contains 5"),
  )
  let contains_expected : Result[@parser.Query, String] = Err(
    "expected filter string",
  )
  assert_eq(contains_result, contains_expected)
  let equals_result = @parser.parse(
    @lexer.tokenize("select name where city == Beijing"),
  )
  let equals_expected : Result[@parser.Query, String] = Err(
    "expected filter number or string",
  )
  assert_eq(equals_result, equals_expected)
}
