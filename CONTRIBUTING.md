# How to Contribute

Contributions to the Capsule documentation are welcome. This repository holds only the website;
changes to Capsule itself belong in
[projectcapsule/capsule](https://github.com/projectcapsule/capsule).

## Opening a pull request

1. Fork the repository and branch off `main`.
2. Edit or add Markdown under `content/en/`.
3. Optionally preview locally with `devbox shell` and `task serve`, see
   [DEVELOPMENT.md](DEVELOPMENT.md).
4. Open the pull request. Netlify posts a deploy preview link on it, so the rendered page can be
   reviewed before merging.

Every change needs a maintainer review, including a maintainer's own. Once merged, Netlify
deploys the site to [projectcapsule.dev](https://projectcapsule.dev).

These checks block a merge:

- **Sign off each commit.** `git commit -s` adds the `Signed-off-by` trailer the DCO check
  requires, certifying the
  [Developer Certificate of Origin](https://developercertificate.org/).
- **Use a conventional commit subject** such as `docs:`, `fix:`, `chore:` or `feat:`.
  [commitlint](https://commitlint.js.org) enforces it on commits, and the pull request title
  follows the same format.
- **Links and spelling.** The link checker and the spell check run in CI. Run `task lychee` and
  `task docs-lint` locally, and add new technical terms to `content/dictionary.txt`.

## Writing

Follow the structure and front matter of neighbouring pages, and keep YAML examples valid,
readers copy them straight out.

`content/en/docs/reference.md` and `content/en/docs/proxy/reference.md` are generated from CRDs
by `task apidocs`; hand edits are overwritten on the next run. The `diff` workflow fails when
the committed files differ from the generated output.

## Code of Conduct

Capsule is a CNCF Sandbox project and follows the
[Capsule Code of Conduct](https://github.com/projectcapsule/capsule/blob/main/CODE_OF_CONDUCT.md).
