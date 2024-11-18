precompile(Tuple{typeof(HiGHS_jll.find_artifact_dir)})
precompile(Tuple{typeof(Base.invokelatest), Any})
precompile(Tuple{typeof(JLLWrappers.get_julia_libpaths)})
precompile(Tuple{Type{Base.VersionNumber}, Int32, Int32, Int32})
precompile(Tuple{typeof(OpenSpecFun_jll.find_artifact_dir)})
precompile(Tuple{typeof(Bzip2_jll.find_artifact_dir)})
precompile(Tuple{typeof(Libiconv_jll.find_artifact_dir)})
precompile(Tuple{typeof(Requires.listenpkg), Any, Base.PkgId})
precompile(Tuple{typeof(Requires.loaded), Base.PkgId})
precompile(Tuple{typeof(Base.haskey), Base.Dict{Base.PkgId, Module}, Base.PkgId})
precompile(Tuple{typeof(Requires.callbacks), Base.PkgId})
precompile(Tuple{typeof(DuckDB_jll.find_artifact_dir)})
precompile(Tuple{typeof(Requires.loadpkg), Base.PkgId})
precompile(Tuple{typeof(Base.first), Array{Any, 1}})
precompile(Tuple{YAML.var"#3#4"{DataType}, YAML.Constructor, YAML.MappingNode})
precompile(Tuple{typeof(Base._array_for), Type{Float64}, Base.HasShape{1}, Tuple{Base.OneTo{Int64}}})
precompile(Tuple{typeof(Base._array_for), Type{Int64}, Base.HasShape{1}, Tuple{Base.OneTo{Int64}}})
precompile(Tuple{typeof(Base.indexed_iterate), Pair{String, Any}, Int64})
precompile(Tuple{typeof(Base.indexed_iterate), Pair{String, Any}, Int64, Int64})
precompile(Tuple{typeof(Base.iterate), Base.Dict{String, Any}, Int64})
precompile(Tuple{typeof(Base.Unicode.lowercase), String})
precompile(Tuple{typeof(Base.get), Base.Dict{String, Any}, String, String})
precompile(Tuple{typeof(Base.replace), String, Pair{Char, Char}})
precompile(
    Tuple{
        Base.Filesystem.var"#_walkdir#35"{Bool, Bool, typeof(throw)},
        Base.Channel{Tuple{String, Array{String, 1}, Array{String, 1}}},
        String,
    },
)
precompile(Tuple{typeof(Base.getproperty), Base.GenericCondition{Base.ReentrantLock}, Symbol})
precompile(Tuple{Distributed.var"#137#139"})
precompile(Tuple{typeof(Base.convert), Type{String}, String})
precompile(Tuple{typeof(Base.string), Module})
precompile(Tuple{typeof(Base.Filesystem.contractuser), String})
precompile(
    Tuple{
        Type{Base.IOContext{IO_t} where IO_t <: IO},
        Base.GenericIOBuffer{GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)}},
        Base.TTY,
    },
)
precompile(Tuple{typeof(Base.write), Base.TTY, Array{UInt8, 1}})
precompile(Tuple{typeof(Base.get), Base.Dict{String, String}, String, String})
precompile(Tuple{typeof(Base.get), Base.Dict{String, Bool}, String, Bool})
precompile(Tuple{typeof(Base.getindex), Base.Dict{String, String}, String})
precompile(Tuple{typeof(Base.split), String, String})
precompile(Tuple{Type{Base.Set{T} where T}, Array{Symbol, 1}})
precompile(Tuple{typeof(Base.get), Base.Dict{String, Any}, String, Bool})
precompile(Tuple{Type{Pair{A, B} where {B} where A}, String, Nothing})
precompile(Tuple{Type{Pair{A, B} where {B} where A}, String, Base.Dict{String, Array{String, 1}}})
precompile(Tuple{typeof(Base.getindex), Base.Dict{String, Bool}, String})
precompile(Tuple{typeof(Base.Filesystem.mkpath), String})
precompile(Tuple{typeof(Base.repeat), Char, Int64})
precompile(Tuple{typeof(Base.isopen), Base.IOStream})
precompile(
    Tuple{
        Type{Base.IOContext{IO_t} where IO_t <: IO},
        Base.GenericIOBuffer{GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)}},
        Base.IOStream,
    },
)
precompile(
    Tuple{
        typeof(Base.print),
        Base.IOContext{Base.GenericIOBuffer{GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)}}},
        Base.SubString{String},
    },
)
precompile(Tuple{typeof(Base.write), Base.IOStream, Array{UInt8, 1}})
precompile(Tuple{typeof(Base.getindex), Array{Float64, 1}, Int64})
precompile(Tuple{typeof(Base.getindex), Array{Bool, 1}, Int64})
precompile(Tuple{typeof(Base.iterate), Array{AbstractString, 1}})
precompile(Tuple{typeof(Base.iterate), Array{AbstractString, 1}, Int64})
precompile(Tuple{typeof(Base.copy), GenericMemory{:not_atomic, Int64, Core.AddrSpace{Core}(0x00)}})
precompile(Tuple{typeof(Base.iterate), Base.Dict{String, Array{String, 1}}})
precompile(Tuple{typeof(Base.indexed_iterate), Pair{String, Array{String, 1}}, Int64})
precompile(Tuple{typeof(Base.indexed_iterate), Pair{String, Array{String, 1}}, Int64, Int64})
precompile(Tuple{typeof(Base.iterate), Base.Dict{String, Array{String, 1}}, Int64})
precompile(Tuple{typeof(Base.keys), Base.Dict{String, Any}})
precompile(Tuple{typeof(Base.iterate), Base.KeySet{String, Base.Dict{String, Any}}})
precompile(Tuple{typeof(Base.iterate), Base.KeySet{String, Base.Dict{String, Any}}, Int64})
precompile(Tuple{Type{Pair{A, B} where {B} where A}, IESopt.Carrier, String})
precompile(Tuple{typeof(Base.getindex), Array{Base.SubString{String}, 1}, Int64})
precompile(Tuple{typeof(Base.contains), Base.SubString{String}, Base.Regex})
precompile(Tuple{typeof(Base.getproperty), Core.MethodTable, Symbol})
precompile(Tuple{typeof(Base.:(>)), Float64, Float64})
precompile(Tuple{typeof(Base.clamp), Float64, Int64, Int64})
precompile(Tuple{typeof(Base.round), Type{Int64}, Float64})
precompile(
    Tuple{
        typeof(MathOptInterface.set),
        MathOptInterface.Utilities.CachingOptimizer{
            MathOptInterface.Bridges.LazyBridgeOptimizer{HiGHS.Optimizer},
            MathOptInterface.Utilities.UniversalFallback{
                MathOptInterface.Utilities.GenericModel{
                    Float64,
                    MathOptInterface.Utilities.ObjectiveContainer{Float64},
                    MathOptInterface.Utilities.VariablesContainer{Float64},
                    MathOptInterface.Utilities.ModelFunctionConstraints{Float64},
                },
            },
        },
        MathOptInterface.VariableName,
        MathOptInterface.VariableIndex,
        String,
    },
)
precompile(
    Tuple{typeof(Base.getindex), Array{JuMP.GenericAffExpr{Float64, JuMP.GenericVariableRef{Float64}}, 1}, Int64},
)
precompile(
    Tuple{typeof(JuMP.add_to_expression!), JuMP.GenericAffExpr{Float64, JuMP.GenericVariableRef{Float64}}, Float64},
)
precompile(Tuple{typeof(Base.getindex), Array{JuMP.GenericVariableRef{Float64}, 1}, Int64})
precompile(
    Tuple{
        typeof(MathOptInterface.set),
        MathOptInterface.Utilities.CachingOptimizer{
            MathOptInterface.Bridges.LazyBridgeOptimizer{HiGHS.Optimizer},
            MathOptInterface.Utilities.UniversalFallback{
                MathOptInterface.Utilities.GenericModel{
                    Float64,
                    MathOptInterface.Utilities.ObjectiveContainer{Float64},
                    MathOptInterface.Utilities.VariablesContainer{Float64},
                    MathOptInterface.Utilities.ModelFunctionConstraints{Float64},
                },
            },
        },
        MathOptInterface.ConstraintName,
        MathOptInterface.ConstraintIndex{
            MathOptInterface.ScalarAffineFunction{Float64},
            MathOptInterface.GreaterThan{Float64},
        },
        String,
    },
)
precompile(
    Tuple{
        typeof(JuMP.model_convert),
        JuMP.GenericModel{Float64},
        JuMP.ScalarConstraint{
            JuMP.GenericAffExpr{Float64, JuMP.GenericVariableRef{Float64}},
            MathOptInterface.LessThan{Float64},
        },
    },
)
precompile(Tuple{typeof(MutableArithmetics.copy_if_mutable), Float64})
precompile(Tuple{typeof(Base.isempty), Array{Float64, 1}})
precompile(Tuple{typeof(Base.getproperty), Base.CoreLogging.SimpleLogger, Symbol})
precompile(Tuple{typeof(Base.getproperty), Base.IOStream, Symbol})
precompile(Tuple{Type{String}, Array{UInt8, 1}})
precompile(
    Tuple{
        typeof(MathOptInterface.Bridges.unbridged_function),
        MathOptInterface.Bridges.LazyBridgeOptimizer{HiGHS.Optimizer},
        Float64,
    },
)
precompile(
    Tuple{
        typeof(Base.isequal),
        Distributed.RemoteChannel{Base.Channel{Bool}},
        Distributed.RemoteChannel{Base.Channel{Bool}},
    },
)
precompile(Tuple{typeof(Base.getproperty), Distributed.RemoteValue, Symbol})
