// Smoke test for the staged Web Playground artifacts.
//
// Usage: node scripts/smoke-web.cjs <web-dir>
//
// Loads the classic-script build and checks that the exported engine answers a
// simple query correctly.

const path = require("path");

const web = process.argv[2];
if (!web) {
  console.error("usage: node scripts/smoke-web.cjs <web-dir>");
  process.exit(2);
}

require(path.join(web, "moonquery.global.js"));

const actual = globalThis.run_query_js(
  '[{"name":"Bob","age":35},{"name":"Ann","age":20}]',
  "select name where age > 30",
);
const expected = '[{"name":"Bob"}]';

if (actual !== expected) {
  console.error("smoke test failed\n  expected: " + expected + "\n  actual:   " + actual);
  process.exit(1);
}

console.log("smoke test ok: " + actual);