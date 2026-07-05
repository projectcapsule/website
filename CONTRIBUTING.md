# Contributing to the Capsule Documentation

Thank you for contributing to the Capsule documentation!

## How to Contribute

1. Fork this repository and create a branch for your changes.
2. Edit or add Markdown files under `content/en/`.
3. Open a pull request, Netlify will automatically post a **deploy preview** link so you can review the rendered site before it is merged.
4. Once approved and merged, the site is deployed automatically to [projectcapsule.dev](https://projectcapsule.dev) via CNCF Netlify.

No local Hugo setup is needed. All rendering and deployment is handled by Netlify.

## Content Guidelines

- All documentation is authored in Markdown.
- Follow the existing directory and heading structure under `content/en/docs/`.
- YAML examples in code blocks should be valid and tested where possible.
- Keep language clear and concise.

## API Reference

The files `content/en/docs/reference.md` and `content/en/docs/proxy/reference.md` are **generated** from CRD YAML files, do not edit them by hand. To regenerate:

```bash
make apidocs
```

The `diff` CI workflow will fail on your PR if the committed reference docs have drifted from the generated output.

## Code Reviews

All submissions require a pull request and at least one review from a maintainer.

## Community

This project follows the [CNCF Code of Conduct](https://github.com/cncf/foundation/blob/main/code-of-conduct.md).
