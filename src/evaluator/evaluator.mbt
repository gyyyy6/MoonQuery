///|
/// Whether the projection asks for every field of each record.
fn selects_all_fields(fields : Array[Array[String]]) -> Bool {
  fields.any(fn(field) { field.length() == 1 && field[0] == "*" })
}

///|
/// Resolve a dotted path inside a JSON value.
///
/// Every segment must name a member of a JSON object. A missing member, an
/// empty path, or an intermediate value that is not an object (for example a
/// string or a number where a nested object was expected) yields `None`.
fn lookup_path(value : Json, path : Array[String]) -> Json? {
  if path.length() == 0 {
    return None
  }
  let mut current = value
  for segment in path {
    match current {
      Object(object) =>
        match object.get(segment) {
          Some(child) => current = child
          None => return None
        }
      _ => return None
    }
  }
  Some(current)
}

///|
/// Read the value at `path` from a record as a number.
///
/// Returns `None` when the path is missing or its leaf is not a JSON number,
/// which is how the caller expresses "this record does not satisfy the filter".
fn numeric_at(value : Json, path : Array[String]) -> Double? {
  match lookup_path(value, path) {
    Some(Number(number, ..)) => Some(number)
    _ => None
  }
}

///|
/// Read the value at `path` from a record as a string.
///
/// Returns `None` when the path is missing or its leaf is not a JSON string,
/// so string filters drop records whose field has another type.
fn string_at(value : Json, path : Array[String]) -> String? {
  match lookup_path(value, path) {
    Some(String(text)) => Some(text)
    _ => None
  }
}

///|
/// Apply `predicate` to the numeric value at `path` in `value`.
///
/// Returns `false` when `value` is not an object, or when any path segment is
/// missing or the leaf is not a JSON number. Every comparison operator uses
/// this gate, so `!=` does not accidentally match records that simply lack the
/// field.
fn compare_numeric_field(
  value : Json,
  path : Array[String],
  predicate : (Double) -> Bool,
) -> Bool {
  match value {
    Object(_) =>
      match numeric_at(value, path) {
        Some(actual) => predicate(actual)
        None => false
      }
    _ => false
  }
}

///|
/// Apply `predicate` to the string value at `path` in `value`.
///
/// Missing paths and non-string leaves yield `false`, so string filters never
/// accidentally match a record of the wrong type.
fn compare_string_field(
  value : Json,
  path : Array[String],
  predicate : (String) -> Bool,
) -> Bool {
  match value {
    Object(_) =>
      match string_at(value, path) {
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
    @parser.Expr::Gt(path, threshold) =>
      compare_numeric_field(value, path, fn(actual) { actual > threshold })
    @parser.Expr::Ge(path, threshold) =>
      compare_numeric_field(value, path, fn(actual) { actual >= threshold })
    @parser.Expr::Lt(path, threshold) =>
      compare_numeric_field(value, path, fn(actual) { actual < threshold })
    @parser.Expr::Le(path, threshold) =>
      compare_numeric_field(value, path, fn(actual) { actual <= threshold })
    @parser.Expr::Eq(path, threshold) =>
      compare_numeric_field(value, path, fn(actual) { actual == threshold })
    @parser.Expr::Ne(path, threshold) =>
      compare_numeric_field(value, path, fn(actual) { actual != threshold })
    @parser.Expr::EqStr(path, expected) =>
      compare_string_field(value, path, fn(actual) { actual == expected })
    @parser.Expr::NeStr(path, expected) =>
      compare_string_field(value, path, fn(actual) { actual != expected })
    @parser.Expr::Contains(path, needle) =>
      compare_string_field(value, path, fn(actual) {
        actual.contains(needle.to_string_view())
      })
    @parser.Expr::StartsWith(path, prefix) =>
      compare_string_field(value, path, fn(actual) {
        actual.has_prefix(prefix.to_string_view())
      })
    @parser.Expr::And(left, right) =>
      // Short-circuit: a false left operand skips the right operand.
      if matches_filter(value, left) {
        matches_filter(value, right)
      } else {
        false
      }
    @parser.Expr::Or(left, right) =>
      // Short-circuit: a true left operand skips the right operand.
      if matches_filter(value, left) {
        true
      } else {
        matches_filter(value, right)
      }
  }
}

///|
/// Copy an object so that merging projected paths never mutates the input JSON.
fn clone_object(source : Map[String, Json]) -> Map[String, Json] {
  let copy : Map[String, Json] = Map([])
  for key, value in source {
    copy[key] = value
  }
  copy
}

///|
/// Insert `value` at `path` into the projected `target` object.
///
/// Intermediate objects are created on demand; an existing object is cloned
/// before being extended, so the original record stays untouched even when a
/// query selects both an ancestor and one of its descendants.
fn insert_path(
  target : Map[String, Json],
  path : Array[String],
  index : Int32,
  value : Json,
) -> Unit {
  let key = path[index]
  if index == path.length() - 1 {
    target[key] = value
    return
  }
  let child = match target.get(key) {
    Some(Object(existing)) => clone_object(existing)
    _ => Map([])
  }
  insert_path(child, path, index + 1, value)
  target[key] = Json::object(child)
}

///|
/// Project `value` onto `fields`, preserving the nested shape of dotted paths.
///
/// `*` keeps the record untouched. Missing paths are simply absent from the
/// result, and non-objects are passed through unchanged. Selecting a dotted
/// path, e.g. `profile.address.city`, produces
/// `{"profile":{"address":{"city": ...}}}` instead of a flattened key.
fn project(value : Json, fields : Array[Array[String]]) -> Json {
  if selects_all_fields(fields) {
    return value
  }
  match value {
    Object(_) => {
      let selected : Map[String, Json] = Map([])
      for path in fields {
        if path.length() > 0 {
          match lookup_path(value, path) {
            Some(field_value) => insert_path(selected, path, 0, field_value)
            None => ()
          }
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
