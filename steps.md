# Hosting the Acquirium docs on watermetadata.org/acquirium

Status (2026-08-27): implemented locally, not yet committed.

## How it works

- `acquirium/` is a git submodule of https://github.com/DataDrivenCPS/acquirium (see `.gitmodules`).
  `build.sh` runs `git submodule update --remote --merge`, so the site always builds from acquirium's
  default-branch tip, same as the other submodules.
- Acquirium's `docs/` is plain Markdown in a Diátaxis layout (`tutorials/`, `how-to/`, `reference/`,
  `explanation/`, each with an `_index.md`; `docs/_index.md` is the landing page). It has no docs
  tooling of its own, so this repo supplies the Jupyter Book config in `acquirium-docs/`:
  - `_config.yml` — book settings. Note: the installed Jupyter Book is 1.x (Sphinx-based), which is
    why this is `_config.yml`/`_toc.yml` and not a MyST `myst.yml`. Two settings matter:
    `myst_title_to_header: true` (the docs put their title in frontmatter, not an H1) and
    `myst_heading_anchors: 4` (GitHub-style `#section` links).
  - `_toc.yml` — sidebar table of contents. Update it when acquirium adds/removes doc pages.
- `build.sh` stages `acquirium/docs/*` + the config into `_staging/acquirium`, builds it with the
  water-ontology uv environment (where `jupyter-book` already lives), and moves the HTML to
  `build/acquirium`, which GitHub Pages serves at https://watermetadata.org/acquirium.
- `index.template` links to `/acquirium` under "Links" (`index.html` is generated from it).

## Testing only the acquirium part

```bash
uv sync --project water-ontology
rm -rf _staging/acquirium && mkdir -p _staging/acquirium
cp -r acquirium/docs/* _staging/acquirium/
cp acquirium-docs/_config.yml acquirium-docs/_toc.yml _staging/acquirium/
uv run --project water-ontology jupyter-book build _staging/acquirium
python3 -m http.server -d _staging/acquirium/_build/html 8000   # http://localhost:8000/
```

Expected: "build succeeded" with a handful of content-side warnings (unknown `csv` lexer, JSON
samples containing `...`, a link into `reference/apps.md`, which acquirium marks as pending rework).
A warning like "toctree contains reference to nonexisting document" means `_toc.yml` is out of sync
with `acquirium/docs`.

## Deploy

```bash
git add .gitmodules acquirium acquirium-docs build.sh index.template steps.md
git commit -m "host acquirium docs at /acquirium"
git push
```

`.github/workflows/deploy.yml` already checks out submodules recursively and publishes `build/`,
so no workflow change is needed. Docs refresh on every deploy of this repo; to refresh on a schedule
without touching this repo, add a `schedule:` cron trigger to `deploy.yml`.
