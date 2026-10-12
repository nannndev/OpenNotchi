export const REPO = "nannndev/OpenNotchi"
export const REPO_URL = `https://github.com/${REPO}`
export const RELEASES_URL = `${REPO_URL}/releases`
export const LATEST_DMG_URL = `${REPO_URL}/releases/latest/download/OpenNotchi.dmg`
export const LATEST_ZIP_URL = `${REPO_URL}/releases/latest/download/OpenNotchi.zip`
export const CHANGELOG_URL = `${REPO_URL}/blob/main/CHANGELOG.md`
export const SITE_URL = "https://opennotchi.vercel.app"

export type SupportLink = {
  name: string
  url: string
  description: string
  /** Brand styling for the button. */
  brand: "buymeacoffee" | "saweria"
}

/**
 * Donation links shown in the Support section. Entries without a username are
 * hidden, so the section still works before the accounts are set up.
 */
const BUY_ME_A_COFFEE_USERNAME = ""
const SAWERIA_USERNAME = "nannndev"

export const SUPPORT_LINKS: SupportLink[] = [
  {
    name: "Buy me a coffee",
    url: `https://buymeacoffee.com/${BUY_ME_A_COFFEE_USERNAME}`,
    description: "Support with a card or PayPal",
    brand: "buymeacoffee" as const,
  },
  {
    name: "Saweria",
    url: `https://saweria.co/${SAWERIA_USERNAME}`,
    description: "Dukung lewat QRIS, GoPay, OVO, DANA",
    brand: "saweria" as const,
  },
].filter((link) => !link.url.endsWith("/"))
