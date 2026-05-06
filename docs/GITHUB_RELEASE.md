# Push and GitHub Release

## What to commit

Commit source, scripts, docs, and icon sources.

Do not commit local build outputs:

- `dist/`
- `release/`
- `.build/`
- `*.app`
- `*.dmg`

These are ignored by `.gitignore`. The GitHub Actions workflow rebuilds the DMG and uploads it to GitHub Releases.

## First push to a new GitHub repo

Authenticate once:

```bash
gh auth login
```

Create the repo and push:

```bash
git init
git add .
git commit -m "Release AudioX v1.0.0"
gh repo create audiox --public --source . --remote origin --push
```

If you want a private repo:

```bash
gh repo create audiox --private --source . --remote origin --push
```

## Push to an existing GitHub repo

```bash
git remote add origin git@github.com:YOUR_NAME/audiox.git
git branch -M main
git add .
git commit -m "Release AudioX v1.0.0"
git push -u origin main
```

If `origin` already exists:

```bash
git remote set-url origin git@github.com:YOUR_NAME/audiox.git
git push -u origin main
```

## Create a GitHub Release with DMG

Push a version tag:

```bash
git tag v1.0.0
git push origin v1.0.0
```

The workflow at `.github/workflows/release.yml` will:

- Build `dist/AudioX-1.0.0-universal.dmg` on a macOS runner.
- Create `SHA256SUMS`.
- Upload both files as workflow artifacts.
- Attach both files to the GitHub Release for `v1.0.0`.

## Manual release build in GitHub Actions

You can also run the workflow manually:

1. Open the GitHub repository.
2. Go to `Actions`.
3. Select `Release DMG`.
4. Click `Run workflow`.

Manual runs upload workflow artifacts but only tag pushes publish GitHub Releases.

## Local DMG build

```bash
scripts/package_dmg.sh universal
```

Local output:

```text
dist/AudioX-1.0.0-universal.dmg
```

## Recommended release flow

```bash
git status
git add .
git commit -m "Release AudioX v1.0.0"
git push
git tag v1.0.0
git push origin v1.0.0
```

After the GitHub Actions run finishes, users can download the DMG from:

```text
https://github.com/YOUR_NAME/audiox/releases/latest
```

