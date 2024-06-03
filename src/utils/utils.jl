macro critical(msg, args...)
    return esc(quote
        local message = string($msg)
        @error message $(args...)
        error(message)
    end)
end

function _try_loading_solver()
    _try_import(solver::String) = IESopt.eval(Meta.parse("""try; import $(solver); true; catch; false; end;"""))
    active = join([s for s in _ALL_SOLVER_INTERFACES if _try_import(s)], ", ")

    if _is_precompiling()
    else
        @info "Activating solver interfaces" active
    end

    return active
end

# Immediately try to load solver interfaces.
const ACTIVE_SOLVER_INTERFACES = _try_loading_solver()

include("general.jl")
include("logging.jl")
include("packing.jl")
include("overview.jl") # makes use of unpacking (therefore included after packing.jl)
include("docs.jl")

include("utilities/Utilities.jl")
const IESU = Utilities
