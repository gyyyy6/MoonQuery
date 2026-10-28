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
