
"""
    @critical(msg, args...)

A macro that logs an error message and then throws an error with the same message. Use it in the same way you would use `@error`, or `@info`, etc.

# Arguments
- `msg`: The main error message to be logged and thrown.
- `args...`: Additional arguments to be included in the error log.
"""
macro critical(msg, args...)
    return esc(quote
        local message = string($msg)
        @error message $(args...)
        error(message)
    end)
end

"""
    @config(model, expr, type::Union{Symbol, Expr}=:Any)

Returns or sets a configuration value in the `model`'s configuration dictionary.

This macro is used to set and retrieve configuration values in the `model`'s configuration dictionary. This resolves the
access properly during compile time. A type can be optionally specified to assert the type of the value.

# Example

```julia
# Setting a configuration value.
@config(model, general.verbosity.core) = "info"

# Getting a configuration value.
verbosity = @config(model, general.verbosity.core, String)
```
"""
macro config(model, expr, type::Union{Symbol, Expr}=:Any)
    function walk(item)
        if item isa Expr && item.head == :.
            # Do `foo.bar` -> `foo["bar"]`.
            a, b = item.args
            return :($a[$(string(b.value))])
        elseif item isa Symbol
            # This is the first "accessors" in the chain.
            return :(__config__[$(string(item))])
        end

        return item
    end

    # Use to substitute the `__config__` symbol with the actual configuration.
    function substitute_model(item)
        (item === :(__config__)) && return :($(esc(model)).ext[:_iesopt].input.config)
        return item
    end

    # Walk to properly access the dict(s).
    expr = MacroTools.postwalk(walk, expr)

    # Walk to substitute `__config__`.
    expr = MacroTools.postwalk(substitute_model, expr)

    # Return expression, including the optional type assert.
    (type != :Any) && return :($expr::$type)
    return expr
end

function _get_solver_module(solver::Any)
    @critical "No solver extension prepared" solver
end

include("general.jl")
include("logging.jl")
include("packing.jl")
include("overview.jl") # makes use of unpacking (therefore included after packing.jl)
include("docs.jl")
include("objectives.jl")

include("modules/Utilities.jl")
const IESU = Utilities

include("testing.jl")
