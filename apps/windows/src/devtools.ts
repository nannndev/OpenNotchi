// Formatting helpers for the Dev tab, kept free of React so they're unit-tested.

/** 1536 → "1.5 KB", 8_589_934_592 → "8.0 GB". */
export function formatBytes(n: number): string {
  const units = ["B", "KB", "MB", "GB", "TB"]
  let i = 0
  while (n >= 1024 && i < units.length - 1) {
    n /= 1024
    i++
  }
  return i === 0 ? `${Math.round(n)} B` : `${n.toFixed(1)} ${units[i]}`
}

/** Bytes per second as "1.2 MB/s". */
export const formatRate = (bps: number) => `${formatBytes(Math.max(0, bps))}/s`

/** Ports a dev server likely serves a page on; Windows' own service ports (135, 445, 5040…) get no "open" button. */
export function isLocalWebPort(port: number): boolean {
  if ([80, 443, 8080, 8000, 8888, 4200, 5000, 5173, 5174, 3000, 3001, 4173, 4321, 8081, 9000].includes(port)) return true
  return port >= 3000 && port < 10000 && ![5040, 5357, 7680].includes(port)
}
