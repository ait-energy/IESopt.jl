# Solvers

## Recommended Configurations

The following configurations can be seen as helpful starting point on how to configure different solvers for large-scale
models. They are largely based on other model's defaults (see e.g.
[PyPSA](https://github.com/PyPSA/pypsa-eur-sec/blob/master/config.default.yaml)).

More informations can be found at:

- HiGHS:
    - https://ergo-code.github.io/HiGHS/stable/options/definitions/
- Gurobi:
    - https://www.gurobi.com/wp-content/uploads/2022-10-Paris_Advanced_Algorithms.pdf
    - https://www.gurobi.com/documentation/current/refman/parameters.html
- CPLEX:
    - https://www.ibm.com/docs/en/icos/22.1.1?topic=cplex-list-parameters

### HiGHS

```yaml
solver:
  name: highs
  attributes:
    threads: 4
    solver: "ipm"
    run_crossover: "off"
    small_matrix_value: 1e-6
    large_matrix_value: 1e9
    primal_feasibility_tolerance: 1e-5
    dual_feasibility_tolerance: 1e-5
    ipm_optimality_tolerance: 1e-4
    parallel: "on"
    random_seed: 1234
```

### Gurobi

```yaml
solver:
  name: gurobi
  attributes:
    Method: 2
    Crossover: 0
    BarConvTol: 1.e-6
    Seed: 123
    AggFill: 0
    PreDual: 0
    GURO_PAR_BARDENSETHRESH: 200
    Threads: 8
    Seed: 1234
```

### Gurobi (NumFocus)

For models with "challenging" numerical properties, the following can be useful:

```yaml
solver:
  name: gurobi
  attributes:
    NumericFocus: 3
    Method: 2
    Crossover: 0
    BarHomogeneous: 1
    BarConvTol: 1.e-5
    FeasibilityTol: 1.e-4
    OptimalityTol: 1.e-4
    ObjScale: -0.5
    Threads: 8
    Seed: 1234
```

### Gurobi (fallback)

```yaml
solver:
  name: gurobi
  attributes:
    Crossover: 0
    Method: 2
    BarHomogeneous: 1
    BarConvTol: 1.e-5
    FeasibilityTol: 1.e-5
    OptimalityTol: 1.e-5
    Threads: 8
    Seed: 1234
```

### CPLEX

```yaml
solver:
  name: cplex
  attributes:
    threads: 4
    lpmethod: 4
    solutiontype: 2
    barrier_convergetol: 1.e-5
    feasopt_tolerance: 1.e-6
```
