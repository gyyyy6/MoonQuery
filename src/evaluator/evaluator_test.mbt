///|
/// Small user collection shared by the end-to-end tests. `Eve` deliberately has
/// no `age` field so that the filter has to cope with a missing key.
let user_data : String =
  #|[
  #|  { "name": "Alice", "age": 30, "city": "Beijing" },
  #|  { "name": "Bob", "age": 35, "city": "Shanghai" },
  #|  { "name": "Carol", "age": 42, "city": "Shenzhen" },
  #|  { "name": "Dave", "age": 18, "city": "Chengdu" },
  #|  { "name": "Eve", "city": "Wuhan" }
  #|]

///|
test "run_query applies filter, limit and projection" {
  let result = @evaluator.run_query(
    user_data, "select name, age where age > 30 limit 1",
  )
  assert_eq(result, "[{\"name\":\"Bob\",\"age\":35}]")
}

///|
test "run_query projects a subset of fields for every match" {
  let result = @evaluator.run_query(
    user_data, "select name, city where age > 30",
  )
  assert_eq(
    result, "[{\"name\":\"Bob\",\"city\":\"Shanghai\"},{\"name\":\"Carol\",\"city\":\"Shenzhen\"}]",
  )
}

///|
test "run_query keeps records intact when selecting '*'" {
  let result = @evaluator.run_query(user_data, "select *")
  assert_eq(
    result, "[{\"name\":\"Alice\",\"age\":30,\"city\":\"Beijing\"},{\"name\":\"Bob\",\"age\":35,\"city\":\"Shanghai\"},{\"name\":\"Carol\",\"age\":42,\"city\":\"Shenzhen\"},{\"name\":\"Dave\",\"age\":18,\"city\":\"Chengdu\"},{\"name\":\"Eve\",\"city\":\"Wuhan\"}]",
  )
}

///|
test "run_query drops records with missing or non-numeric filter fields" {
  let data =
    #|[
    #|  { "name": "numeric", "age": 20 },
    #|  { "name": "missing" },
    #|  { "name": "textual", "age": "30" }
    #|]
  let result = @evaluator.run_query(data, "select name where age > 10")
  assert_eq(result, "[{\"name\":\"numeric\"}]")
}

///|
test "run_query returns an empty array when nothing matches" {
  let result = @evaluator.run_query(user_data, "select name where age > 100")
  assert_eq(result, "[]")
}

///|
test "run_query clamps an oversized limit to the available records" {
  let result = @evaluator.run_query(user_data, "select name limit 100")
  assert_eq(
    result, "[{\"name\":\"Alice\"},{\"name\":\"Bob\"},{\"name\":\"Carol\"},{\"name\":\"Dave\"},{\"name\":\"Eve\"}]",
  )
}

///|
test "execute filters, limits and projects parsed data" {
  let data : Array[Json] = [
    Json::object({ "name": Json::string("Alice"), "age": Json::number(30.0) }),
    Json::object({ "name": Json::string("Bob"), "age": Json::number(35.0) }),
    Json::object({ "name": Json::string("Carol"), "age": Json::number(42.0) }),
  ]
  let query : @parser.Query = {
    fields: ["name", "age"],
    filter: Some(@parser.Expr::Gt("age", 31.0)),
    limit: Some(1),
  }
  let expected : Array[Json] = [
    Json::object({ "name": Json::string("Bob"), "age": Json::number(35.0) }),
  ]
  assert_eq(@evaluator.execute(query, data), expected)
}

///|
test "run_query reports an invalid query as an error document" {
  let result = @evaluator.run_query(user_data, "select")
  assert_eq(result, "{\"error\":\"expected field name\"}")
}

///|
test "run_query reports malformed JSON as an error document" {
  let result = @evaluator.run_query("[", "select *")
  assert_true(result.has_prefix("{\"error\":\"invalid JSON input"))
}

///|
test "run_query rejects a document that is not an array" {
  let result = @evaluator.run_query("{\"a\": 1}", "select *")
  assert_eq(result, "{\"error\":\"expected a JSON array of records\"}")
}

///|
test "run_query handles a non-array document and a zero limit" {
  // A top-level document that is not an array is reported, never panicked on.
  assert_eq(
    @evaluator.run_query("\"just a string\"", "select *"),
    "{\"error\":\"expected a JSON array of records\"}",
  )
  assert_eq(
    @evaluator.run_query("123", "select *"),
    "{\"error\":\"expected a JSON array of records\"}",
  )
  // `limit 0` yields an empty result instead of raising.
  assert_eq(@evaluator.run_query(user_data, "select name limit 0"), "[]")
  // An empty input array stays empty, whatever the query asks for.
  assert_eq(@evaluator.run_query("[]", "select * limit 5"), "[]")
}

///|
test "run_query supports < and <= filters" {
  assert_eq(
    @evaluator.run_query(user_data, "select name where age < 30"),
    "[{\"name\":\"Dave\"}]",
  )
  assert_eq(
    @evaluator.run_query(user_data, "select name where age <= 30"),
    "[{\"name\":\"Alice\"},{\"name\":\"Dave\"}]",
  )
}

///|
test "run_query supports >= filters including the boundary" {
  assert_eq(
    @evaluator.run_query(user_data, "select name where age >= 35"),
    "[{\"name\":\"Bob\"},{\"name\":\"Carol\"}]",
  )
}

///|
test "run_query supports == and != filters" {
  assert_eq(
    @evaluator.run_query(user_data, "select name where age == 30"),
    "[{\"name\":\"Alice\"}]",
  )
  // Eve has no `age`, so even `!=` drops her: every comparison requires a
  // numeric field.
  assert_eq(
    @evaluator.run_query(user_data, "select name where age != 30"),
    "[{\"name\":\"Bob\"},{\"name\":\"Carol\"},{\"name\":\"Dave\"}]",
  )
  assert_eq(
    @evaluator.run_query(user_data, "select name where age != 100"),
    "[{\"name\":\"Alice\"},{\"name\":\"Bob\"},{\"name\":\"Carol\"},{\"name\":\"Dave\"}]",
  )
}

///|
test "run_query compares fractional numbers as doubles" {
  let data =
    #|[
    #|  { "name": "half", "score": 1.5 },
    #|  { "name": "two", "score": 2.0 },
    #|  { "name": "five-halves", "score": 2.5 }
    #|]
  assert_eq(
    @evaluator.run_query(data, "select name where score >= 2.0"),
    "[{\"name\":\"two\"},{\"name\":\"five-halves\"}]",
  )
  assert_eq(
    @evaluator.run_query(data, "select name where score == 2.0"),
    "[{\"name\":\"two\"}]",
  )
  assert_eq(
    @evaluator.run_query(data, "select name where score < 2.5"),
    "[{\"name\":\"half\"},{\"name\":\"two\"}]",
  )
  assert_eq(
    @evaluator.run_query(data, "select name where score != 2.0"),
    "[{\"name\":\"half\"},{\"name\":\"five-halves\"}]",
  )
}

///|
test "execute evaluates new AST nodes directly" {
  let data : Array[Json] = [
    Json::object({ "name": Json::string("Alice"), "age": Json::number(30.0) }),
    Json::object({ "name": Json::string("Bob"), "age": Json::number(35.0) }),
  ]
  let le_query : @parser.Query = {
    fields: ["name"],
    filter: Some(@parser.Expr::Le("age", 30.0)),
    limit: None,
  }
  let ne_query : @parser.Query = {
    fields: ["name"],
    filter: Some(@parser.Expr::Ne("age", 30.0)),
    limit: None,
  }
  let expected_le : Array[Json] = [
    Json::object({ "name": Json::string("Alice") }),
  ]
  let expected_ne : Array[Json] = [
    Json::object({ "name": Json::string("Bob") }),
  ]
  assert_eq(@evaluator.execute(le_query, data), expected_le)
  assert_eq(@evaluator.execute(ne_query, data), expected_ne)
}
