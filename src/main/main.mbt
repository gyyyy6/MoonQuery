///|
/// Dataset used when no JSON argument is supplied, so that
/// `moon run src/main -- "select name where age > 30"` works out of the box.
let demo_data : String =
  #|[
  #|  { "name": "Alice", "age": 30, "city": "Beijing" },
  #|  { "name": "Bob", "age": 35, "city": "Shanghai" },
  #|  { "name": "Carol", "age": 42, "city": "Shenzhen" },
  #|  { "name": "Dave", "age": 18, "city": "Chengdu" },
  #|  { "name": "Eve", "city": "Wuhan" }
  #|]

///|
/// Help text shown by `-h` / `--help` and on argument errors.
let usage_text : String =
  #|MoonQuery - a tiny SELECT engine over JSON
  #|
  #|Usage:
  #|  moon run src/main -- <query> [json]
  #|  moon run src/main -- --query <query> [--json <json>]
  #|
  #|Arguments:
  #|  <query>  Query, e.g. "select name, age where age > 30 limit 2".
  #|           Supported: `select <fields|*>`, `where <field> > <number>`, `limit <n>`.
  #|  [json]   JSON array to query. Defaults to the built-in demo dataset.
  #|
  #|Options:
  #|  -q, --query <query>  Query string (same as the first positional argument)
  #|  -j, --json  <json>   JSON array (same as the second positional argument)
  #|  -h, --help           Print this message
  #|
  #|Examples:
  #|
  #|  # 1) Scan the built-in demo dataset
  #|  moon run src/main -- "select *"
  #|
  #|  # 2) Filter + limit; records without a numeric age are dropped
  #|  moon run src/main -- "select name, age where age > 30 limit 2"
  #|  #   -> [{"name":"Bob","age":35},{"name":"Carol","age":42}]
  #|
  #|  # 3) Query an inline JSON array
  #|  moon run src/main -- "select name, city" "[{"name":"Bob","age":35,"city":"Shanghai"}]"
  #|  #   -> [{"name":"Bob","city":"Shanghai"}]
  #|
  #|  # 4) Flags instead of positional arguments
  #|  moon run src/main -- --query "select * limit 1" --json "[{"a":1,"b":2}]"
  #|  #   -> [{"a":1,"b":2}]
  #|
  #|  # 5) JSON omitted -> the built-in demo dataset is used
  #|  moon run src/main -- "select name where age > 40"
  #|  #   -> [{"name":"Carol"}]
  #|
  #|  # 6) Errors never panic, they come back as a JSON document
  #|  moon run src/main -- "select where"
  #|  #   -> {"error":"expected field name"}
  #|
  #|  # 7) Projection: * keeps every field of each record
  #|  moon run src/main -- "select * limit 1"
  #|
  #|  # 8) Help
  #|  moon run src/main -- --help

///|
/// Split the raw arguments (program name included) into `(query, json)`.
fn parse_args(raw : Array[String]) -> Result[(String, String), String] {
  let mut query : String? = None
  let mut json : String? = None
  let positional : Array[String] = []
  let mut index = 1
  while index < raw.length() {
    let arg = raw[index]
    match arg {
      "-q" | "--query" => {
        if index + 1 >= raw.length() {
          return Err("missing value for " + arg)
        }
        query = Some(raw[index + 1])
        index = index + 1
      }
      "-j" | "--json" => {
        if index + 1 >= raw.length() {
          return Err("missing value for " + arg)
        }
        json = Some(raw[index + 1])
        index = index + 1
      }
      _ => positional.push(arg)
    }
    index = index + 1
  }
  let query = match query {
    Some(value) => value
    None =>
      match positional.get(0) {
        Some(value) => value
        None => return Err("no query given")
      }
  }
  let json = match json {
    Some(value) => value
    None =>
      match positional.get(1) {
        Some(value) => value
        None => demo_data
      }
  }
  Ok((query, json))
}

///|
/// CLI entry point: `moon run src/main -- <query> [json]`.
fn main {
  let raw = @env.args()
  if raw.contains("-h") || raw.contains("--help") {
    println(usage_text)
    return
  }
  match parse_args(raw) {
    Ok((query, json)) => println(@evaluator.run_query(json, query))
    Err(message) => {
      println("error: " + message)
      println("")
      println(usage_text)
    }
  }
}
