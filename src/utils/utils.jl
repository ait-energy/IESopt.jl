
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

function _get_solver_module(solver::Any)
    @critical "No solver extension prepared" solver
end

include("general.jl")
include("logging.jl")
include("packing.jl")
include("overview.jl") # makes use of unpacking (therefore included after packing.jl)
include("docs.jl")

include("utilities/Utilities.jl")
const IESU = Utilities
