Favicon light & dark mode

1. favicon-adaptive.svg — otomatis navy di mode terang, putih di mode gelap.
2. Fallback PNG: favicon-32.png (ikon aplikasi, aman di kedua mode).

Pasang di <head> website:
<link rel="icon" href="/favicon-adaptive.svg" type="image/svg+xml">
<link rel="icon" href="/favicon-32.png" sizes="32x32" type="image/png">
<link rel="apple-touch-icon" href="/app-icon.png">

Alternatif dua file terpisah:
<link rel="icon" href="/icon-navy.svg" media="(prefers-color-scheme: light)">
<link rel="icon" href="/icon-white.svg" media="(prefers-color-scheme: dark)">
