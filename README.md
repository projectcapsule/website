# Capsule Website

Source for [projectcapsule.dev](https://projectcapsule.dev), the documentation site for
[Capsule](https://github.com/projectcapsule/capsule) and
[capsule-proxy](https://github.com/projectcapsule/capsule-proxy).

Built with [Hugo](https://gohugo.io) and the [Docsy](https://www.docsy.dev) theme, pulled in as
a Hugo module. CNCF Netlify deploys `main` and previews every pull request.

## Running locally

<<<<<<< HEAD
For Docsy documentation, see [Docsy user guide][].

This Docsy Example Project is hosted on [Netlify][] at [example.docsy.dev][].
You can view deploy logs from the [deploy section of the project's Netlify
dashboard][deploys], or this [alternate dashboard][].

This is not an officially supported Google product. This project is currently maintained.

## Using the Docsy Example Project as a template

A simple way to get started is to use this project as a template, which gives you a site project that is set up and ready to use. To do this:

1. Use the dropdown for switching branches/tags to change to the **latest** released tag.

2. Click **Use this template**.

3. Select a name for your new project and click **Create repository from template**.

4. Make your own local working copy of your new repo using git clone, replacing https://github.com/me/example.git with your repo’s web URL:

```bash
git clone --depth 1 https://github.com/me/example.git
```

You can now edit your own versions of the site’s source files.

## Running the website locally

Install [Devbox](https://www.jetify.com/docs/devbox/installing_devbox) to get the
project's development tools, including Hugo Extended, Node.js, Go, Task, prek, and
Lychee. From the repository root, run:

```bash
devbox shell
task setup
task serve
```

Open <http://localhost:1313> to preview the site. Check documentation links locally
with:

```bash
task lychee
```

See [DEVELOPMENT.md](DEVELOPMENT.md) for the available tasks and Git hook setup.

## Running a container locally
=======
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
>>>>>>> 69f84ecda17339f5b199618ab341bc084082143e

Pages live under `content/en/`. See [CONTRIBUTING.md](CONTRIBUTING.md) for the pull request
workflow and [DEVELOPMENT.md](DEVELOPMENT.md) for the pre-commit hooks and link checker.

## License

[Apache 2.0](LICENSE).
