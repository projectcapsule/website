# Capsule Website

Source for [projectcapsule.dev](https://projectcapsule.dev), the documentation site for
[Capsule](https://github.com/projectcapsule/capsule) and
[capsule-proxy](https://github.com/projectcapsule/capsule-proxy).

Built with [Hugo](https://gohugo.io) and the [Docsy](https://www.docsy.dev) theme, pulled in as
a Hugo module. CNCF Netlify deploys `main` and previews every pull request.

## Running locally

`npm install` brings in the pinned extended Hugo, so `npx` runs the version the site is
deployed with. A `go` toolchain is also needed, to fetch the Docsy module.

```bash
npm install
npx hugo server   # http://localhost:1313
```

## Generated API reference

`content/en/docs/reference.md` and `content/en/docs/proxy/reference.md` come from the Capsule
and capsule-proxy CRDs. Edit those upstream, not these files, then regenerate:

```bash
make apidocs              # both repositories at main, so unreleased CRDs
make apidocs REF=v0.10.6  # one ref, used for both repositories
```

## Contributing

Pages live under `content/en/`. See [CONTRIBUTING.md](CONTRIBUTING.md) for the pull request
workflow and [DEVELOPMENT.md](DEVELOPMENT.md) for the pre-commit hooks and link checker.

## License

[Apache 2.0](LICENSE).
