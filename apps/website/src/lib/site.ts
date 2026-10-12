export const REPO = "nannndev/OpenNotchi"
export const REPO_URL = `https://github.com/${REPO}`
export const RELEASES_URL = `${REPO_URL}/releases`
export const LATEST_DMG_URL = `${REPO_URL}/releases/latest/download/OpenNotchi.dmg`
export const LATEST_ZIP_URL = `${REPO_URL}/releases/latest/download/OpenNotchi.zip`
export const CHANGELOG_URL = `${REPO_URL}/blob/main/CHANGELOG.md`
export const SITE_URL = "https://opennotchi.vercel.app"

export type SupportLink = { name: string; url: string; description: string }

/**
 * Donation links shown in the Support section. Leave empty to show only the
 * GitHub star / share / contribute options.
 */
export const SUPPORT_LINKS: SupportLink[] = []
