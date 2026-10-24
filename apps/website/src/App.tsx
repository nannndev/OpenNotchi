import { useEffect } from "react"
import { Analytics } from "@vercel/analytics/react"
import { Contributors } from "@/components/sections/contributors"
import { Download } from "@/components/sections/download"
import { Features } from "@/components/sections/features"
import { Hero } from "@/components/sections/hero"
import { InstallGuide } from "@/components/sections/install-guide"
import { Photobox } from "@/components/sections/photobox"
import { SiteFooter } from "@/components/sections/site-footer"
import { SiteNav } from "@/components/sections/site-nav"
import { Support } from "@/components/sections/support"
import { TooltipProvider } from "@/components/ui/tooltip"

export default function App() {
  // The page renders client-side, so jump to a #section link once it exists.
  useEffect(() => {
    if (window.location.hash) {
      document.querySelector(window.location.hash)?.scrollIntoView()
    }
  }, [])

  return (
    <TooltipProvider>
      <SiteNav />
      <main id="top">
        <Hero />
        <Features />
        <Photobox />
        <Download />
        <InstallGuide />
        <Contributors />
        <Support />
      </main>
      <SiteFooter />
      <Analytics />
    </TooltipProvider>
  )
}
