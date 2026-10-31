///|
pub(all) enum Token {
  Select
  Where
  Limit
  Identifier(String)
  Number(Double)
  GT
  GE
  LT
  LE
  EQ
  NE
  Comma
  EOF
} derive(Eq, Debug)

///|
pub extend Token with Eq::{not_equal, equal}

///|
pub extend Token with Debug::{to_repr}

///|
fn chars_to_string(chars : Array[Char], start : Int32, end : Int32) -> String {
  let builder = StringBuilder()
  let mut i = start
  while i < end {
    builder.write_char(chars[i])
    i = i + 1
  }
  builder.to_string()
}

///|
fn parse_number(text : String) -> Double {
  let chars = text.to_array()
  let mut value = 0.0
  let mut scale = 0.1
  let mut fractional = false
  let mut i = 0
  while i < chars.length() {
    let c = chars[i]
    if c == '.' {
      fractional = true
    } else {
      let digit = Double::from_int(c.to_int() - '0'.to_int())
      if fractional {
        value = value + digit * scale
        scale = scale / 10.0
      } else {
        value = value * 10.0 + digit
      }
    }
    i = i + 1
  }
  value
}

///|
pub fn tokenize(input : String) -> Array[Token] {
  let tokens : Array[Token] = []
  let chars = input.to_array()
  let length = chars.length()
  let mut i = 0
  while i < length {
    let c = chars[i]
    if c.is_ascii_whitespace() {
      i = i + 1
    } else if c == ',' {
      tokens.push(Comma)
      i = i + 1
    } else if c == '*' {
      tokens.push(Identifier("*"))
      i = i + 1
    } else if c == '>' {
      if i + 1 < length && chars[i + 1] == '=' {
        tokens.push(GE)
        i = i + 2
      } else {
        tokens.push(GT)
        i = i + 1
      }
    } else if c == '<' {
      if i + 1 < length && chars[i + 1] == '=' {
        tokens.push(LE)
        i = i + 2
      } else {
        tokens.push(LT)
        i = i + 1
      }
    } else if c == '=' {
      if i + 1 < length && chars[i + 1] == '=' {
        tokens.push(EQ)
        i = i + 2
      } else {
        i = i + 1
      }
    } else if c == '!' {
      if i + 1 < length && chars[i + 1] == '=' {
        tokens.push(NE)
        i = i + 2
      } else {
        i = i + 1
      }
    } else if c.is_ascii_alphabetic() {
      let start = i
      while i < length && chars[i].is_ascii_alphabetic() {
        i = i + 1
      }
      let word = chars_to_string(chars, start, i)
      match word.to_lower() {
        "select" => tokens.push(Select)
        "where" => tokens.push(Where)
        "limit" => tokens.push(Limit)
        _ => tokens.push(Identifier(word))
      }
    } else if c.is_ascii_digit() {
      let start = i
      while i < length && chars[i].is_ascii_digit() {
        i = i + 1
      }
      if i < length && chars[i] == '.' {
        i = i + 1
        while i < length && chars[i].is_ascii_digit() {
          i = i + 1
        }
      }
      tokens.push(Number(parse_number(chars_to_string(chars, start, i))))
    } else {
      i = i + 1
    }
  }
  tokens.push(EOF)
  tokens
}
