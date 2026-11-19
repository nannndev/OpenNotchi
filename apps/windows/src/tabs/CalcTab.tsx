import { Check, Copy, Trash2 } from "lucide-react"
import { useState } from "react"
import { evaluateCalc } from "../calc"

interface CalcHistoryItem {
  expr: string
  result: string
}

const QUICK_EXAMPLES = ["20% of 450", "1024 mb to gb", "32 c to f", "sqrt(144) * 3"]

export function CalcTab() {
  const [expr, setExpr] = useState("")
  const [history, setHistory] = useState<CalcHistoryItem[]>(() => {
    try {
      const raw = localStorage.getItem("opennotchi_calc_history")
      return raw ? JSON.parse(raw) : []
    } catch {
      return []
    }
  })
  const [copied, setCopied] = useState(false)

  const live = evaluateCalc(expr)

  const commit = () => {
    if (!live || !expr.trim()) return
    const next = [{ expr: expr.trim(), result: live.formatted }, ...history.slice(0, 9)]
    setHistory(next)
    try {
      localStorage.setItem("opennotchi_calc_history", JSON.stringify(next))
    } catch {}
    setExpr(String(live.value))
  }

  const copyResult = (text: string) => {
    navigator.clipboard?.writeText(text).catch(() => {})
    setCopied(true)
    setTimeout(() => setCopied(false), 1200)
  }

  return (
    <div className="calc-tab">
      <div className="calc-input-row">
        <input
          type="text"
          className="calc-input"
          value={expr}
          onChange={(e) => setExpr(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === "Enter") {
              e.preventDefault()
              commit()
            } else if (e.key === "Escape") {
              setExpr("")
            }
          }}
          placeholder="Type math or units (e.g. 20% of 450, 100 km to mi)…"
          autoFocus
        />
        {live && (
          <button
            type="button"
            className="calc-result-pill"
            onClick={() => copyResult(live.formatted)}
            title="Click to copy result"
          >
            <span>= {live.formatted}</span>
            {copied ? <Check size={11} /> : <Copy size={11} />}
          </button>
        )}
      </div>

      <div className="calc-lower">
        {history.length > 0 ? (
          <div className="calc-history">
            <div className="calc-hist-hdr">
              <span>Recent</span>
              <button
                type="button"
                onClick={() => {
                  setHistory([])
                  try { localStorage.removeItem("opennotchi_calc_history") } catch {}
                }}
                title="Clear history"
              >
                <Trash2 size={10} />
              </button>
            </div>
            <div className="calc-hist-list">
              {history.map((item, idx) => (
                <button
                  key={idx}
                  type="button"
                  className="calc-hist-row"
                  onClick={() => setExpr(item.expr)}
                >
                  <span className="expr">{item.expr}</span>
                  <span className="res">= {item.result}</span>
                </button>
              ))}
            </div>
          </div>
        ) : (
          <div className="calc-examples">
            <span className="calc-ex-label">Try:</span>
            {QUICK_EXAMPLES.map((ex) => (
              <button key={ex} type="button" className="calc-ex-chip" onClick={() => setExpr(ex)}>
                {ex}
              </button>
            ))}
          </div>
        )}
      </div>
    </div>
  )
}
