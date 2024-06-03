# Releasing

This documents the steps necessary to release a new version of the IESopt.jl package. Follow these step-by-step, and fix
any issues that might arise, before proceeding to the next step:

1. [Check tests locally](#check-tests-locally)
2. [Check formatting](#check-formatting)
3. [Update the changelog](#update-the-changelog)
4. [Update the version number](#update-the-version-number)
5. [Trigger a new release](#trigger-a-new-release)

## Check tests locally

After entering "package mode" (press `]`), make sure that the `IESopt` environment is activated, which shows as
`(IESopt) pkg>` (if not execute `activate .`), and then run the tests by executing the `test` command:

```shell
(IESopt) pkg> test
```

## Check formatting

The following assumes that you have installed the `JuliaFormatter.jl` package.

<details>
<summary>Expand: How to install <b><i>JuliaFormatter</i></b></summary>

> It is advised to add that package to your "base" environment (it comes at little overhead, and is then available in
> all environments). To install the package, run the following command in the Julia REPL, after switching to "package
> mode" (press `]`):
>
> ```shell
> (......) pkg> activate
> (@v1.10) pkg> add JuliaFormatter
> ```
>
> The first "empty" activate command is necessary to switch to the "base" environment (it acts like `conda deactivate`).
> The second command then installs the `JuliaFormatter.jl` package (note that `(@v1.10)` is just an example, it could be
> different for you).

</details>

To check/fix the formatting of the package, run the following command in the Julia REPL:

```julia
using JuliaFormatter
format("src")
```

This automatically formats all files in the `src` directory. This returns `true` if all files were already formatted
correctly.

## Update the changelog

Check out [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) for guidance on how to write a changelog. You can use
the template below, replace all placeholders, and remove the parts that are not applicable. Add the new entry as topmost
entry of the [CHANGELOG.md](CHANGELOG.md) file.

<details>
<summary>Expand: Changelog template</summary>

```markdown
## [X.Y.Z] - YYYY-MM-DD

{{Give a (really) short description of the release here, ideally one sentence.}}

### Added

- {{document new features here}}

### Changed

- {{document changed features here}}

### Deprecated

- {{document deprecated features here}}

### Removed

- {{document removed features here}}

### Fixed

- {{document fixed bugs here}}
```

</details>

## Update the version number

Update the version number in the [Project.toml](Project.toml) file. The version number should be in the format `X.Y.Z`.
Check the [Semantic Versioning](https://semver.org/spec/v2.0.0.html) specification for guidance on how to update the
version number. Make sure to name your commit as:

```text
chore: prep for vX.Y.Z
```

## Trigger a new release

Open the latest commit that was merged into the `main` branch (this should be a `chore: prep for vX.Y.Z` commit) and add
a comment with the following text:

```text
@JuliaRegistrator register

Release notes:

{{>> directly add you new changelog entry here <<}}
```
