# Developer Documentation

The following sections provide rough guidelines on how to work with IESopt, and mostly IESopt.jl, improving the documentation, testing, and implementing new features.

!!! info "Helping out"
    Looking for things to contribute, with a low entry barrier (besides any open issue)? Check for `To be added` (especially in the documentation), or `TODO` (especially in the code).

## Getting started

### General

1. Install [Julia](https://julialang.org/downloads/).
2. Install [VSCode](https://code.visualstudio.com/), and some [extensions](#working-with-vscode) _(this step is optional, but highly recommended)_.
3. Clone/fork the repository.
4. Happy coding (... see below)!

> If you are new to Julia, or not entirely sure how everything works - let's talk. We are happy to help you get started, and to guide you through the process. Stuff like [Revise.jl](https://timholy.github.io/Revise.jl/) can be a huge help, and we can show you how to use it. Further, if you are coming from, e.g., a standard Python background, the advantages of a dynamic REPL-driven development may be new to you.

### Tips and tricks

- Check out [Modern Julia Workflows](https://modernjuliaworkflows.github.io/).
- Check out the [Julia Discourse](https://discourse.julialang.org/).
- Read up details on [Revise usage](https://timholy.github.io/Revise.jl/stable/cookbook/).

## Architecture

See [ARCHITECTURE.md](https://github.com/ait-energy/IESopt.jl/main/blob/main/ARCHITECTURE.md) for more information.

## Coding conventions

### Branches

We mainly use a ["feature branch workflow"](https://www.atlassian.com/git/tutorials/comparing-workflows/feature-branch-workflow), similar to ["trunk based development"](https://trunkbaseddevelopment.com/). We strive to keep the `main` branch as clean as possible (docs and tests should build and pass), and work on a separate `development` (trunk) branch. For larger changes, consider starting new feature branches. Where possible we use PRs (or merge requests) to get changes into the `main` branch, while doing a (light) code review for each other.

### Naming conventions

#### Julia

We make use of the following naming conventions, which slightly differ from the [Julia naming conventions](https://docs.julialang.org/en/v1/manual/style-guide/1), but are similar to other large projects out there:

- Types and similar items use `CamelCase`, e.g., `MyType`.
- Functions and variables use `snake_case`, e.g., `my_function(...)`.
- Functions that modify their arguments should end with an exclamation mark, e.g., `optimize!(...)`.
- Functions and variables should actually make use of underscores, whenever reasonable (and not only when absolutely necessary), e.g., `set_to_zero!(...)` (not `settozero!(...)` like the [Julia naming conventions](https://docs.julialang.org/en/v1/manual/style-guide/1) may suggest).
- Constants are written in `UPPERCASE`, e.g., `MY_CONSTANT`.

#### Python

To be added (`black` with `--line-length 88`, `ruff`, standard naming conventions, ...).

### Conventional commits

Refer to the [Conventional Commits](https://www.conventionalcommits.org/) specification for a detailed explanation. In short, we use the following format:

- `feat: implemented new feature X`
- `fix: fixed the bug X`
- `refactor: refactored the code X`
- `docs: updated the documentation X`
- `test: added a new test for X`
- `chore: updated the dependencies X`

> As indicated we use `docs`, but `test` (and not `tests`), which can be remembered by looking at the folder names: `docs/` and `test/`.

### Version numbers

Documenter.jl (as of May, 22nd, 2024) aggressively states: _"Documenter, like any good Julia package, follows semantic versioning (SemVer)."_

Unfortunately, [semantic versioning](https://semver.org/) may not be as well suited as one might think for a package like IESopt.jl. Some reasons are:

- While the (Julia) API has been stable for a long time (in a sense of: backwards-compatible), we consider the YAML configuration syntax as main part of IESopt's "API". This syntax has changed multiple times, and will likely change in the future. Maintaining full backwards compatibility for this is not feasible all the time. This induces a need for a major version bump, even though the Julia API has not changed.
- A mere bug fix, even a small one, in IESopt.jl may very likely induce changed results of any model run. A user could see vastly different results between `v1.3.10` and `v1.3.11`, even though the changes are minimal. This involves not taking patch updates lightly, which is not the case in many other packages.

However, as indicated, the use of semantic versioning is still "expected" by large parts of the Julia community, and not doing so may make it harder for some users, and/or some interactions with other packages. So...

1. **IESopt.jl makes use of semantic versioning!**
2. You are advised to consider the above points when deciding on version bumps.
3. Advise users and make sure you properly document changes.
4. Expect rising major version numbers.

## Working with VSCode

The following set of extensions may be helpful, either for development or documentation purposes:

- [Julia](https://marketplace.visualstudio.com/items?itemName=julialang.language-julia)
- [Live Preview](https://marketplace.visualstudio.com/items?itemName=ms-vscode.live-server)
- [Markdown Julia](https://marketplace.visualstudio.com/items?itemName=colinfang.markdown-julia)
- [Markdown Preview GitHub Styling](https://marketplace.visualstudio.com/items?itemName=bierner.markdown-preview-github-styles)
- [markdownlint](https://marketplace.visualstudio.com/items?itemName=DavidAnson.vscode-markdownlint)
- [Rainbow CSV](https://marketplace.visualstudio.com/items?itemName=mechatroner.rainbow-csv)

## Improving the documentation

```@meta
# TODO: refactor to new syntax: `julia --project=. -e 'include("docs/liveserver.jl")'`
```

Docstrings of public entries of IESopt.jl are taken from the code, see `src/...`. Besides that, the documentation is contained in the `docs/src/...` folder, and built based on `docs/make.jl`, using [Documenter.jl](https://documenter.juliadocs.org/).

!!! info "Diátaxis"
    Consider checking out the excellent "project" [_Diátaxis_, by Daniele Procida](https://diataxis.fr/). We try to adhere to the principles outlined there, and you may find them useful as well. For a quick intro, you may consider starting here: [The difference between a tutorial and how-to guide](https://diataxis.fr/tutorials-how-to/).

### Setup

Make sure that you

1. have a working installation of Julia (otherwise go to [julialang.org](https://julialang.org/downloads/) and install it; we recommend sticking to `Juliaup` if asked), and
2. have a terminal of your choice launched at `IESopt.jl/`.

Then, run the following command once to set up the environment used for the documentation:

```console
julia --project=docs -e 'import Pkg; Pkg.instantiate()'
```

### Building the documentation

Launch an interactive web server that shows you the documentation while you are working on it:

```console
julia --project=docs -e 'using LiveServer; servedocs(; launch_browser=true)'
```

> **Note**: While the above is your best choice in 95% of all cases, you can also manually build the documentation using
>
> ```console
> julia --project=docs docs/make.jl
> ```
>
> which may be useful if you modify source files (which LiveServer.jl currently does not track in a convenient way). Note however that this will not automatically reload the documentation in your browser (but may in VSCode if you right-click the `index.html` file and select `Preview`, using the `Live Preview` extension), and may fail to properly account for image/... paths.

## Code formatting

We provide a custom `.JuliaFormatter.toml` file that should be used to format the code. The easiest way to use it is to:

1. Add `JuliaFormatter` to your Julia base environment by running `] add JuliaFormatter` in the package mode of your Julia REPL (without an active IESopt environment).
2. Run `using JuliaFormatter` in the Julia REPL (this now works even if you activated the IESopt environment).
3. Run `format(".")` in the Julia REPL to format all files in your current directory. This takes a bit of compile time, but after the first run, it should be fairly fast.

Make sure you checked the formatting, before finalizing your changes or opening a PR. If you forgot to include formatting in your actual commits (we all do...), and cannot reasonably amend them, add **all** formatting changes at the end in a single commit with the message:

```console
git commit -m "chore: formatting"
```

## Testing

### Running tests locally

Launch a new Julia REPL (hit `Alt+J` and then `Alt+O` in VSCode), enter Package mode (by pressing `]` in your REPL, now showing `(IESopt) pkg>`), and then execute all tests by running:

```console
(IESopt) pkg> test
```
