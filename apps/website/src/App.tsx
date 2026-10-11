import { NotchDemo } from "@/components/notch-demo"
import { Contributors } from "@/components/sections/contributors"
import { Download } from "@/components/sections/download"
import { Features } from "@/components/sections/features"
import { Hero } from "@/components/sections/hero"
import { SiteFooter } from "@/components/sections/site-footer"
import { SiteNav } from "@/components/sections/site-nav"
import { TooltipProvider } from "@/components/ui/tooltip"

export default function App() {
  return (
    <TooltipProvider>
      <NotchDemo />
      <SiteNav />
      <main id="top">
        <Hero />
        <Features />
        <Download />
        <Contributors />
      </main>
      <SiteFooter />
    </TooltipProvider>
  )
}
