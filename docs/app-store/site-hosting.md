# Hosting Privacy and Support Pages

App Store Connect requires a public Privacy Policy URL for iOS apps and expects a Support URL in app metadata. This project includes a static site in `site/`.

## GitHub Pages Path

1. Push this repository to GitHub.
2. Open the repository settings.
3. Go to Pages.
4. Set the source to GitHub Actions.
5. Run or wait for the `Publish App Store Site` workflow.

After deployment, open the workflow run summary. It prints the exact App Store URLs:

```text
https://<github-user-or-org>.github.io/<repository-name>/privacy.html
https://<github-user-or-org>.github.io/<repository-name>/support.html
```

Replace `<github-user-or-org>` and `<repository-name>` with the actual GitHub owner and repository.

Publishing helper: `docs/github-publishing.md`.

The GitHub publishing helper also enables GitHub Issues and writes a public support request link into `site/support.html` and `site/privacy.html` after the final repository owner and name are known.

## Other Static Hosts

The same `site/` folder can be uploaded to any static host, including Vercel, Netlify, Cloudflare Pages, or an object storage bucket with public website hosting.

## App Store Connect Fields

- Privacy Policy URL: public URL for `privacy.html`
- Support URL: public URL for `support.html`
