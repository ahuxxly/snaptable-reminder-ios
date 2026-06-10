# GitHub Publishing

Use this after the local repository is ready and the GitHub CLI is installed and authenticated.

## Install and Login

On Windows:

```powershell
winget install --id GitHub.cli -e --source winget
```

Recommended one-command path after GitHub CLI is installed:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/github-login-and-publish.ps1 -RepoName snaptable-reminder-ios -Visibility public
```

This starts GitHub browser login when needed, then calls `scripts/github-publish.ps1`.

Manual login alternative:

```powershell
gh auth login
```

Choose GitHub.com and browser login. The account must be able to create repositories or push to the target repository.

If the current PowerShell session does not recognize `gh` right after installation, open a new terminal. The publishing script also checks the standard install path `C:\Program Files\GitHub CLI\gh.exe`.

## Create and Push a Repository

From the repository root:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/github-publish.ps1 -RepoName snaptable-reminder-ios -Visibility public
```

What the script does:

- Confirms `gh` is installed and logged in.
- Requires a clean git working tree.
- Creates a GitHub repository when `origin` is missing.
- Pushes the current branch.
- Prints recent GitHub Actions runs.

## Existing Repository

If a repository already exists, set the remote first:

```powershell
git remote add origin https://github.com/<owner>/<repo>.git
powershell -ExecutionPolicy Bypass -File scripts/github-publish.ps1
```

Replace `<owner>` and `<repo>` with the actual GitHub owner and repository name.

## GitHub Pages

After the first push:

1. Open repository Settings > Pages.
2. Set Source to GitHub Actions.
3. Confirm the `Publish App Store Site` workflow completes.
4. Use these URLs in App Store Connect:

```text
https://<owner>.github.io/<repo>/privacy.html
https://<owner>.github.io/<repo>/support.html
```

To write those URLs into Fastlane metadata after Pages is live:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/write-fastlane-store-urls.ps1 -Owner <owner> -RepoName <repo>
```

## CI Gate

The `iOS CI` workflow must pass before App Store upload work is trusted. It generates the Xcode project, runs unit tests, and builds for an iPhone simulator on a hosted macOS runner.

The manual `App Store Screenshots` workflow generates raw screenshot exports and a Fastlane screenshot folder for App Store Connect after the app builds on GitHub's macOS runner.

The manual `Release Readiness` workflow runs Mac verification and screenshot capture together, then uploads the same screenshot artifacts.
