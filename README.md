# Capsule Documentation

This repository contains the documentation for [Capsule](https://github.com/projectcapsule/capsule), the Kubernetes multi-tenancy operator.

The site is published at **[projectcapsule.dev](https://projectcapsule.dev)** and is automatically deployed via [CNCF Netlify](https://www.netlify.com/) on every merge to `main`.

## Contributing

All documentation lives under `content/en/`. Contributions are welcome — open a pull request with your changes.

Netlify automatically generates a **deploy preview** for every pull request, so you can review your changes at a live URL before merging. No local Hugo setup is required.

See [CONTRIBUTING.md](CONTRIBUTING.md) for contribution guidelines and [DEVELOPMENT.md](DEVELOPMENT.md) for local tooling setup (pre-commit hooks, link checking, API doc generation).

## API Reference

The files `content/en/docs/reference.md` and `content/en/docs/proxy/reference.md` are **generated** from CRD YAML files. Do not edit them by hand. To regenerate:

```bash
make apidocs
```

These files are checked in CI — the `diff` workflow fails if the generated output has drifted from what is committed.

## License

[Apache 2.0](LICENSE)
