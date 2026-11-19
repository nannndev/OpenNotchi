// Safe math expression evaluator & unit converter (no eval / Function).

export interface CalcResult {
  value: number
  formatted: string
  unit?: string
}

const LENGTH_TO_M: Record<string, number> = {
  mm: 0.001,
  cm: 0.01,
  m: 1,
  km: 1000,
  in: 0.0254,
  inch: 0.0254,
  ft: 0.3048,
  yd: 0.9144,
  mi: 1609.344,
}

const MASS_TO_G: Record<string, number> = {
  mg: 0.001,
  g: 1,
  kg: 1000,
  oz: 28.349523125,
  lb: 453.59237,
  lbs: 453.59237,
}

const DATA_TO_BYTES: Record<string, number> = {
  b: 1,
  kb: 1024,
  mb: 1024 ** 2,
  gb: 1024 ** 3,
  tb: 1024 ** 4,
}

const TIME_TO_SEC: Record<string, number> = {
  ms: 0.001,
  s: 1,
  sec: 1,
  min: 60,
  m: 60,
  h: 3600,
  hr: 3600,
  d: 86400,
  day: 86400,
}

export function formatNumber(n: number): string {
  if (!Number.isFinite(n)) return "Error"
  if (Math.abs(n) >= 1e12 || (Math.abs(n) > 0 && Math.abs(n) < 1e-6)) {
    return n.toExponential(4)
  }
  const rounded = Math.round(n * 1e8) / 1e8
  return rounded.toLocaleString("en-US", { maximumFractionDigits: 6 })
}

export function evaluateCalc(raw: string): CalcResult | null {
  const input = raw.trim()
  if (!input) return null

  // 1. Unit conversion: "<expr> <from> to <to>" or "<expr> <from> in <to>"
  const convMatch = input.match(/^(.+?)\s+([a-zA-Z]+)\s+(?:to|in)\s+([a-zA-Z]+)$/i)
  if (convMatch) {
    const [, lhs, fromRaw, toRaw] = convMatch
    const base = parseMath(lhs)
    if (base !== null) {
      const converted = convertUnit(base, fromRaw.toLowerCase(), toRaw.toLowerCase())
      if (converted !== null) {
        return { value: converted, formatted: `${formatNumber(converted)} ${toRaw}`, unit: toRaw }
      }
    }
  }

  // 2. "X% of Y"
  const pctOf = input.match(/^(-?\d+(?:\.\d+)?)\s*%\s+of\s+(.+)$/i)
  if (pctOf) {
    const pct = Number(pctOf[1])
    const rhs = parseMath(pctOf[2])
    if (Number.isFinite(pct) && rhs !== null) {
      const val = (pct / 100) * rhs
      return { value: val, formatted: formatNumber(val) }
    }
  }

  // 3. Pure math expression
  const val = parseMath(input)
  if (val === null || !Number.isFinite(val)) return null
  return { value: val, formatted: formatNumber(val) }
}

function convertUnit(val: number, from: string, to: string): number | null {
  // Temperature
  if ((from === "c" || from === "celsius") && (to === "f" || to === "fahrenheit")) return (val * 9) / 5 + 32
  if ((from === "f" || from === "fahrenheit") && (to === "c" || to === "celsius")) return ((val - 32) * 5) / 9
  if ((from === "c" || from === "celsius") && (to === "k" || to === "kelvin")) return val + 273.15
  if ((from === "k" || from === "kelvin") && (to === "c" || to === "celsius")) return val - 273.15

  for (const table of [LENGTH_TO_M, MASS_TO_G, DATA_TO_BYTES, TIME_TO_SEC]) {
    if (from in table && to in table) {
      return (val * table[from]) / table[to]
    }
  }
  return null
}

// Recursive descent parser for arithmetic expressions
function parseMath(expr: string): number | null {
  const rawTokens = tokenize(expr)
  if (!rawTokens || rawTokens.length === 0) return null
  const tokens: string[] = rawTokens
  let pos = 0

  const peek = () => tokens[pos]
  const consume = () => tokens[pos++]

  function parseAddSub(): number {
    let left = parseMulDiv()
    while (peek() === "+" || peek() === "-") {
      const op = consume()
      const right = parseMulDiv()
      left = op === "+" ? left + right : left - right
    }
    return left
  }

  function parseMulDiv(): number {
    let left = parsePower()
    while (peek() === "*" || peek() === "/" || peek() === "%") {
      const op = consume()
      const right = parsePower()
      if (op === "*") left *= right
      else if (op === "/") left /= right
      else left %= right
    }
    return left
  }

  function parsePower(): number {
    const base = parseUnary()
    if (peek() === "^") {
      consume()
      const exp = parsePower()
      return Math.pow(base, exp)
    }
    return base
  }

  function parseUnary(): number {
    if (peek() === "-") {
      consume()
      return -parseUnary()
    }
    if (peek() === "+") {
      consume()
      return parseUnary()
    }
    return parsePrimary()
  }

  function parsePrimary(): number {
    const t = peek()
    if (!t) throw new Error("Unexpected end")

    if (t === "(") {
      consume()
      const val = parseAddSub()
      if (peek() !== ")") throw new Error("Missing )")
      consume()
      return val
    }

    // Constants
    if (t === "pi") {
      consume()
      return Math.PI
    }
    if (t === "e") {
      consume()
      return Math.E
    }

    // Functions
    if (/^(sqrt|sin|cos|tan|abs|log|ln|round|floor|ceil)$/.test(t)) {
      const fn = consume()
      if (peek() !== "(") throw new Error("Expected (")
      consume()
      const arg = parseAddSub()
      if (peek() !== ")") throw new Error("Expected )")
      consume()
      switch (fn) {
        case "sqrt": return Math.sqrt(arg)
        case "sin": return Math.sin(arg)
        case "cos": return Math.cos(arg)
        case "tan": return Math.tan(arg)
        case "abs": return Math.abs(arg)
        case "log": return Math.log10(arg)
        case "ln": return Math.log(arg)
        case "round": return Math.round(arg)
        case "floor": return Math.floor(arg)
        case "ceil": return Math.ceil(arg)
      }
    }

    const num = Number(t)
    if (!Number.isNaN(num)) {
      consume()
      // Trailing percent literal (e.g. 50% -> 0.5)
      if (peek() === "%" && (!tokens[pos + 1] || /[+\-*/)]/.test(tokens[pos + 1]))) {
        consume()
        return num / 100
      }
      return num
    }

    throw new Error(`Unexpected token: ${t}`)
  }

  try {
    const result = parseAddSub()
    if (pos !== tokens.length) return null
    return result
  } catch {
    return null
  }
}

function tokenize(expr: string): string[] | null {
  const cleaned = expr.replace(/×/g, "*").replace(/÷/g, "/").replace(/,/g, "")
  const re = /\s*(\d+(?:\.\d+)?|[a-zA-Z]+|[+\-*/^%()])\s*/g
  const out: string[] = []
  let idx = 0
  while (idx < cleaned.length) {
    re.lastIndex = idx
    const m = re.exec(cleaned)
    if (!m || m.index !== idx) return null
    out.push(m[1].toLowerCase())
    idx = re.lastIndex
  }
  return out
}
