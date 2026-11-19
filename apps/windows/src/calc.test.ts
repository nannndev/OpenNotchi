import assert from "node:assert/strict"
import test from "node:test"
import { evaluateCalc } from "./calc.ts"

test("evaluateCalc evaluates arithmetic expressions with precedence", () => {
  assert.equal(evaluateCalc("2 + 3 * 4")?.value, 14)
  assert.equal(evaluateCalc("(2 + 3) * 4")?.value, 20)
  assert.equal(evaluateCalc("2 ^ 10")?.value, 1024)
  assert.equal(evaluateCalc("sqrt(144)")?.value, 12)
})

test("evaluateCalc evaluates percentages", () => {
  assert.equal(evaluateCalc("20% of 450")?.value, 90)
})

test("evaluateCalc converts units across length, data, and temperature", () => {
  assert.ok(Math.abs((evaluateCalc("100 c to f")?.value ?? 0) - 212) < 0.001)
  assert.ok(Math.abs((evaluateCalc("1024 mb to gb")?.value ?? 0) - 1) < 0.001)
  assert.equal(evaluateCalc("10 km to m")?.value, 10000)
})

test("evaluateCalc returns null for invalid input", () => {
  assert.equal(evaluateCalc(""), null)
  assert.equal(evaluateCalc("2 + * 3"), null)
})
