import { Check, Copy, Search, Trash2 } from "lucide-react"
import { useEffect, useState } from "react"

interface ClipboardItem {
  id: string
  text: string
  timestamp: number
}

const STORAGE_KEY = "opennotchi_clipboard_v1"

function loadHistory(): ClipboardItem[] {
  try {
    const raw = localStorage.getItem(STORAGE_KEY)
    if (!raw) {
      return [
        { id: "1", text: "Welcome to OpenNotchi for Windows! 🚀", timestamp: Date.now() - 60000 },
        { id: "2", text: "https://github.com/nannndev/OpenNotchi", timestamp: Date.now() - 120000 },
      ]
    }
    return JSON.parse(raw)
  } catch {
    return []
  }
}

function saveHistory(items: ClipboardItem[]) {
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(items.slice(0, 30)))
  } catch {}
}

export function ClipboardTab() {
  const [items, setItems] = useState<ClipboardItem[]>(loadHistory)
  const [search, setSearch] = useState("")
  const [copiedId, setCopiedId] = useState<string | null>(null)

  // Try to inspect clipboard when the tab is mounted or clicked
  useEffect(() => {
    const checkClipboard = async () => {
      try {
        if (!navigator.clipboard?.readText) return
        const text = await navigator.clipboard.readText()
        if (text && text.trim().length > 0) {
          setItems((prev) => {
            if (prev[0]?.text === text) return prev
            const next = [{ id: String(Date.now()), text, timestamp: Date.now() }, ...prev.filter((i) => i.text !== text)].slice(0, 30)
            saveHistory(next)
            return next
          })
        }
      } catch {
        // clipboard access might require focus or user permission
      }
    }
    checkClipboard()
  }, [])

  const copyItem = async (item: ClipboardItem) => {
    try {
      await navigator.clipboard.writeText(item.text)
      setCopiedId(item.id)
      setTimeout(() => setCopiedId((curr) => (curr === item.id ? null : curr)), 1200)
    } catch (e) {
      console.error(e)
    }
  }

  const deleteItem = (e: React.MouseEvent, id: string) => {
    e.stopPropagation()
    const next = items.filter((i) => i.id !== id)
    setItems(next)
    saveHistory(next)
  }

  const clearAll = () => {
    setItems([])
    saveHistory([])
  }

  const filtered = items.filter((item) => item.text.toLowerCase().includes(search.toLowerCase()))

  return (
    <div className="tab-clipboard">
      <div className="clipboard-header">
        <div className="clipboard-search">
          <Search size={13} className="search-icon" />
          <input
            type="text"
            placeholder="Search clipboard…"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
          />
          {search && (
            <button className="clear-search" onClick={() => setSearch("")}>
              ✕
            </button>
          )}
        </div>
        {items.length > 0 && (
          <button className="clipboard-clear-btn" onClick={clearAll} title="Clear all history">
            Clear
          </button>
        )}
      </div>

      <div className="clipboard-list">
        {filtered.length === 0 ? (
          <div className="clipboard-empty">
            <Copy size={22} className="empty-icon" />
            <span>{search ? "No matches found" : "Copied text will show up here"}</span>
          </div>
        ) : (
          filtered.map((item) => {
            const isCopied = copiedId === item.id
            return (
              <div
                key={item.id}
                className={`clipboard-row ${isCopied ? "copied" : ""}`}
                onClick={() => copyItem(item)}
              >
                <div className="clipboard-text" title={item.text}>
                  {item.text}
                </div>
                <div className="clipboard-actions">
                  {isCopied ? (
                    <span className="copied-badge">
                      <Check size={12} /> Copied
                    </span>
                  ) : (
                    <button
                      className="clipboard-del-btn"
                      onClick={(e) => deleteItem(e, item.id)}
                      title="Delete"
                    >
                      <Trash2 size={12} />
                    </button>
                  )}
                </div>
              </div>
            )
          })
        )}
      </div>
    </div>
  )
}
