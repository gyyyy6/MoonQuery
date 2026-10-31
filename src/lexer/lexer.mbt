///|
pub(all) enum Token {
  Select
  Where
  Limit
  Contains
  StartsWith
  Identifier(String)
  Number(Double)
  StringLit(String)
  GT
  GE
  LT
  LE
  EQ
  NE
  Comma
  EOF
  LexError(String)
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
/// Scan a double-quoted string literal starting at `start`.
///
/// Returns the decoded contents, the index just past the closing quote, and
/// whether a closing quote was found. Common escapes (`\"`, `\\`, `\n`, `\t`,
/// `\r`) are decoded; an unknown escape is preserved verbatim.
fn scan_string_literal(
  chars : Array[Char],
  start : Int32,
) -> (String, Int32, Bool) {
  let builder = StringBuilder()
  let length = chars.length()
  let mut i = start + 1
  while i < length {
    let c = chars[i]
    if c == '"' {
      return (builder.to_string(), i + 1, true)
    } else if c == '\\' && i + 1 < length {
      match chars[i + 1] {
        '"' => builder.write_char('"')
        '\\' => builder.write_char('\\')
        'n' => builder.write_char('\n')
        't' => builder.write_char('\t')
        'r' => builder.write_char('\r')
        escaped => {
          builder.write_char('\\')
          builder.write_char(escaped)
        }
      }
      i = i + 2
    } else {
      builder.write_char(c)
      i = i + 1
    }
  }
  (builder.to_string(), length, false)
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
    } else if c == '"' {
      let (text, next, closed) = scan_string_literal(chars, i)
      if closed {
        tokens.push(StringLit(text))
      } else {
        tokens.push(LexError("unterminated string literal"))
      }
      i = next
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
        "contains" => tokens.push(Contains)
        "startswith" => tokens.push(StartsWith)
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
