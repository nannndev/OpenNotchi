import { Plus, RefreshCw, TrendingDown, TrendingUp, X } from "lucide-react"
import { useCallback, useEffect, useState } from "react"
import { useSettings } from "../settings"

interface TickerData {
  symbol: string
  price: number
  changePct: number
  high24h: number
  low24h: number
}

export function MarketsTab() {
  const [settings, setSettings] = useSettings()
  const [tickers, setTickers] = useState<TickerData[]>([])
  const [loading, setLoading] = useState(false)
  const [adding, setAdding] = useState(false)
  const [newSym, setNewSym] = useState("")
  const [error, setError] = useState<string | null>(null)

  const symbols = settings.marketSymbols?.length ? settings.marketSymbols : ["BTCUSDT", "ETHUSDT", "SOLUSDT", "BNBUSDT"]

  const fetchQuotes = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      const encoded = encodeURIComponent(JSON.stringify(symbols))
      const res = await fetch(`https://api.binance.com/api/v3/ticker/24hr?symbols=${encoded}`)
      if (!res.ok) throw new Error(`HTTP ${res.status}`)
      const rows = (await res.json()) as Array<{
        symbol: string
        lastPrice: string
        priceChangePercent: string
        highPrice: string
        lowPrice: string
      }>
      const mapped: TickerData[] = rows.map((r) => ({
        symbol: r.symbol,
        price: Number(r.lastPrice),
        changePct: Number(r.priceChangePercent),
        high24h: Number(r.highPrice),
        low24h: Number(r.lowPrice),
      }))
      setTickers(mapped)
    } catch {
      setError("Offline or rate-limited")
    } finally {
      setLoading(false)
    }
  }, [symbols.join(",")])

  useEffect(() => {
    fetchQuotes()
    const id = window.setInterval(fetchQuotes, 15000)
    return () => window.clearInterval(id)
  }, [fetchQuotes])

  const addSymbol = () => {
    const clean = newSym.trim().toUpperCase()
    if (!clean) return
    const full = clean.endsWith("USDT") ? clean : `${clean}USDT`
    if (!symbols.includes(full)) {
      setSettings({ marketSymbols: [...symbols, full] })
    }
    setNewSym("")
    setAdding(false)
  }

  const removeSymbol = (sym: string) => {
    if (symbols.length <= 1) return
    setSettings({ marketSymbols: symbols.filter((s) => s !== sym) })
  }

  return (
    <div className="markets-tab">
      <div className="markets-hdr">
        <span className="markets-title">Live Crypto Watchlist</span>
        <div className="markets-actions">
          {adding ? (
            <form
              className="markets-add-form"
              onSubmit={(e) => {
                e.preventDefault()
                addSymbol()
              }}
            >
              <input
                value={newSym}
                onChange={(e) => setNewSym(e.target.value)}
                placeholder="DOGE…"
                autoFocus
              />
              <button type="submit">Add</button>
              <button type="button" onClick={() => setAdding(false)}><X size={10} /></button>
            </form>
          ) : (
            <button type="button" className="markets-btn" onClick={() => setAdding(true)} title="Add ticker">
              <Plus size={11} />
            </button>
          )}
          <button type="button" className="markets-btn" onClick={fetchQuotes} title="Refresh quotes">
            <RefreshCw size={11} className={loading ? "spin" : ""} />
          </button>
        </div>
      </div>

      {error && tickers.length === 0 ? (
        <div className="markets-empty">{error}</div>
      ) : (
        <div className="markets-grid">
          {tickers.map((t) => {
            const up = t.changePct >= 0
            const base = t.symbol.replace(/USDT$/, "")
            const span = Math.max(1e-9, t.high24h - t.low24h)
            const rangePct = Math.min(100, Math.max(0, ((t.price - t.low24h) / span) * 100))

            return (
              <div key={t.symbol} className="market-card">
                <div className="market-card-top">
                  <span className="market-sym">{base}</span>
                  <span className={`market-chg ${up ? "up" : "down"}`}>
                    {up ? <TrendingUp size={10} /> : <TrendingDown size={10} />}
                    {up ? "+" : ""}{t.changePct.toFixed(2)}%
                  </span>
                  {symbols.length > 1 && (
                    <button
                      type="button"
                      className="market-rm"
                      onClick={() => removeSymbol(t.symbol)}
                      title={`Remove ${base}`}
                    >
                      <X size={9} />
                    </button>
                  )}
                </div>
                <div className="market-price">
                  ${t.price >= 100 ? t.price.toLocaleString("en-US", { maximumFractionDigits: 2 }) : t.price.toPrecision(5)}
                </div>
                <div className="market-range" title={`24h range: $${t.low24h} – $${t.high24h}`}>
                  <i style={{ width: `${rangePct}%` }} className={up ? "up" : "down"} />
                </div>
              </div>
            )
          })}
        </div>
      )}
    </div>
  )
}
