// Builds the eay-gateway sidecar and places it where Tauri's `bundle.externalBin` expects it:
// src-tauri/binaries/eay-gateway-<target-triple>[.exe].
// Source: $EAY_GATEWAY_DIR, else a sibling eay-gateway checkout (../../../eay-gateway).
import { execFileSync } from "node:child_process"
import { copyFileSync, existsSync, mkdirSync } from "node:fs"
import { dirname, join, resolve } from "node:path"
import { fileURLToPath } from "node:url"

const here = dirname(fileURLToPath(import.meta.url))
const gateway = resolve(process.env.EAY_GATEWAY_DIR || join(here, "..", "..", "..", "..", "eay-gateway"))
if (!existsSync(join(gateway, "Cargo.toml"))) {
  console.error(`eay-gateway not found at ${gateway}. Clone github.com/nannndev/eay-gateway next to OpenNotchi or set EAY_GATEWAY_DIR.`)
  process.exit(1)
}
const triple =
  process.env.TAURI_ENV_TARGET_TRIPLE ||
  execFileSync("rustc", ["-vV"], { encoding: "utf8" })
    .split("\n")
    .find((l) => l.startsWith("host:"))
    .slice(6)
    .trim()
const ext = triple.includes("windows") ? ".exe" : ""

execFileSync("cargo", ["build", "--release", "--locked", "--bin", "eay-gateway", "--target", triple, "--manifest-path", join(gateway, "Cargo.toml")], { stdio: "inherit" })

const out = join(here, "..", "src-tauri", "binaries")
mkdirSync(out, { recursive: true })
copyFileSync(join(gateway, "target", triple, "release", `eay-gateway${ext}`), join(out, `eay-gateway-${triple}${ext}`))
console.log(`eay-gateway -> src-tauri/binaries/eay-gateway-${triple}${ext}`)
