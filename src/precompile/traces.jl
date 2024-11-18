precompile(Tuple{typeof(Base.:(==)), Symbol, Symbol})
precompile(Tuple{Type{NamedTuple{(:dicttype,), T} where T <: Tuple}, Tuple{DataType}})
precompile(Tuple{typeof(Base.getproperty), Base.Generator{Tuple{}, FilePathsBase.var"#10#11"}, Symbol})
precompile(Tuple{Type{NamedTuple{(:validate,), T} where T <: Tuple}, Tuple{Bool}})
precompile(Tuple{Type{NamedTuple{(:all, :imported), T} where T <: Tuple}, Tuple{Bool, Bool}})
precompile(Tuple{Type{NamedTuple{(:path, :slice), T} where T <: Tuple}, Tuple{Symbol, Bool}})
precompile(Tuple{Type{InvertedIndices.InvertedIndex{S} where S}, Symbol})
precompile(Tuple{typeof(Base.convert), Type{Symbol}, Symbol})
precompile(Tuple{Type{NamedTuple{(:throw,), T} where T <: Tuple}, Tuple{Bool}})
precompile(Tuple{typeof(Core.memoryref), GenericMemory{:not_atomic, Float64, Core.AddrSpace{Core}(0x00)}})
precompile(
    Tuple{
        typeof(Core.memoryref),
        GenericMemory{:not_atomic, NamedTuple{names, T} where {T <: Tuple} where names, Core.AddrSpace{Core}(0x00)},
    },
)
precompile(Tuple{typeof(Base.:(==)), Bool, Bool})
precompile(Tuple{typeof(IESopt.generate!), AbstractString})
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
precompile(Tuple{Type{Base.Dict{K, V} where {V} where K}, Pair{Symbol, Nothing}, Vararg{Pair{Symbol, Nothing}}})
precompile(Tuple{Type{Base.Dict{Symbol, Nothing}}, NTuple{6, Pair{Symbol, Nothing}}})
precompile(Tuple{typeof(Base.getindex), Base.Dict{Symbol, Nothing}, Symbol})
precompile(Tuple{typeof(Base.getindex), Base.Dict{String, String}, String})
precompile(
    Tuple{typeof(Core.memoryref), GenericMemory{:not_atomic, Array{Pair{Symbol, Any}, 1}, Core.AddrSpace{Core}(0x00)}},
)
precompile(
    Tuple{
        typeof(Base.CoreLogging.handle_message),
        Base.CoreLogging.ConsoleLogger,
        Base.CoreLogging.LogLevel,
        Vararg{Any, 6},
    },
)
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
precompile(Tuple{typeof(Base.split), String, String})
precompile(Tuple{Type{Base.Set{T} where T}, Array{Symbol, 1}})
precompile(Tuple{typeof(Base.get), Base.Dict{String, Any}, String, Bool})
precompile(Tuple{Type{Pair{A, B} where {B} where A}, String, Nothing})
precompile(Tuple{Type{Pair{A, B} where {B} where A}, String, Base.Dict{String, Array{String, 1}}})
precompile(Tuple{typeof(Base.getindex), Base.Dict{String, Bool}, String})
precompile(Tuple{typeof(Base.Filesystem.mkpath), String})
precompile(
    Tuple{
        typeof(Core.kwcall),
        NamedTuple{(:authors, :version, :top_level_config, :path), Tuple{String, Base.VersionNumber, String, String}},
        typeof(Base.CoreLogging.handle_message),
        LoggingExtras.TeeLogger{Tuple{Base.CoreLogging.ConsoleLogger, IESopt._FileLogger}},
        Base.CoreLogging.LogLevel,
        String,
        Module,
        Symbol,
        Symbol,
        String,
        Int64,
    },
)
precompile(
    Tuple{
        typeof(Core.kwcall),
        NamedTuple{names, T} where {T <: Tuple} where names,
        typeof(Base.CoreLogging.handle_message),
        Base.CoreLogging.ConsoleLogger,
        Base.CoreLogging.LogLevel,
        Vararg{Any, 6},
    },
)
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
precompile(
    Tuple{
        typeof(Base.CoreLogging.handle_message),
        LoggingExtras.TeeLogger{Tuple{Base.CoreLogging.ConsoleLogger, IESopt._FileLogger}},
        Base.CoreLogging.LogLevel,
        String,
        Module,
        Symbol,
        Symbol,
        String,
        Int64,
    },
)
precompile(Tuple{typeof(Base.iterate), Array{AbstractString, 1}})
precompile(Tuple{typeof(Base.iterate), Array{AbstractString, 1}, Int64})
precompile(
    Tuple{
        typeof(Core.kwcall),
        NamedTuple{(:count,), Tuple{Int64}},
        typeof(Base.CoreLogging.handle_message),
        LoggingExtras.TeeLogger{Tuple{Base.CoreLogging.ConsoleLogger, IESopt._FileLogger}},
        Base.CoreLogging.LogLevel,
        String,
        Module,
        Symbol,
        Symbol,
        String,
        Int64,
    },
)
precompile(
    Tuple{
        typeof(Core.kwcall),
        NamedTuple{(:number_of_disabled_components,), Tuple{Int64}},
        typeof(Base.CoreLogging.handle_message),
        LoggingExtras.TeeLogger{Tuple{Base.CoreLogging.ConsoleLogger, IESopt._FileLogger}},
        Base.CoreLogging.LogLevel,
        String,
        Module,
        Symbol,
        Symbol,
        String,
        Int64,
    },
)
precompile(Tuple{typeof(Base.copy), GenericMemory{:not_atomic, Int64, Core.AddrSpace{Core}(0x00)}})
precompile(Tuple{typeof(Base.iterate), Base.Dict{String, Array{String, 1}}})
precompile(Tuple{typeof(Base.indexed_iterate), Pair{String, Array{String, 1}}, Int64})
precompile(Tuple{typeof(Base.indexed_iterate), Pair{String, Array{String, 1}}, Int64, Int64})
precompile(Tuple{typeof(Base.iterate), Base.Dict{String, Array{String, 1}}, Int64})
precompile(
    Tuple{
        typeof(Core.kwcall),
        NamedTuple{(:n_components,), Tuple{Int64}},
        typeof(Base.CoreLogging.handle_message),
        LoggingExtras.TeeLogger{Tuple{Base.CoreLogging.ConsoleLogger, IESopt._FileLogger}},
        Base.CoreLogging.LogLevel,
        String,
        Module,
        Symbol,
        Symbol,
        String,
        Int64,
    },
)
precompile(Tuple{typeof(Base.keys), Base.Dict{String, Any}})
precompile(Tuple{typeof(Base.iterate), Base.KeySet{String, Base.Dict{String, Any}}})
precompile(Tuple{typeof(Base.iterate), Base.KeySet{String, Base.Dict{String, Any}}, Int64})
precompile(Tuple{Type{Pair{A, B} where {B} where A}, IESopt.Carrier, String})
precompile(
    Tuple{
        typeof(Core.kwcall),
        NamedTuple{(:Connection, :Unit, :Decision, :Profile, :Node), NTuple{5, Int64}},
        typeof(Base.CoreLogging.handle_message),
        LoggingExtras.TeeLogger{Tuple{Base.CoreLogging.ConsoleLogger, IESopt._FileLogger}},
        Base.CoreLogging.LogLevel,
        String,
        Module,
        Symbol,
        Symbol,
        String,
        Int64,
    },
)
precompile(Tuple{typeof(IESopt._prepare!), IESopt.Unit})
precompile(Tuple{typeof(Base.getindex), Array{Base.SubString{String}, 1}, Int64})
precompile(Tuple{typeof(Base.contains), Base.SubString{String}, Base.Regex})
precompile(Tuple{typeof(Base.getproperty), Core.MethodTable, Symbol})
precompile(Tuple{Type{NamedTuple{(:ignore_predictor,), T} where T <: Tuple}, Tuple{Bool}})
precompile(Tuple{ProgressMeter.var"#45#48"{ProgressMeter.Progress, Distributed.RemoteChannel{Base.Channel{Bool}}}})
precompile(Tuple{typeof(Base.:(>)), Float64, Float64})
precompile(Tuple{typeof(Base.clamp), Float64, Int64, Int64})
precompile(Tuple{typeof(Base.round), Type{Int64}, Float64})
precompile(Tuple{typeof(ProgressMeter.tty_width), String, Base.TTY, Bool})
precompile(
    Tuple{
        typeof(Core.kwcall),
        NamedTuple{(:barglyphs,), Tuple{ProgressMeter.BarGlyphs}},
        typeof(ProgressMeter.barstring),
        Int64,
        Float64,
    },
)
precompile(Tuple{typeof(Base.StringVector), Int64})
precompile(Tuple{Type{Printf.Spec{Base.Val{Char(0x73000000)}}}, Bool, Bool, Bool, Bool, Bool, Int64, Int64, Bool, Bool})
precompile(Tuple{typeof(Base.print), Base.TTY, String})
precompile(Tuple{typeof(ProgressMeter.move_cursor_up_while_clearing_lines), Base.TTY, Int64})
precompile(Tuple{typeof(ProgressMeter.printover), Base.TTY, String, Symbol})
precompile(Tuple{typeof(Base.flush), Base.TTY})
precompile(Tuple{typeof(Base.println), Base.TTY})
precompile(Tuple{typeof(Base.Broadcast.broadcastable), Int64})
precompile(Tuple{typeof(Base.getproperty), Distributed.RemoteValue, Symbol})
precompile(
    Tuple{
        ProgressMeter.var"#46#49"{
            Distributed.RemoteChannel{Base.Channel{Bool}},
            IESopt.var"#397#399"{JuMP.GenericModel{Float64}, typeof(IESopt._construct_variables!)},
        },
        IESopt.Profile,
    },
)
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
    Tuple{
        ProgressMeter.var"#46#49"{
            Distributed.RemoteChannel{Base.Channel{Bool}},
            IESopt.var"#397#399"{JuMP.GenericModel{Float64}, typeof(IESopt._construct_variables!)},
        },
        IESopt.Node,
    },
)
precompile(
    Tuple{
        ProgressMeter.var"#46#49"{
            Distributed.RemoteChannel{Base.Channel{Bool}},
            IESopt.var"#397#399"{JuMP.GenericModel{Float64}, typeof(IESopt._construct_variables!)},
        },
        IESopt.Unit,
    },
)
precompile(
    Tuple{typeof(Base.getindex), Array{JuMP.GenericAffExpr{Float64, JuMP.GenericVariableRef{Float64}}, 1}, Int64},
)
precompile(
    Tuple{typeof(JuMP.add_to_expression!), JuMP.GenericAffExpr{Float64, JuMP.GenericVariableRef{Float64}}, Float64},
)
precompile(
    Tuple{
        ProgressMeter.var"#46#49"{
            Distributed.RemoteChannel{Base.Channel{Bool}},
            IESopt.var"#397#399"{JuMP.GenericModel{Float64}, typeof(IESopt._construct_constraints!)},
        },
        IESopt.Profile,
    },
)
precompile(Tuple{typeof(JuMP._constant_to_number), Int64})
precompile(Tuple{typeof(JuMP._constant_to_number), Float64})
precompile(Tuple{typeof(Base.iszero), Float64})
precompile(
    Tuple{
        ProgressMeter.var"#46#49"{
            Distributed.RemoteChannel{Base.Channel{Bool}},
            IESopt.var"#397#399"{JuMP.GenericModel{Float64}, typeof(IESopt._construct_constraints!)},
        },
        IESopt.Node,
    },
)
precompile(
    Tuple{
        ProgressMeter.var"#46#49"{
            Distributed.RemoteChannel{Base.Channel{Bool}},
            IESopt.var"#397#399"{JuMP.GenericModel{Float64}, typeof(IESopt._construct_constraints!)},
        },
        IESopt.Unit,
    },
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
precompile(
    Tuple{
        typeof(Core.kwcall),
        NamedTuple{(:name,), Tuple{String}},
        typeof(Base.CoreLogging.handle_message),
        LoggingExtras.TeeLogger{Tuple{Base.CoreLogging.ConsoleLogger, IESopt._FileLogger}},
        Base.CoreLogging.LogLevel,
        String,
        Module,
        Symbol,
        Symbol,
        String,
        Int64,
    },
)
precompile(Tuple{typeof(Base.isempty), Array{Float64, 1}})
precompile(
    Tuple{
        typeof(Base.show),
        Base.IOContext{Base.TTY},
        Base.Multimedia.MIME{:var"text/plain"},
        JuMP.GenericModel{Float64},
    },
)
precompile(
    Tuple{
        typeof(MathOptInterface.get),
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
        MathOptInterface.Name,
    },
)
precompile(Tuple{typeof(Base.println), Base.IOContext{Base.TTY}, String})
precompile(Tuple{typeof(Base.print), Base.IOContext{Base.TTY}, MathOptInterface.OptimizationSense})
precompile(
    Tuple{
        typeof(MathOptInterface.get),
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
        MathOptInterface.ObjectiveFunctionType,
    },
)
precompile(
    Tuple{
        typeof(MathOptInterface.get),
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
        MathOptInterface.NumberOfVariables,
    },
)
precompile(
    Tuple{
        typeof(MathOptInterface.get),
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
        MathOptInterface.ListOfConstraintTypesPresent,
    },
)
precompile(Tuple{typeof(Base._array_for), Type{Tuple{Type, Type}}, Array{Tuple{Type, Type}, 1}, Base.HasShape{1}})
precompile(
    Tuple{
        Type{Base.LinearIndices{N, R} where {R <: Tuple{Vararg{Base.AbstractUnitRange{Int64}, N}}} where N},
        Array{Tuple{Type, Type}, 1},
    },
)
precompile(Tuple{typeof(Base.iterate), Array{Tuple{Type, Type}, 1}})
precompile(Tuple{typeof(Base.indexed_iterate), Tuple{DataType, DataType}, Int64})
precompile(Tuple{typeof(Base.indexed_iterate), Tuple{DataType, DataType}, Int64, Int64})
precompile(Tuple{typeof(Base.setindex!), Array{Tuple{Type, Type}, 1}, Tuple{DataType, DataType}, Int64})
precompile(Tuple{typeof(Base.iterate), Array{Tuple{Type, Type}, 1}, Int64})
precompile(
    Tuple{
        typeof(JuMP.num_constraints),
        JuMP.GenericModel{Float64},
        Type{JuMP.GenericAffExpr{Float64, JuMP.GenericVariableRef{Float64}}},
        Type{MathOptInterface.EqualTo{Float64}},
    },
)
precompile(
    Tuple{
        typeof(MathOptInterface.get),
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
        MathOptInterface.NumberOfConstraints{
            MathOptInterface.ScalarAffineFunction{Float64},
            MathOptInterface.EqualTo{Float64},
        },
    },
)
precompile(
    Tuple{
        typeof(MathOptInterface.Utilities.print_with_acronym),
        Base.GenericIOBuffer{GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)}},
        String,
    },
)
precompile(
    Tuple{
        typeof(JuMP.num_constraints),
        JuMP.GenericModel{Float64},
        Type{JuMP.GenericAffExpr{Float64, JuMP.GenericVariableRef{Float64}}},
        Type{MathOptInterface.GreaterThan{Float64}},
    },
)
precompile(
    Tuple{
        typeof(MathOptInterface.get),
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
        MathOptInterface.NumberOfConstraints{
            MathOptInterface.ScalarAffineFunction{Float64},
            MathOptInterface.GreaterThan{Float64},
        },
    },
)
precompile(
    Tuple{
        typeof(JuMP.num_constraints),
        JuMP.GenericModel{Float64},
        Type{JuMP.GenericAffExpr{Float64, JuMP.GenericVariableRef{Float64}}},
        Type{MathOptInterface.LessThan{Float64}},
    },
)
precompile(
    Tuple{
        typeof(MathOptInterface.get),
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
        MathOptInterface.NumberOfConstraints{
            MathOptInterface.ScalarAffineFunction{Float64},
            MathOptInterface.LessThan{Float64},
        },
    },
)
precompile(
    Tuple{
        typeof(JuMP.num_constraints),
        JuMP.GenericModel{Float64},
        Type{JuMP.GenericVariableRef{Float64}},
        Type{MathOptInterface.GreaterThan{Float64}},
    },
)
precompile(Tuple{typeof(Base._bool), MathOptInterface.Utilities.var"#114#115"{UInt16}})
precompile(
    Tuple{
        typeof(MathOptInterface.get),
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
        MathOptInterface.NumberOfConstraints{MathOptInterface.VariableIndex, MathOptInterface.GreaterThan{Float64}},
    },
)
precompile(Tuple{Type{NamedTuple{(:default,), T} where T <: Tuple}, Tuple{Float64}})
precompile(
    Tuple{
        ProgressMeter.var"#46#49"{
            Distributed.RemoteChannel{Base.Channel{Bool}},
            IESopt.var"#397#399"{JuMP.GenericModel{Float64}, typeof(IESopt._construct_variables!)},
        },
        IESopt.Connection,
    },
)
precompile(Tuple{typeof(Base._array_for), Type{String}, Base.HasShape{1}, Tuple{Base.OneTo{Int64}}})
precompile(
    Tuple{IESopt.var"##_getfile#18", Symbol, Type, Bool, typeof(IESopt._getfile), JuMP.GenericModel{Float64}, String},
)
precompile(
    Tuple{
        typeof(Core.kwcall),
        NamedTuple{(:filename,), Tuple{String}},
        typeof(Base.CoreLogging.handle_message),
        LoggingExtras.TeeLogger{Tuple{Base.CoreLogging.ConsoleLogger, IESopt._FileLogger}},
        Base.CoreLogging.LogLevel,
        String,
        Module,
        Symbol,
        Symbol,
        String,
        Int64,
    },
)
precompile(
    Tuple{
        typeof(Base.haskey),
        Base.Pairs{Symbol, String, Tuple{Symbol}, NamedTuple{(:filename,), Tuple{String}}},
        Symbol,
    },
)
precompile(
    Tuple{
        CSV.var"##File#32",
        Int64,
        Bool,
        Int64,
        Int64,
        Int64,
        Bool,
        Nothing,
        Bool,
        Nothing,
        Nothing,
        Nothing,
        Nothing,
        Bool,
        Nothing,
        Nothing,
        Nothing,
        Int64,
        Nothing,
        Array{String, 1},
        String,
        Char,
        Bool,
        Bool,
        Char,
        Nothing,
        Nothing,
        Char,
        Nothing,
        Nothing,
        Char,
        Nothing,
        Array{String, 1},
        Array{String, 1},
        Bool,
        Nothing,
        Nothing,
        Base.IdDict{Type, Type},
        Tuple{Float64, Int64},
        Bool,
        Bool,
        Type{String},
        Bool,
        Bool,
        Int64,
        Bool,
        Bool,
        Bool,
        Type{CSV.File},
        String,
    },
)
precompile(Tuple{typeof(CSV.getbytebuffer), String, Bool})
precompile(Tuple{typeof(Base.indexed_iterate), Tuple{Ptr{Nothing}, Int64}, Int64})
precompile(Tuple{typeof(Base.indexed_iterate), Tuple{Ptr{Nothing}, Int64}, Int64, Int64})
precompile(Tuple{typeof(Base.getindex), Array{UInt8, 1}, Int64})
precompile(Tuple{typeof(Base.min), Int64, Int64})
precompile(Tuple{typeof(CSV.getname), String})
precompile(
    Tuple{typeof(Base.parent), SentinelArrays.SentinelArray{Float64, 1, Float64, Base.Missing, Array{Float64, 1}}},
)
precompile(Tuple{typeof(Base.parent), SentinelArrays.SentinelArray{Int64, 1, Int64, Base.Missing, Array{Int64, 1}}})
precompile(Tuple{typeof(Base.length), Array{Float64, 1}})
precompile(
    Tuple{typeof(Base.length), SentinelArrays.SentinelArray{Float64, 1, Float64, Base.Missing, Array{Float64, 1}}},
)
precompile(Tuple{typeof(Base.length), Array{Int64, 1}})
precompile(Tuple{typeof(Base.length), SentinelArrays.SentinelArray{Int64, 1, Int64, Base.Missing, Array{Int64, 1}}})
precompile(Tuple{typeof(Base.getindex), Array{Int64, 1}, Base.UnitRange{Int64}})
precompile(Tuple{typeof(Base.length), Array{Union{Base.Missing, Int64}, 1}})
precompile(Tuple{typeof(Base.Broadcast.extrude), Array{Float64, 1}})
precompile(Tuple{typeof(Base.setindex!), Array{Float64, 1}, Float64, Int64})
precompile(Tuple{typeof(Base.setindex!), Array{Union{Base.Missing, Float64}, 1}, Base.Missing, Int64})
precompile(Tuple{typeof(Base.Broadcast.extrude), Array{Int64, 1}})
precompile(Tuple{typeof(Base.Broadcast.extrude), Array{Union{Base.Missing, Int64}, 1}})
precompile(Tuple{typeof(Base.setindex!), Array{Union{Base.Missing, Int64}, 1}, Base.Missing, Int64})
precompile(Tuple{DataFrames.var"#952#953", DataFrames.DataFrame})
precompile(Tuple{typeof(Base.copy), Array{Float64, 1}})
precompile(Tuple{typeof(Base.copy), Array{Union{Base.Missing, Float64}, 1}})
precompile(Tuple{typeof(Base.push!), Array{AbstractArray{T, 1} where T, 1}, Array{Union{Base.Missing, Float64}, 1}})
precompile(Tuple{typeof(Base.copy), Array{Union{Base.Missing, Int64}, 1}})
precompile(Tuple{Type{Pair{A, B} where {B} where A}, String, DataFrames.DataFrame})
precompile(
    Tuple{
        typeof(Base.setindex!),
        SentinelArrays.SentinelArray{String, 1, UndefInitializer, Base.Missing, Array{String, 1}},
        String,
        Int64,
    },
)
precompile(Tuple{typeof(Base.sizehint!), Array{String, 1}, Int64})
precompile(Tuple{typeof(Base.getindex), Float64, Int64})
precompile(Tuple{typeof(Base.eof), Base.GenericIOBuffer{GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)}}})
precompile(
    Tuple{
        typeof(Base.read),
        Base.GenericIOBuffer{GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)}},
        Type{Char},
    },
)
precompile(
    Tuple{
        typeof(Base.parent),
        SentinelArrays.SentinelArray{String, 1, UndefInitializer, Base.Missing, Array{String, 1}},
    },
)
precompile(Tuple{typeof(Base.length), Array{Union{Base.Missing, Bool}, 1}})
precompile(Tuple{typeof(Base.copy), Array{Union{Base.Missing, Bool}, 1}})
precompile(Tuple{typeof(Base.getindex), Array{Union{Base.Missing, Int64}, 1}, Int64})
precompile(Tuple{typeof(Base.getindex), Int64, Int64})
precompile(Tuple{typeof(Dates.UTM), Int64})
precompile(Tuple{typeof(Base.:(+)), Vararg{Int64, 4}})
precompile(Tuple{typeof(Base.getindex), Array{Union{Base.Missing, String}, 1}, Int64})
precompile(Tuple{typeof(Base.:(!=)), UInt8, UInt8})
precompile(Tuple{typeof(Base.iterate), Base.SplitIterator{String, Base.Regex}})
precompile(Tuple{typeof(Base.push!), Array{String, 1}, Base.SubString{String}})
precompile(Tuple{typeof(Base.iterate), Base.SplitIterator{String, Base.Regex}, Tuple{Int64, Int64, Int64}})
precompile(
    Tuple{
        typeof(Core.kwcall),
        NamedTuple{(:opaque_closures,), Tuple{Bool}},
        Type{
            RuntimeGeneratedFunctions.RuntimeGeneratedFunction{
                argnames,
                cache_tag,
                context_tag,
                id,
                B,
            } where {B} where {id} where {context_tag} where {cache_tag} where argnames,
        },
        Type,
        Type,
        Expr,
    },
)
precompile(Tuple{typeof(RuntimeGeneratedFunctions.normalize_args), Array{Any, 1}})
precompile(Tuple{Type{Array{Symbol, 1}}, UndefInitializer, Tuple{Int64}})
precompile(
    Tuple{
        typeof(Base.collect_to_with_first!),
        Array{Symbol, 1},
        Symbol,
        Base.Generator{Array{Any, 1}, typeof(RuntimeGeneratedFunctions.normalize_args)},
        Int64,
    },
)
precompile(
    Tuple{
        typeof(Base.show),
        Base.GenericIOBuffer{GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)}},
        Symbol,
    },
)
precompile(Tuple{Type{Tuple}, Array{Symbol, 1}})
precompile(Tuple{Mmap.var"#3#5"{Ptr{Nothing}, Int64}, GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)}})
precompile(Tuple{typeof(Base.contains), String, String})
precompile(
    Tuple{
        Type{
            Base.Broadcast.Broadcasted{
                Style,
                Axes,
                F,
                Args,
            } where {Args <: Tuple} where {F} where {Axes} where Style <: Union{Nothing, Base.Broadcast.BroadcastStyle},
        },
        Base.Broadcast.DefaultArrayStyle{1},
        typeof(Base.string),
        Tuple{Array{Base.SubString{String}, 1}},
    },
)
precompile(
    Tuple{
        Type{
            Base.Broadcast.Broadcasted{
                Style,
                Axes,
                F,
                Args,
            } where {Args <: Tuple} where {F} where {Axes} where Style <: Union{Nothing, Base.Broadcast.BroadcastStyle},
        },
        Base.Broadcast.DefaultArrayStyle{1},
        typeof(Base.string),
        Tuple{Array{Base.SubString{String}, 1}},
        Tuple{Base.OneTo{Int64}},
    },
)
precompile(
    Tuple{
        typeof(Base.copy),
        Base.Broadcast.Broadcasted{
            Base.Broadcast.DefaultArrayStyle{1},
            Tuple{Base.OneTo{Int64}},
            typeof(Base.string),
            Tuple{Array{Base.SubString{String}, 1}},
        },
    },
)
precompile(Tuple{typeof(Base.view), Array{Float64, 1}, Array{Int64, 1}})
precompile(
    Tuple{
        typeof(Core.kwcall),
        NamedTuple{(:filename, :source), Tuple{String, String}},
        typeof(Base.CoreLogging.handle_message),
        LoggingExtras.TeeLogger{Tuple{Base.CoreLogging.ConsoleLogger, IESopt._FileLogger}},
        Base.CoreLogging.LogLevel,
        String,
        Module,
        Symbol,
        Symbol,
        String,
        Int64,
    },
)
precompile(
    Tuple{
        typeof(Base.haskey),
        Base.Pairs{Symbol, String, Tuple{Symbol, Symbol}, NamedTuple{(:filename, :source), Tuple{String, String}}},
        Symbol,
    },
)
precompile(
    Tuple{typeof(Core.kwcall), NamedTuple{(:addon,), Tuple{Symbol}}, typeof(Base.invokelatest), Any, Any, Vararg{Any}},
)
precompile(
    Tuple{
        Base.var"##invokelatest#2",
        Base.Pairs{Symbol, Symbol, Tuple{Symbol}, NamedTuple{(:addon,), Tuple{Symbol}}},
        typeof(Base.invokelatest),
        Any,
        Any,
        Vararg{Any},
    },
)
precompile(
    Tuple{
        typeof(Core.kwcall),
        NamedTuple{(:addon,), Tuple{Symbol}},
        typeof(Base.CoreLogging.handle_message),
        LoggingExtras.TeeLogger{Tuple{Base.CoreLogging.ConsoleLogger, IESopt._FileLogger}},
        Base.CoreLogging.LogLevel,
        String,
        Module,
        Symbol,
        Symbol,
        String,
        Int64,
    },
)
precompile(
    Tuple{
        typeof(Core.kwcall),
        NamedTuple{(:addon,), Tuple{Symbol}},
        typeof(LoggingExtras.comp_handle_message_check),
        Base.CoreLogging.ConsoleLogger,
        Base.CoreLogging.LogLevel,
        Vararg{Any},
    },
)
precompile(
    Tuple{
        LoggingExtras.var"##comp_handle_message_check#1",
        Base.Pairs{Symbol, Symbol, Tuple{Symbol}, NamedTuple{(:addon,), Tuple{Symbol}}},
        typeof(LoggingExtras.comp_handle_message_check),
        Base.CoreLogging.ConsoleLogger,
        Base.CoreLogging.LogLevel,
        Vararg{Any},
    },
)
precompile(Tuple{typeof(Base.pairs), NamedTuple{(:addon,), Tuple{Symbol}}})
precompile(
    Tuple{typeof(Base.haskey), Base.Pairs{Symbol, Symbol, Tuple{Symbol}, NamedTuple{(:addon,), Tuple{Symbol}}}, Symbol},
)
precompile(
    Tuple{
        typeof(Base.CoreLogging.showvalue),
        Base.IOContext{Base.GenericIOBuffer{GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)}}},
        Symbol,
    },
)
precompile(
    Tuple{
        typeof(Core.kwcall),
        NamedTuple{(:addon,), Tuple{Symbol}},
        typeof(LoggingExtras.comp_handle_message_check),
        IESopt._FileLogger,
        Base.CoreLogging.LogLevel,
        Vararg{Any},
    },
)
precompile(
    Tuple{
        LoggingExtras.var"##comp_handle_message_check#1",
        Base.Pairs{Symbol, Symbol, Tuple{Symbol}, NamedTuple{(:addon,), Tuple{Symbol}}},
        typeof(LoggingExtras.comp_handle_message_check),
        IESopt._FileLogger,
        Base.CoreLogging.LogLevel,
        Vararg{Any},
    },
)
precompile(
    Tuple{
        typeof(Core.kwcall),
        NamedTuple{(:addon,), Tuple{Symbol}},
        typeof(Base.CoreLogging.handle_message),
        IESopt._FileLogger,
        Base.CoreLogging.LogLevel,
        String,
        Module,
        Symbol,
        Symbol,
        String,
        Int64,
    },
)
precompile(
    Tuple{
        typeof(Base.:(==)),
        Base.GenericIOBuffer{GenericMemory{:not_atomic, UInt8, Core.AddrSpace{Core}(0x00)}},
        Base.TTY,
    },
)
precompile(Tuple{Type{Base.CoreLogging.LogState}, Base.CoreLogging.ConsoleLogger})
precompile(Tuple{typeof(JuMP.Containers.build_error_fn), Symbol, Tuple{Symbol, Vararg{Expr, 4}}, LineNumberNode})
precompile(
    Tuple{
        typeof(Base.show_call),
        Base.IOContext{Base.AnnotatedIOBuffer},
        Symbol,
        Expr,
        Array{Any, 1},
        Int64,
        Int64,
        Bool,
    },
)
precompile(Tuple{typeof(JuMP.Containers.parse_macro_arguments), Function, Tuple{Symbol, Vararg{Expr, 4}}})
precompile(
    Tuple{
        JuMP.Containers.var"##parse_macro_arguments#96",
        Nothing,
        Nothing,
        typeof(JuMP.Containers.parse_macro_arguments),
        JuMP.Containers.var"#error_fn#98"{String},
        Tuple{Symbol, Vararg{Expr, 4}},
    },
)
precompile(Tuple{typeof(Base.haskey), Base.Dict{Symbol, Any}, Symbol})
precompile(Tuple{typeof(Base.isexpr), Any, NTuple{4, Symbol}})
precompile(Tuple{typeof(Base.popfirst!), Array{Any, 1}})
precompile(Tuple{Type{NamedTuple{(:invalid_index_variables,), T} where T <: Tuple}, Tuple{Array{Symbol, 1}}})
precompile(
    Tuple{
        typeof(Core.kwcall),
        NamedTuple{(:invalid_index_variables,), Tuple{Array{Symbol, 1}}},
        typeof(JuMP.Containers.parse_ref_sets),
        Function,
        Expr,
    },
)
precompile(
    Tuple{
        JuMP.Containers.var"##parse_ref_sets#97",
        Array{Symbol, 1},
        typeof(JuMP.Containers.parse_ref_sets),
        JuMP.Containers.var"#error_fn#98"{String},
        Expr,
    },
)
precompile(Tuple{Type{NamedTuple{(:move_factors_into_sums,), T} where T <: Tuple}, Tuple{Bool}})
precompile(Tuple{typeof(JuMP.parse_constraint_call), Function, Bool, Base.Val{:<=}, Expr, Symbol})
precompile(Tuple{MacroTools.var"#25#26"{typeof(JuMP._rewrite_to_jump_logic)}, QuoteNode})
precompile(Tuple{typeof(Base.setindex_widen_up_to), Array{Symbol, 1}, QuoteNode, Int64})
precompile(Tuple{Type{Array{Expr, 1}}, UndefInitializer, Tuple{Int64}})
precompile(Tuple{typeof(Base.setindex_widen_up_to), Array{Expr, 1}, QuoteNode, Int64})
precompile(Tuple{Type{NamedTuple{(:kwarg_exclude,), T} where T <: Tuple}, Tuple{Array{Symbol, 1}}})
precompile(Tuple{typeof(Base.append!), Array{Any, 1}, Array{Expr, 1}})
precompile(Tuple{Type{NamedTuple{(:register_name, :wrap_let), T} where T <: Tuple}, Tuple{Nothing, Bool}})
precompile(Tuple{Base.RedirectStdStream, Base.TTY})
precompile(Tuple{IESopt.var"#13#16"{Base.PipeEndpoint}})
precompile(Tuple{IESopt.var"#14#17"{Base.PipeEndpoint}})
precompile(
    Tuple{
        Type{Pair{A, B} where {B} where A},
        String,
        NamedTuple{(:addon, :config), Tuple{Module, Base.Dict{String, Any}}},
    },
)
precompile(Tuple{Type{GenericMemory{:not_atomic, String, Core.AddrSpace{Core}(0x00)}}, UndefInitializer, Int64})
precompile(Tuple{Type{Pair{A, B} where {B} where A}, Symbol, Base.Dict{String, Any}})
precompile(Tuple{typeof(Base.:(/)), Float64, Int64})
precompile(
    Tuple{
        typeof(Base.haskey),
        Base.Pairs{
            Symbol,
            Int64,
            NTuple{6, Symbol},
            NamedTuple{(:Connection, :Unit, :ModifyMe, :Decision, :Profile, :Node), NTuple{6, Int64}},
        },
        Symbol,
    },
)
precompile(Tuple{typeof(IESopt.IESoptAddon_Example18.initialize!), JuMP.GenericModel{Float64}, Base.Dict{String, Any}})
precompile(
    Tuple{
        typeof(Core.kwcall),
        NamedTuple{(:addon, :step), Tuple{String, Symbol}},
        typeof(Base.CoreLogging.handle_message),
        LoggingExtras.TeeLogger{Tuple{Base.CoreLogging.ConsoleLogger, IESopt._FileLogger}},
        Base.CoreLogging.LogLevel,
        String,
        Module,
        Symbol,
        Symbol,
        String,
        Int64,
    },
)
precompile(
    Tuple{
        typeof(Base.haskey),
        Base.Pairs{Symbol, Any, Tuple{Symbol, Symbol}, NamedTuple{(:addon, :step), Tuple{String, Symbol}}},
        Symbol,
    },
)
precompile(
    Tuple{
        typeof(IESopt.IESoptAddon_Example18.construct_constraints!),
        JuMP.GenericModel{Float64},
        Base.Dict{String, Any},
    },
)
precompile(
    Tuple{
        Type{Base.Generator{I, F} where {F} where I},
        JuMP.Containers.var"#84#85"{
            IESopt.IESoptAddon_Example18.var"#1#2"{IESopt.Unit, Int64, JuMP.GenericModel{Float64}},
        },
        JuMP.Containers.VectorizedProductIterator{Tuple{Base.OneTo{Int64}}},
    },
)
precompile(
    Tuple{
        typeof(Base.collect),
        Base.Generator{
            JuMP.Containers.VectorizedProductIterator{Tuple{Base.OneTo{Int64}}},
            JuMP.Containers.var"#84#85"{
                IESopt.IESoptAddon_Example18.var"#1#2"{IESopt.Unit, Int64, JuMP.GenericModel{Float64}},
            },
        },
    },
)
precompile(
    Tuple{
        typeof(Base.collect_to_with_first!),
        Array{
            JuMP.ConstraintRef{
                JuMP.GenericModel{Float64},
                MathOptInterface.ConstraintIndex{
                    MathOptInterface.ScalarAffineFunction{Float64},
                    MathOptInterface.LessThan{Float64},
                },
                JuMP.ScalarShape,
            },
            1,
        },
        JuMP.ConstraintRef{
            JuMP.GenericModel{Float64},
            MathOptInterface.ConstraintIndex{
                MathOptInterface.ScalarAffineFunction{Float64},
                MathOptInterface.LessThan{Float64},
            },
            JuMP.ScalarShape,
        },
        Base.Generator{
            JuMP.Containers.VectorizedProductIterator{Tuple{Base.OneTo{Int64}}},
            JuMP.Containers.var"#84#85"{
                IESopt.IESoptAddon_Example18.var"#1#2"{IESopt.Unit, Int64, JuMP.GenericModel{Float64}},
            },
        },
        Tuple{Tuple{Int64, Int64}},
    },
)
precompile(Tuple{typeof(Base._iterate), Base.Dict{String, Any}, Int64})
precompile(Tuple{typeof(Base.join), Array{String, 1}, String})
precompile(Tuple{typeof(Base.isempty), Base.Dict{String, Any}})
precompile(Tuple{typeof(Base.isempty), Array{Int64, 1}})
precompile(
    Tuple{
        typeof(Base.haskey),
        Base.Pairs{
            Symbol,
            Any,
            NTuple{4, Symbol},
            NamedTuple{(:mode, :enable_CH, :enable_DE, :enable_AT), Tuple{String, Bool, Bool, Bool}},
        },
        Symbol,
    },
)
precompile(Tuple{typeof(Base.haskey), Base.Dict{String, Bool}, String})
