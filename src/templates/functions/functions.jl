function _compile_rgf(ex; id::Tuple, opaque_closures::Bool=true)
    cache_tag = getfield(@__MODULE__, Symbol("#_RGF_ModTag"))
    context_tag = getfield(@__MODULE__, Symbol("#_RGF_ModTag"))

    def = RuntimeGeneratedFunctions.splitdef(ex)
    args = RuntimeGeneratedFunctions.normalize_args(get(def, :args, Symbol[]))

    body = def[:body]
    if opaque_closures
        body = RuntimeGeneratedFunctions.closures_to_opaque(body)
    end

    cached_body = RuntimeGeneratedFunctions._cache_body(cache_tag, id, body)

    return RuntimeGeneratedFunctions.RuntimeGeneratedFunction{Tuple(args), cache_tag, context_tag, id}(cached_body)
end

include("prepare.jl")
include("validate.jl")
include("finalize.jl")
