// Smoke test for the staged Web Playground artifacts.
//
// Usage: node scripts/smoke-web.cjs <web-dir>
//
// Loads the classic-script build and checks that the exported engine supports
// numeric filters, string matching, logical operators and nested field paths.

const path = require("path");

const web = process.argv[2];
if (!web) {
  console.error("usage: node scripts/smoke-web.cjs <web-dir>");
  process.exit(2);
}

require(path.join(web, "moonquery.global.js"));

const cases = [
  {
    name: "numeric filter",
    json: '[{"name":"Bob","age":35},{"name":"Ann","age":20}]',
    query: "select name where age > 30",
    expected: '[{"name":"Bob"}]',
  },
  {
    name: "AND / OR",
    json: '[{"name":"Bob","age":35},{"name":"Ann","age":20}]',
    query: 'select name where age > 30 or name == "Ann"',
    expected: '[{"name":"Bob"},{"name":"Ann"}]',
  },
  {
    name: "string matching",
    json: '[{"name":"Alice","profile":{"address":{"city":"Beijing"}}}]',
    query: 'select name where name startsWith "Al" and profile.address.city contains "jing"',
    expected: '[{"name":"Alice"}]',
  },
  {
    name: "nested projection",
    json: '[{"name":"Alice","profile":{"address":{"city":"Beijing"}}}]',
    query: 'select name, profile.address.city where profile.address.city == "Beijing"',
    expected: '[{"name":"Alice","profile":{"address":{"city":"Beijing"}}}]',
  },
  {
    name: "missing nested path",
    json: '[{"name":"Ann"}]',
    query: 'select name where profile.address.city == "Beijing"',
    expected: "[]",
  },
];

let failures = 0;
for (const test of cases) {
  const actual = globalThis.run_query_js(test.json, test.query);
  if (actual !== test.expected) {
    console.error(
      "smoke test failed: " +
        test.name +
        "\n  query:    " +
        test.query +
        "\n  expected: " +
        test.expected +
        "\n  actual:   " +
        actual,
    );
    failures += 1;
  } else {
    console.log("smoke test ok: " + test.name + " -> " + actual);
  }
}

if (failures > 0) {
  process.exit(1);
}