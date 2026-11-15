# Publishing the browser game

Live site: **https://the-karol.github.io/mission-arestemis/**

GitHub Pages is configured with **GitHub Actions** as its publishing source. The workflow `.github/workflows/pages.yml` downloads a tested web build from a GitHub Release, verifies its SHA-256 checksum and deploys it as a Pages artifact.

The PCK exceeds GitHub's normal file-size limit, so generated web files are release assets rather than Git commits. The workflow publishes the selected build; it does not compile source changes automatically.

## Publish an update

1. Export and test the game locally using the [development guide](DEVELOPMENT.md).
2. Run `python tools/package_pages.py`. This creates `build/pages-web.zip` and prints its SHA-256 checksum. The archive has `index.html` at its root.
3. Create a new GitHub Release with a unique tag and attach `pages-web.zip` to it. Publish the release; prereleases also work.
4. Update `RELEASE_TAG` and `WEB_SHA256` in `.github/workflows/pages.yml` to match that release and checksum.
5. Commit and push the workflow change to `main`. The deployment starts automatically.
6. Check **Actions > Deploy web game to GitHub Pages** for a successful run, then open the live site.

To redeploy the same build, open that workflow in Actions and select **Run workflow**. To roll back, restore the tag and checksum of a previous working release and push the workflow change.

## Hosting details

- The game uses single-threaded Godot WebGL 2; cross-origin isolation headers are not required.
- Relative runtime paths allow the game to run under `/mission-arestemis/`.
- Keep the generated `index.*` filenames unchanged and deploy HTML, PCK, WASM and JavaScript together.
- Saving and Workshop storage remain browser-local. Moving from localhost to Pages creates a separate save location; use exported blueprints to transfer Workshop designs.
- The local Windows testing ZIP contains a server and is not the Pages deployment archive.
