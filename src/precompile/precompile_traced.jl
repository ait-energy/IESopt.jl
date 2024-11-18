# julia --optimize=0 --startup-file=no --project=. --trace-compile=precompile.jl workload.jl

# Currently failing lookups:
# - Bzip2_jll
# - HiGHS_jll

function _precompile_cleaning_walker(__item)
    if MacroTools.@capture(__item, precompile(args__))
        return quote
            try
                $__item
            catch __exception
                if __exception isa UndefVarError
                    push!(__unknowns, (scope=__exception.scope, var=__exception.var))
                else
                    @warn __exception
                end

                nothing
            end
        end
    end

    return __item
end

function _precompile_traces()
    traces_file = (RelocatableFolders.@path normpath(@__DIR__, "traces.jl"))::RelocatableFolders.Path
    traces = read(traces_file, String)

    statements = JuliaSyntax.parsestmt(
        Expr,
        """
let
    # Indirectly "importing" these packages.
    Requires = ResultsJLD2.JLD2.FileIO.Requires
    MacroTools = JuMP.MacroTools
    MathOptInterface = JuMP.MOI
    InvertedIndices = DataFrames.InvertedIndices
    Mmap = CSV.Mmap
    Distributed = ProgressMeter.Distributed
    MutableArithmetics = JuMP.MutableArithmetics
    Serialization = RuntimeGeneratedFunctions.Serialization
    DuckDB_jll = ResultsDuckDB.DuckDB.DuckDB_jll
    SentinelArrays = CSV.SentinelArrays
    InlineStrings = CSV.InlineStrings

    # The following are "cross-indirect-dependencies", and require some previous definition.
    CodecBzip2 = MathOptInterface.FileFormats.CodecBzip2
    JLLWrappers = DuckDB_jll.JLLWrappers
    SpecialFunctions = MathOptInterface.Nonlinear.SpecialFunctions
    OpenSpecFun_jll = SpecialFunctions.OpenSpecFun_jll
    Libiconv_jll = YAML.StringEncodings.Libiconv_jll

    __unknowns = Set()
    
    $traces
    
    if !isempty(__unknowns)
        @warn "Detected a total of \$(length(__unknowns)) unknown precompile entries"
        for elem in __unknowns
            @info "Missing: \$(elem.scope).\$(elem.var)"
        end
    end

    nothing
end
""",
    )

    safe_statements = MacroTools.postwalk(_precompile_cleaning_walker, statements)
    @eval $safe_statements

    return nothing
end

_precompile_traces()
