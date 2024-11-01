# IESopt.jl

_**Integrated Energy System Optimization** framework written in Julia._

## Introduction

`IESopt.jl` is the core of the IESopt framework, developed at [AIT Austrian Institute of Technology GmbH](https://www.ait.ac.at/).
It is written in Julia, and uses [JuMP](https://github.com/jump-dev/JuMP.jl) package to construct the underlying
mathematical optimization models, and to interface with various solvers. The model is designed to be modular, and allows
for easy extension and customization.

Check out the following GitHub repositories for more information:

- [IESopt.jl](https://github.com/ait-energy/IESopt.jl), the core model (a Julia package).
- [iesopt](https://github.com/ait-energy/iesopt), the Python interface.

!!! danger "Merging documentations"
    We are currently merging this documentation into the (now) central one, over at working [iesopt](https://github.com/ait-energy/iesopt). Besides migrating everything, this requires some clean-up of
    (potentially) confindential left-overs (e.g., from projects), so the documentation needs to be checked page-by-page. If you are trying to
    get started before we manage to fix everything, get in touch with us directly - we'll help you set up everything you
    need.
