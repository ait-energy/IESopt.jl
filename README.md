# Integrated Energy System Optimization (IESopt.jl)

[![License](https://img.shields.io/github/license/ait-energy/IESopt.jl)](LICENSE)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://ait-energy.github.io/IESopt.jl/dev/)
<!--
[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://ait-energy.github.io/IESopt.jl/stable/)
-->

[![Build Status](https://github.com/ait-energy/IESopt.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/ait-energy/IESopt.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/ait-energy/IESopt.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/ait-energy/IESopt.jl)
[![Aqua](https://raw.githubusercontent.com/JuliaTesting/Aqua.jl/master/badge.svg)](https://github.com/JuliaTesting/Aqua.jl)

**IESopt** (_Integrated Energy System Optimization_) is a modeling and optimization framework for integrated energy
systems.

> Note: We are currently moving from our internal version control to GitHub. Missing contents will be added during the
> upcoming days ...

## Table of Contents

- [Background](#background)
- [Install](#install)
- [Usage](#usage)
- [API](#api)
- [Contributing](#contributing)
- [License](#license)

## Background

IESopt has been in development at AIT since 2021, and was moved to GitHub in June, 2024, based on a cleaned version with
slightly more than 1000 commits. Check out the [references](https://ait-energy.github.io/IESopt.jl/dev/pages/references/publications/)
for a more detailed overview about publications and projects, where IESopt has been used.

## Install

Make sure to check out the detailed [installation guides](https://ait-energy.github.io/IESopt.jl/stable/pages/tutorials/setup/)
in the documentation, both for Python and Julia.

### Quick setup for Julia

In an open REPL, type `]` to enter the package mode, make sure that your environment is
activated (e.g., do `activate .`), then add the package with the following command:

```bash
(your-env) pkg> add IESopt
```

### Quick setup for Python

Head over to [iesopt-py](https://github.com/ait-energy/iesopt-py) and follow the instructions there, or - if you already
have a working Python environment - install the package, e.g., via `poetry`:

```bash
poetry add iesopt-py
```

## Usage

IESopt requires a configured model to run. You can start with the extensive [first model tutorial](https://ait-energy.github.io/IESopt.jl/previews/PR3/pages/tutorials/first_model/), or checkout [IESoptLib](https://github.com/ait-energy/IESoptLib.jl) which
includes many more examples.

### Basic usage

The basic workflow to get results from a model, defined by a top-level configuration file `config.iesopt.yaml`, is as
follows:

1. Parse, generate, and build the model from `config.iesopt.yaml`.
2. Optimize the model (the chose solver is specified in `config.iesopt.yaml`).
3. Get the results from the model.

Steps 1. and 2. can be combined in a single call, which the convenience function `run(...)` provides.

#### Julia

```julia
using IESopt

model = IESopt.run("config.iesopt.yaml")
results = model.ext[:iesopt].results
```

#### Python

```python
import iesopt

model = iesopt.run("config.iesopt.yaml")
df_results = model.results.to_pandas()
```

## API

TODO: Document the API of the package.

### Julia

### Python

## Contributing

[![Code Style](https://img.shields.io/badge/code_style-custom-blue?style=flat&logo=julia&logoColor=white)](.JuliaFormatter.toml)
[![Readme Style](https://img.shields.io/badge/readme_style-standard-lime?style=flat&logo=julia&logoColor=white)](https://github.com/RichardLitt/standard-readme)

PRs accepted.

## License

[MIT © AIT Austrian Institute of Technology GmbH.](LICENSE)
