# pixelcade.org app pages

The HTML for the app download pages on pixelcade.org, and the screenshots they show.

| File | Page |
|---|---|
| `pixelcade-apps-page.html` | https://pixelcade.org/apps/ (Pixelcade Companion: iOS, Android, Mac, Windows) |
| `pixelcade-sidekick-apps-page.html` | https://pixelcade.org/sidekick-apps/ (Pixelcade Sidekick: iOS, Android) |

## Updating a page

Edit the HTML here, then paste the whole file into the page's **Custom HTML** block in WordPress.
The styles are scoped to the page (`.pxapps` / `.pxsk`), so they don't affect the rest of the site.

## Images and downloads

- Screenshots: `companion/` and `sidekick/`, served by GitHub Pages at
  `https://alinke.github.io/pixelcade-linux-builds/apps/...` (JPEG, 600 px wide for phones).
  Keep them free of game art, console logos and other third-party trademarks.
- Windows downloads: the `windows-companion` release of this repo
  (`Pixelcade-Companion-Windows-x64.exe`, `Pixelcade-Companion-Windows-ARM64.zip`).
  Replace a file there with `gh release upload windows-companion <file> --clobber`;
  the download links stay the same.
- Store badges and QR codes are the ones already in the pixelcade.org media library.
