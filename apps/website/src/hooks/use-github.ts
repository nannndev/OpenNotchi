import { useEffect, useState } from "react"
import { REPO } from "@/lib/site"

const API = `https://api.github.com/repos/${REPO}`

export type ReleaseAsset = { name: string; size: number; download_count: number; browser_download_url: string }
export type Release = { tag_name: string; published_at: string; html_url: string; assets: ReleaseAsset[] }
export type Repo = { stargazers_count: number; forks_count: number }
export type Contributor = { login: string; avatar_url: string; html_url: string; contributions: number; type: string }

/** Fetches a GitHub API path, cached in sessionStorage to stay under the rate limit. */
function useGitHub<T>(path: string, maxAgeMinutes: number) {
  const [data, setData] = useState<T | null>(null)
  const [error, setError] = useState(false)

  useEffect(() => {
    const key = `gh:${path}`
    try {
      const hit = JSON.parse(sessionStorage.getItem(key) ?? "null")
      if (hit && Date.now() - hit.t < maxAgeMinutes * 60_000) {
        setData(hit.v)
        return
      }
    } catch {
      // Storage unavailable: just fetch.
    }

    let cancelled = false
    fetch(`${API}${path}`, { headers: { Accept: "application/vnd.github+json" } })
      .then((r) => (r.ok ? r.json() : Promise.reject(r.status)))
      .then((value: T) => {
        if (cancelled) return
        setData(value)
        try {
          sessionStorage.setItem(key, JSON.stringify({ t: Date.now(), v: value }))
        } catch {
          // Ignore quota or privacy-mode errors.
        }
      })
      .catch(() => !cancelled && setError(true))
    return () => {
      cancelled = true
    }
  }, [path, maxAgeMinutes])

  return { data, error, loading: !data && !error }
}

export const useLatestRelease = () => useGitHub<Release>("/releases/latest", 10)
export const useRepo = () => useGitHub<Repo>("", 10)
export const useReleases = () => useGitHub<Release[]>("/releases?per_page=100", 10)

/** Total .dmg and .zip downloads across every release (null while loading). */
export function useDownloadCount() {
  const { data } = useReleases()
  if (!data) return null
  return data
    .flatMap((release) => release.assets)
    .filter((asset) => /^OpenNotchi.*\.(dmg|zip)$/.test(asset.name))
    .reduce((sum, asset) => sum + asset.download_count, 0)
}

export function formatCount(n: number) {
  return new Intl.NumberFormat("en", { notation: n >= 10_000 ? "compact" : "standard" }).format(n)
}

export const useContributors = () => useGitHub<Contributor[]>("/contributors?per_page=100", 30)

export function formatSize(bytes: number) {
  return bytes > 1e6 ? `${(bytes / 1e6).toFixed(1)} MB` : `${Math.round(bytes / 1e3)} KB`
}
