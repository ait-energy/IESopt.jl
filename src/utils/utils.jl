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
