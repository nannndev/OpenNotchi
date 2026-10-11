# OpenNotchi website

Landing page for OpenNotchi: React + Vite + TypeScript, Tailwind CSS v4,
shadcn/ui and Motion. The latest version, download links, star count and
contributors are read live from the GitHub API.

```bash
npm install
npm run dev      # http://localhost:5173
npm run build    # outputs dist/
```

Deployed on Vercel with **Root Directory** set to `website`. Vercel detects
Vite automatically; `vercel.json` adds `/download` and `/github` redirects.
