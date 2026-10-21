# How to Contribute

Contributions to the Capsule documentation are welcome. This repository holds only the website;
changes to Capsule itself belong in
[projectcapsule/capsule](https://github.com/projectcapsule/capsule).

## Opening a pull request

Fork, branch off `main`, edit the Markdown under `content/en/`, and open the pull request.
Netlify posts a deploy preview link on it, so the rendered page can be reviewed before merging.
Every change needs a maintainer review, including a maintainer's own.

Two checks block a merge:

- **Sign off each commit.** `git commit -s` adds the `Signed-off-by` trailer the DCO check
  requires, certifying the
  [Developer Certificate of Origin](https://developercertificate.org/).
- **Use a conventional commit subject** — `docs:`, `fix:`, `chore:`, `feat:`.
  [commitlint](https://commitlint.js.org) enforces it.

## Writing

Follow the structure and front matter of neighbouring pages, and keep YAML examples valid —
readers copy them straight out.

`content/en/docs/reference.md` and `content/en/docs/proxy/reference.md` are generated from CRDs
by `make apidocs`; hand edits are overwritten on the next run.

## Code of Conduct

Capsule is a CNCF Sandbox project and follows the
[Capsule Code of Conduct](https://github.com/projectcapsule/capsule/blob/main/CODE_OF_CONDUCT.md).
