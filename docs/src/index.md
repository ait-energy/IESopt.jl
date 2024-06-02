# IESopt.jl

_**Integrated Energy System Optimization** framework written in Julia._

## Introduction

`IESopt.jl` is the core of the IESopt framework, developed at [AIT Austrian Institute of Technology GmbH](https://www.ait.ac.at/).
It is written in Julia, and uses [JuMP](https://github.com/jump-dev/JuMP.jl) package to construct the underlying
mathematical optimization models, and to interface with various solvers. The model is designed to be modular, and allows
for easy extension and customization.

```@meta
# TODO: add "The main functionalities of IESopt.jl are: ..." itemize here.
# TODO: add gitter here
# TODO: cleanup the "About" section, and integrate it here
```

Check out the following GitHub repositories for more information:

- [IESopt.jl](https://github.com/ait-energy/IESopt.jl), the core model (a Julia package).
- [iesopt-py](https://github.com/ait-energy/iesopt-py), the Python interface.

!!! danger "Moving to open-source"
    We are currently working (hard) on getting IESopt fully open-source on GitHub, which requires some clean-up of
    (potentially) confindential left-overs (e.g., from projects). Meanwhile, a lot of internals are changing (after
    staying fixed for a long time), and the documentation needs to be checked page-by-page. If you are trying to
    get started before we manage to fix everything, get in touch with us directly - we'll help you set up everything you
    need. The documentation currently consists of mostly structured pages, with the content being added as soon as
    possible.

## Installation

!!! details "Using Python"
    To be added.

!!! details "Using Julia"
    To be added.

## Citation

If you find IESopt useful in your work, and are intend to publish or document your modeling, we kindly request that you
include the following citation:

- **Style: APA7**
  > Strömer, S., Schwabeneder, D., & contributors. (2021-2024). _IESopt: Integrated Energy System Optimization_ [Software]. AIT Austrian Institute of Technology GmbH. [https://github.com/ait-energy/IESopt](https://github.com/ait-energy/IESopt)
- **Style: IEEE**
  > [1] S. Strömer, D. Schwabeneder, and contributors, _"IESopt: Integrated Energy System Optimization,"_ AIT Austrian Institute of Technology GmbH, 2021-2024. [Online]. Available: [https://github.com/ait-energy/IESopt](https://github.com/ait-energy/IESopt)
- **BibTeX:**
  ```bibtex
  @misc{iesopt,
      author = {Strömer, Stefan and Schwabeneder, Daniel and contributors},
      title = {{IES}opt: Integrated Energy System Optimization},
      organization = {AIT Austrian Institute of Technology GmbH},
      url = {https://github.com/ait-energy/IESopt},
      type = {Software},
      year = {2021-2024},
  }
  ```

```@meta
# ## About

# ### Overview

# IESopt, _Integrated Energy System Optimization_, is a general purpose energy system optimization framework, developed at the [Center for Energy](https://www.ait.ac.at/en/about-the-ait/center/center-for-energy), at [AIT Austrian Institute of Technology GmbH](https://www.ait.ac.at/), mainly developed and maintained by the unit [Integrated Energy Systems](https://www.ait.ac.at/en/research-topics/integrated-energy-systems).

# ### Feature summary

# What IESopt is, may be, and is not:

# - YES
#   - IESopt is a general purpose energy system (optimization) model. It supports multiple solvers (using `JuMP.jl` to interface with them) as well as a standardized way to build up models using "core components".
# - MAYBE
#   - IESopt.jl is not branded as JuMP extension. It plays nicely with JuMP, and some extensions, but we currently do not see it as a fully fledged JuMP extension. That, e.g., entails that `copy_extension_data` is not implemented at the moment, so `copy_model` is not supported. This is a deliberate choice, and may be changed in the - near or far - future.
# - NO (really ...)
#   - A full energy system model, in the sense of "containing data". There are a lot of good, and open, data sources out there from other teams, consider using them.
```
