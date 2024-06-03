"""
    Utilities

This module contains utility functions for the IESopt package, that can be helpful in preparing or analysing components.
"""
module Utilities

import ..IESopt
import ..IESopt: @critical
import ArgCheck: @argcheck
import JuMP

include("model_wrapper.jl")

"""
    annuity(total::Number; lifetime::Number, rate::Float64, fraction::Float64)

Calculate the annuity of a total amount over a lifetime with a given interest rate.

# Arguments

- `total::Number`: The total amount to be annuitized.

# Keyword Arguments

- `lifetime::Number`: The lifetime over which the total amount is to be annuitized.
- `rate::Float64`: The interest rate at which the total amount is to be annuitized.
- `fraction::Float64`: The fraction of a year that the annuity is to be calculated for (default: 1.0).

# Returns

`Float64`: The annuity of the total amount over the lifetime with the given interest rate.

# Example

Calculating a simple annuity, for a total amount of € 1000,- over a lifetime of 10 years with an interest rate of 5%:

```julia
# Set a parameter inside a template.
set("capex", IESU.annuity(1000.0; lifetime=10, rate=0.05))
```

Calculating a simple annuity, for a total amount of € 1000,- over a lifetime of 10 years with an interest rate of 5%,
for a fraction of a year (given by `MODEL.yearspan`, which is the total timespan of the model in years):
    
```julia
# Set a parameter inside a template.
set("capex", IESU.annuity(1000.0; lifetime=10, rate=0.05, fraction=MODEL.yearspan))
```
"""
function annuity(total::Number; lifetime::Number, rate::Float64, fraction::Float64=1.0)::Float64
    @argcheck total >= 0
    @argcheck 0 < lifetime < 1e3
    @argcheck 0.0 < rate < 1.0
    @argcheck fraction > 0
    return total * rate / (1 - (1 + rate)^(-lifetime)) * fraction
end

function annuity(total::Number, lifetime::Number, rate::Number)
    msg = "Error trying to call `annuity($(total), $(lifetime), $(rate))`"
    reason = "`lifetime` and `rate` must be passed as keyword arguments to `annuity(...)`"
    example = "`annuity(1000.0; lifetime=10, rate=0.05)`"
    @critical msg reason example
end

function annuity(total::Number, lifetime::Number, rate::Number, fraction::Number)
    msg = "Error trying to call `annuity($(total), $(lifetime), $(rate), $(fraction))`"
    reason = "`lifetime`, `rate`, and `fraction` must be passed as keyword arguments to `annuity(...)`"
    example = "`annuity($(total); lifetime=$(lifetime), rate=$(rate), fraction=$(fraction))`"
    @critical msg reason example
end

end
