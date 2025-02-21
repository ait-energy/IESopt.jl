# IESopt: Integrated Energy System Optimization

> This is the Julia core framework of **IESopt**. For a more information and the more beginner-friendly Python wrapper,
> check out the [iesopt repository](https://github.com/ait-energy/iesopt).

---

[![Docs](https://img.shields.io/badge/docs-stable-blue.svg)](https://ait-energy.github.io/iesopt/)

[![License](https://img.shields.io/github/license/ait-energy/IESopt.jl)](LICENSE)
[![Build Status](https://github.com/ait-energy/IESopt.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/ait-energy/IESopt.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/ait-energy/IESopt.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/ait-energy/IESopt.jl)
[![Aqua](https://raw.githubusercontent.com/JuliaTesting/Aqua.jl/master/badge.svg)](https://github.com/JuliaTesting/Aqua.jl)

<!--
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://ait-energy.github.io/IESopt.jl/dev/)
[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://ait-energy.github.io/IESopt.jl/stable/)
-->

**IESopt** (_Integrated Energy System Optimization_) is a modeling and optimization framework for integrated energy
systems.

It is developed and maintained at the **Center for Energy** at
[AIT Austrian Institute of Technology GmbH](https://www.ait.ac.at/). The framework is designed to support the
optimization of energy systems that are characterized by a high degree of integration between different energy carriers
and sectors. It focuses on offering a modular and adaptable tool for modelers, that does not compromise on performance,
while still being user-friendly. This is enabled by reducing energy system assets to abstract building blocks, that are
supported by specialized implementation, and can be combined into complex systems without the need of a detailed
understanding of mathematical modeling or proficiency in any coding-language.

## Quickstart

To install the package, open a Julia REPL and run `add IESopt` in package mode (hit `]`), or run:

```julia
using Pkg
Pkg.add("IESopt")
```

You can then run a model using:

```julia
using IESopt: IESopt

model = IESopt.run("config.iesopt.yaml")
```

Check out the [documentation](https://ait-energy.github.io/iesopt/) for examples and more information.

## Contributing

[![Code Style](https://img.shields.io/badge/code_style-custom-blue?style=flat&logo=julia&logoColor=white)](.JuliaFormatter.toml)

PRs accepted. Checkout the _developer documentation section_ in the [documentation](https://ait-energy.github.io/iesopt/).

## License

[MIT © AIT Austrian Institute of Technology GmbH.](LICENSE)
