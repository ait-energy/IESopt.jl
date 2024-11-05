# IESopt: Integrated Energy System Optimization

[![License](https://img.shields.io/github/license/ait-energy/IESopt.jl)](LICENSE)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://ait-energy.github.io/IESopt.jl/dev/)
<!--
[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://ait-energy.github.io/IESopt.jl/stable/)
-->

[![Build Status](https://github.com/ait-energy/IESopt.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/ait-energy/IESopt.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/ait-energy/IESopt.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/ait-energy/IESopt.jl)
[![Aqua](https://raw.githubusercontent.com/JuliaTesting/Aqua.jl/master/badge.svg)](https://github.com/JuliaTesting/Aqua.jl)

> Note: We are currently moving from our internal version control to GitHub. Missing contents will be added during the
> upcoming days ...

**IESopt** (_Integrated Energy System Optimization_) is a modeling and optimization framework for integrated energy
systems.

It is developed and maintained at the **Center for Energy** at
[AIT Austrian Institute of Technology GmbH](https://www.ait.ac.at/). The framework is designed to support the
optimization of energy systems that are characterized by a high degree of integration between different energy carriers
and sectors. It focuses on offering a modular and adaptable tool for modelers, that does not compromise on performance,
while still being user-friendly. This is enabled by reducing energy system assets to abstract building blocks, that are
supported by specialized implementation, and can be combined into complex systems without the need of a detailed
understanding of mathematical modeling or proficiency in any coding-language.

## MERGING DOCUMENTATIONS

> We are currently merging this documentation into the (now) central one, over at working [iesopt](https://github.com/ait-energy/iesopt). Besides migrating everything, this requires some clean-up of
> (potentially) confindential left-overs (e.g., from projects), so the documentation needs to be checked page-by-page. If you are trying to
> get started before we manage to fix everything, get in touch with us directly - we'll help you set up everything you
> need. Leftovers can be seen in #4c2a59c or earlier. Information in the current Julia documentation as well as in this README may be outdated!

---
---

## Table of Contents

- [Background](#background)
- [Install](#install)
- [Usage](#usage)
- [API](#api)
- [Contributing](#contributing)
- [License](#license)

## Background

IESopt has been in development at AIT since 2021, and was moved to GitHub in June, 2024, based on a cleaned version with
slightly more than 1000 commits. IESopt has been applied in a variety of projects, ranging from small-scale energy
system optimization, to large-scale models spanning multiple sectors and regions. Check out the
[list of references](https://ait-energy.github.io/IESopt.jl/dev/pages/references/) for more information.

## Install

Make sure to check out the detailed [installation guides](https://ait-energy.github.io/IESopt.jl/dev/#Installation)
in the documentation, both for Python and Julia. Depending on your use-case, and choice of programming language / setup,
there are different ways to get started. If you are experienced with Julia, and want to interact with the core model
itself, then using `IESopt.jl` directly will suit you best. If you are looking for a more user-friendly interaction, or
are new to energy system modeling and/or coding at all, you might want to check out the Python wrapper
[iesopt](https://github.com/ait-energy/iesopt).

> If you are not 110% sure where to start... start here: [iesopt](https://github.com/ait-energy/iesopt)

### Quick setup for Julia

In an open REPL, type `]` to enter the package mode, make sure that your environment is
activated (e.g., do `activate .`), then add the package with the following command:

```bash
(your-env) pkg> add IESopt
```

### Quick setup for Python

Head over to [iesopt](https://github.com/ait-energy/iesopt) and follow the instructions there, or - if you already
have a working Python environment - install the package, e.g., via `poetry`:

```bash
poetry add iesopt
```

## Usage

IESopt requires a configured model to run. You can start with the extensive [first model tutorial](https://ait-energy.github.io/IESopt.jl/dev/pages/tutorials/first_model/).

### Basic usage

The basic workflow to get results from a model, defined by a top-level configuration file `config.iesopt.yaml`, is as
follows:

1. Parse, generate, and build the model from `config.iesopt.yaml`.
2. Optimize the model (the chose solver is specified in `config.iesopt.yaml`).
3. Get the results from the model.

Steps 1. and 2. can be combined in a single call, which the convenience function `run(...)` provides.

#### Using Julia

```julia
using IESopt

model = IESopt.run("config.iesopt.yaml")
results = model.ext[:iesopt].results
```

#### Using Python

```python
import iesopt

model = iesopt.run("config.iesopt.yaml")
df_results = model.results.to_pandas()
```

## API

Check out the full [API reference](https://ait-energy.github.io/IESopt.jl/dev/pages/manual/api/) in the
documentation, and most importantly the [YAML reference](https://ait-energy.github.io/IESopt.jl/dev/pages/manual/yaml/),
that documents how the required model configuration files should be structured.

### Basic API

A short overview is given below.

#### Julia API

```julia
"""Builds and returns a model using the IESopt framework."""
IESopt.generate!(filename::String)

"""Optimize the given model, optionally saving model results to disk."""
IESopt.optimize!(model::JuMP.Model; save_results::Bool=true, kwargs...)

"""Build, optimize, and return a model, in a single call."""
IESopt.run(filename::String; verbosity=nothing, kwargs...)

"""Get the component with the name `component_name` from the `model`."""
IESopt.get_component(model::JuMP.Model, component_name::String)

"""Compute the Irreducible Infeasible Set (IIS) of the model."""
IESopt.compute_IIS(model::JuMP.Model; filename::String = "")
```

### Python API

To be added.

## Contributing

[![Code Style](https://img.shields.io/badge/code_style-custom-blue?style=flat&logo=julia&logoColor=white)](.JuliaFormatter.toml)
[![Readme Style](https://img.shields.io/badge/readme_style-standard-lime?style=flat&logo=julia&logoColor=white)](https://github.com/RichardLitt/standard-readme)

PRs accepted. Checkout the [developer documentation](https://ait-energy.github.io/IESopt.jl/dev/pages/dev_docs/).

## License

[MIT © AIT Austrian Institute of Technology GmbH.](LICENSE)
