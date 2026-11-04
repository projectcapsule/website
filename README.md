# Capsule Website

Source for [projectcapsule.dev](https://projectcapsule.dev), the documentation site for
[Capsule](https://github.com/projectcapsule/capsule) and
[capsule-proxy](https://github.com/projectcapsule/capsule-proxy).

Built with [Hugo](https://gohugo.io) and the [Docsy](https://www.docsy.dev) theme, pulled in as
a Hugo module. CNCF Netlify deploys `main` and previews every pull request.

## Running locally

The tooling (Hugo, Go, Node.js, Task, prek, lychee) is provided by
[Devbox](https://www.jetify.com/docs/devbox/installing_devbox), so there is nothing else to
install.

```bash
devbox shell
task setup    # once: installs Node.js dependencies and the Git hooks
task serve    # http://localhost:1313
```

Outside the shell, prefix a task with `devbox run`, for example `devbox run task serve`.
`task build` builds the production site into `public/`. Run `task --list` for all tasks.

## Generated API reference

`content/en/docs/reference.md` and `content/en/docs/proxy/reference.md` come from the Capsule
and capsule-proxy CRDs. Edit those upstream, not these files, then regenerate:

```bash
task apidocs                       # both repositories at main, so unreleased CRDs
task apidocs:capsule REF=v0.12.0   # one repository at a specific ref
```

## Contributing

Pages live under `content/en/`. A local setup is optional, as Netlify posts a deploy preview on
every pull request. See [CONTRIBUTING.md](CONTRIBUTING.md) for the pull request workflow and
[DEVELOPMENT.md](DEVELOPMENT.md) for the tasks, Git hooks and link checker.

## License

[Apache 2.0](LICENSE).
