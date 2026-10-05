# GitHub Pages

The web app is a static site. GitHub Pages serves the calculator; builds and character data stay in
each visitor's browser. The addon ZIPs can be distributed separately through GitHub Releases.

## First deployment

1. Create a GitHub repository and push this project's source to its default branch.
2. Open the repository's **Settings → Pages** and select **GitHub Actions** as the source.
3. Open **Actions → Deploy web app → Run workflow**, select the default branch, and run it.
4. Use the site URL shown by the successful deployment. Add that URL to the root README.

The included workflow verifies the shared engine, builds the PWA and publishes only `web/dist/`. It
runs on manual request. Creating or editing local files does not publish a site. See
[GitHub's Pages workflow guide](https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages).

## Updates

Push a tested update, then run **Deploy web app** again. Existing visitors receive an **Update now**
prompt when the new offline cache is ready. Their saved library stays in browser storage. Use the
same URL for future releases: saves belong to the browser and site origin.

The workflow also builds and checks the addon archive. Upload `ForeverTalents.zip` from a local
build to a matching GitHub Release when distributing an addon update.

## Local preview

```sh
pnpm build
pnpm preview
```

Open `http://localhost:4173`. For another static host, deploy the contents of `web/dist/` to an
HTTPS site. Relative asset paths support hosting under a repository subdirectory.
