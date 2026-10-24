import { invoke } from "@tauri-apps/api/core"
import { emit, listen } from "@tauri-apps/api/event"
import { useEffect, useState } from "react"
import pkg from "../package.json" with { type: "json" }

// Read from package.json so a version bump can never leave this stale (it once said 0.9.0 in a 0.10.0 build).
export const CURRENT_VERSION: string = pkg.version
export const GITHUB_REPO = "nannndev/OpenNotchi"

export interface UpdateInfo {
  available: boolean
  currentVersion: string
  latestVersion: string
  releaseName: string
  releaseNotes: string
  downloadUrl: string
  releaseUrl: string
  publishedAt: string
}

/**
 * Returns true if targetVersion is strictly newer than currentVersion.
 * Examples:
 *   compareSemver("0.1.0", "v0.1.1") => true
 *   compareSemver("0.1.0", "0.2.0")  => true
 *   compareSemver("0.1.0", "0.1.0")  => false
 *   compareSemver("0.2.0", "0.1.9")  => false
 */
export function compareSemver(currentVersion: string, targetVersion: string): boolean {
  const clean = (v: string) =>
    v
      .trim()
      .replace(/^[vV]/, "")
      .split(/[-+]/)[0]
      .split(".")
      .map((part) => parseInt(part, 10) || 0)

  const [curMaj = 0, curMin = 0, curPatch = 0] = clean(currentVersion)
  const [tarMaj = 0, tarMin = 0, tarPatch = 0] = clean(targetVersion)

  if (tarMaj !== curMaj) return tarMaj > curMaj
  if (tarMin !== curMin) return tarMin > curMin
  return tarPatch > curPatch
}

/** Open any external URL in default Windows browser */
export async function openExternalUrl(url: string): Promise<void> {
  try {
    await invoke("open_external_url", { url })
  } catch {
    window.open(url, "_blank")
  }
}

const UPDATE_CACHE_KEY = "opennotchi_cached_update"
const LAST_CHECK_KEY = "opennotchi_last_update_check"
const CHECK_INTERVAL_MS = 4 * 60 * 60 * 1000 // 4 hours

/** Queries GitHub Releases API for the latest release */
export async function checkForUpdates(
  currentVersion = CURRENT_VERSION,
): Promise<UpdateInfo> {
  const url = `https://api.github.com/repos/${GITHUB_REPO}/releases/latest`
  const res = await fetch(url, {
    headers: {
      Accept: "application/vnd.github.v3+json",
    },
  })

  if (!res.ok) {
    throw new Error(`GitHub API error: ${res.status} ${res.statusText}`)
  }

  const data = await res.json()
  const latestTag: string = data.tag_name || ""
  const isAvailable = compareSemver(currentVersion, latestTag)

  // Find Windows installer .exe asset in the release
  let downloadUrl = data.html_url || `https://github.com/${GITHUB_REPO}/releases`
  if (Array.isArray(data.assets)) {
    const exeAsset = data.assets.find(
      (a: { name?: string; browser_download_url?: string }) =>
        typeof a.name === "string" && a.name.toLowerCase().endsWith(".exe"),
    )
    if (exeAsset?.browser_download_url) {
      downloadUrl = exeAsset.browser_download_url
    }
  }

  const info: UpdateInfo = {
    available: isAvailable,
    currentVersion,
    latestVersion: latestTag.replace(/^[vV]/, ""),
    releaseName: data.name || latestTag,
    releaseNotes: data.body || "",
    downloadUrl,
    releaseUrl: data.html_url || downloadUrl,
    publishedAt: data.published_at || "",
  }

  try {
    localStorage.setItem(UPDATE_CACHE_KEY, JSON.stringify(info))
    localStorage.setItem(LAST_CHECK_KEY, String(Date.now()))
    emit("opennotchi-update-status", info).catch(() => {})
  } catch {}

  return info
}

/** Hook for live update checking and notification across Pill & Settings */
export function useUpdateChecker(): {
  updateInfo: UpdateInfo | null
  isChecking: boolean
  error: string | null
  checkNow: () => Promise<UpdateInfo | null>
} {
  const [updateInfo, setUpdateInfo] = useState<UpdateInfo | null>(() => {
    try {
      const cached = localStorage.getItem(UPDATE_CACHE_KEY)
      const info = cached ? (JSON.parse(cached) as UpdateInfo) : null
      // A cache written by an older install must not keep showing the update banner after upgrading.
      return info && info.currentVersion === CURRENT_VERSION ? info : null
    } catch {
      return null
    }
  })
  const [isChecking, setIsChecking] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const checkNow = async (): Promise<UpdateInfo | null> => {
    setIsChecking(true)
    setError(null)
    try {
      const info = await checkForUpdates()
      setUpdateInfo(info)
      return info
    } catch (e) {
      const msg = e instanceof Error ? e.message : "Failed to check for updates"
      setError(msg)
      return null
    } finally {
      setIsChecking(false)
    }
  }

  useEffect(() => {
    // Listen for broadcast update status from other windows
    const unlisten = listen<UpdateInfo>("opennotchi-update-status", ({ payload }) => {
      setUpdateInfo(payload)
    })

    // Check on startup if not checked in the last 4 hours
    try {
      const lastCheck = parseInt(localStorage.getItem(LAST_CHECK_KEY) || "0", 10)
      if (Date.now() - lastCheck > CHECK_INTERVAL_MS || !updateInfo) {
        checkNow().catch(() => {})
      }
    } catch {
      checkNow().catch(() => {})
    }

    return () => {
      unlisten.then((f) => f()).catch(() => {})
    }
  }, [])

  return { updateInfo, isChecking, error, checkNow }
}
