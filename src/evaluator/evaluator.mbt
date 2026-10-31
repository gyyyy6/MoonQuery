///|
/// Whether the projection asks for every field of each record.
fn selects_all_fields(fields : Array[String]) -> Bool {
  fields.any(fn(field) { field == "*" })
}

///|
/// Read `field` from `object` as a number.
///
/// Returns `None` when the field is missing or is not a JSON number, which is
/// how the caller expresses "this record does not satisfy the filter".
fn numeric_field(object : Map[String, Json], field : String) -> Double? {
  match object.get(field) {
    Some(Number(value, ..)) => Some(value)
    _ => None
  }
}

///|
/// Apply `predicate` to the numeric value of `field` in `value`.
///
/// Returns `false` when `value` is not an object, or when the field is missing
/// or not a JSON number. Every comparison operator uses this gate, so `!=`
/// does not accidentally match records that simply lack the field.
fn compare_numeric_field(
  value : Json,
  field : String,
  predicate : (Double) -> Bool,
) -> Bool {
  match value {
    Object(object) =>
      match numeric_field(object, field) {
        Some(actual) => predicate(actual)
        None => false
      }
    _ => false
  }
}

///|
/// Decide whether a single record satisfies a filter expression.
fn matches_filter(value : Json, filter : @parser.Expr) -> Bool {
  match filter {
    @parser.Expr::Gt(field, threshold) =>
      compare_numeric_field(value, field, fn(actual) { actual > threshold })
    @parser.Expr::Ge(field, threshold) =>
      compare_numeric_field(value, field, fn(actual) { actual >= threshold })
    @parser.Expr::Lt(field, threshold) =>
      compare_numeric_field(value, field, fn(actual) { actual < threshold })
    @parser.Expr::Le(field, threshold) =>
      compare_numeric_field(value, field, fn(actual) { actual <= threshold })
    @parser.Expr::Eq(field, threshold) =>
      compare_numeric_field(value, field, fn(actual) { actual == threshold })
    @parser.Expr::Ne(field, threshold) =>
      compare_numeric_field(value, field, fn(actual) { actual != threshold })
  }
}

///|
/// Project `value` onto `fields`.
///
/// `*` keeps the record untouched. Missing fields are simply absent from the
/// result, and non-objects are passed through unchanged.
fn project(value : Json, fields : Array[String]) -> Json {
  if selects_all_fields(fields) {
    return value
  }
  match value {
    Object(object) => {
      let selected : Map[String, Json] = Map([])
      for field in fields {
        match object.get(field) {
          Some(field_value) => selected[field] = field_value
          None => ()
        }
      }
      Json::object(selected)
    }
    _ => value
  }
}

///|
/// Run `query` against `data`: filter, then limit, then project.
pub fn execute(query : @parser.Query, data : Array[Json]) -> Array[Json] {
  let filtered = match query.filter {
    Some(filter) => data.filter(fn(value) { matches_filter(value, filter) })
    None => data
  }
  let limited = match query.limit {
    Some(limit) => {
      let count = if limit < 0 { 0 } else { limit }
      let count = if count > filtered.length() {
        filtered.length()
      } else {
        count
      }
      filtered[:count].to_owned()
    }
    None => filtered
  }
  limited.map(fn(value) { project(value, query.fields) })
}

///|
/// Render a `{"error": ...}` document for the failure paths of `run_query`.
fn error_json(message : String) -> String {
  let object : Map[String, Json] = { "error": Json::string(message) }
  Json::object(object).stringify()
}

///|
/// End-to-end entry point: tokenize and parse `query_str`, evaluate it against
/// the JSON document held in `json_str`, and return the matching records as a
/// compact JSON array.
///
/// Invalid queries, malformed JSON and non-array documents are reported as a
/// `{"error": "..."}` document instead of raising.
pub fn run_query(json_str : String, query_str : String) -> String {
  let tokens = @lexer.tokenize(query_str)
  let query = match @parser.parse(tokens) {
    Ok(query) => query
    Err(message) => return error_json(message)
  }
  let document = @json.parse(json_str) catch {
    error => return error_json("invalid JSON input: \{error}")
  }
  let data = match document {
    Array(items) => items
    _ => return error_json("expected a JSON array of records")
  }
  Json::array(execute(query, data)).stringify()
}
