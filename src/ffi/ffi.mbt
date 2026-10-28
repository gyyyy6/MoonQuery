///|
/// JavaScript / Wasm entry point for the Web Playground.
///
/// Thin wrapper around `@evaluator.run_query`: takes the JSON document and the
/// query as strings and returns the resulting JSON document (or an
/// `{"error": ...}` document) as a string.
#export_name("run_query_js")
pub fn run_query_js(json_str : String, query_str : String) -> String {
  @evaluator.run_query(json_str, query_str)
}
