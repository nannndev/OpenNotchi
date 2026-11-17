// Builds the notchi-gateway sidecar (apps/gateway) and places it where Tauri's
// `bundle.externalBin` expects it: src-tauri/binaries/notchi-gateway-<target-triple>[.exe].
import { execFileSync } from "node:child_process"
import { copyFileSync, mkdirSync } from "node:fs"
import { dirname, join } from "node:path"
import { fileURLToPath } from "node:url"

const here = dirname(fileURLToPath(import.meta.url))
const gateway = join(here, "..", "..", "gateway")
const triple =
  process.env.TAURI_ENV_TARGET_TRIPLE ||
  execFileSync("rustc", ["-vV"], { encoding: "utf8" })
    .split("\n")
    .find((l) => l.startsWith("host:"))
    .slice(6)
    .trim()
const ext = triple.includes("windows") ? ".exe" : ""

execFileSync("cargo", ["build", "--release", "--locked", "--target", triple, "--manifest-path", join(gateway, "Cargo.toml")], { stdio: "inherit" })

const out = join(here, "..", "src-tauri", "binaries")
mkdirSync(out, { recursive: true })
copyFileSync(join(gateway, "target", triple, "release", `notchi-gateway${ext}`), join(out, `notchi-gateway-${triple}${ext}`))
console.log(`notchi-gateway -> src-tauri/binaries/notchi-gateway-${triple}${ext}`)
