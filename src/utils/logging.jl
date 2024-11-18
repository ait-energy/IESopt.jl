struct _FileLogger <: AbstractLogger
    logger::Logging.SimpleLogger
end

function _FileLogger(path::String)
    return _FileLogger(Logging.SimpleLogger(open(path, "w")))
end

function Logging.handle_message(filelogger::_FileLogger, args...; kwargs...)
    Logging.handle_message(filelogger.logger, args...; kwargs...)
    return flush(filelogger.logger.stream)
end
Logging.shouldlog(filelogger::_FileLogger, arg...) = true
Logging.min_enabled_level(filelogger::_FileLogger) = Logging.Info
Logging.catch_exceptions(filelogger::_FileLogger) = Logging.catch_exceptions(filelogger.logger)

"""
    safe_close_filelogger(model::JuMP.Model)

Safely closes the file logger's iostream if it is open. This function checks if the logger associated with the given `model` is a `LoggingExtras.TeeLogger` and if it contains a `IESopt._FileLogger` as one of its loggers. If the file logger's stream is open, it will be closed.

# Arguments
- `model::JuMP.Model`: The IESopt model which contains the logger to be closed.

# Returns
- `nothing`: This function does not return any value.

# Notes
- The function includes a `try-catch` block to handle any potential errors during the closing process. Currently, the catch block does not perform any actions.
"""
function safe_close_filelogger(model::JuMP.Model)
    try
        if internal(model).logger isa LoggingExtras.TeeLogger
            tl = internal(model).logger
            if length(tl.loggers) == 2
                if tl.loggers[2] isa IESopt._FileLogger
                    if isopen(tl.loggers[2].logger.stream)
                        @info "Safely closing the file logger's iostream"
                        close(tl.loggers[2].logger.stream)
                    end
                end
            end
        end
    catch
        # TODO: maybe we can do something here?
    end

    return nothing
end

function _attach_logger!(model::JuMP.Model)
    verbosity = @config(model, general.verbosity.core, String)
    sym_verbosity = Symbol(uppercasefirst(verbosity))
    logger = Logging.ConsoleLogger(getfield(Logging, sym_verbosity); meta_formatter=_new_metafmt)

    if @config(model, general.performance.logfile, Bool)
        scenario_name = @config(model, general.name.scenario, String)
        log_file = "$(scenario_name).iesopt.log"
        log_path = normpath(mkpath(@config(model, paths.results)), log_file)
        try
            internal(model).logger = LoggingExtras.TeeLogger(logger, _FileLogger(log_path))
        catch
            @error (
                "Could not create file logger, falling back to console logger only; if this happened after a " *
                "previous model run, consider calling `safe_close_filelogger(model)` after you are done with your " *
                "previous model - before re-generating a new one - to properly release the log file handle"
            )
            internal(model).logger = logger
        end
    else
        internal(model).logger = logger
    end

    return internal(model).logger::Union{Logging.ConsoleLogger, LoggingExtras.TeeLogger}
end

# Based on `default_metafmt` from ConsoleLogger.jl
function _new_metafmt(level::LogLevel, _module, group, id, file, line)
    @nospecialize
    PAD = 25

    level_str = lowercase(level == Warn ? "Warning" : string(level))
    abspath_core = abspath(dirname(dirname(dirname(@__FILE__))))
    abspath_file = abspath(file)

    if startswith(abspath_file, abspath_core)
        file = relpath(abspath_file, abspath_core)
        depth = splitpath(file)

        if depth[1] == "src"
            depth_prefix = replace(join(depth[2:end], "|"), ".jl" => "")
        elseif depth[1] == "addons"
            depth_prefix = "addon ($(replace(depth[end], ".jl" => "")))"
        else
            depth_prefix = "? ($(replace(depth[end], ".jl" => "")))"
        end
    else
        depth = splitpath(file)
        depth_prefix = "custom ($(replace(depth[end], ".jl" => "")))"
    end

    max_depth_prefix_length = PAD - length(level_str) - length(" @ ") - length(" ~")
    if length(depth_prefix) > max_depth_prefix_length
        depth_prefix = depth_prefix[1:(max_depth_prefix_length - 3)] * "..."
    end

    color = Logging.default_logcolor(level)
    prefix = rpad("$(level_str) @ $(depth_prefix) ~", PAD)
    suffix::String = ""

    Info <= level < Warn && return color, prefix, suffix

    _module !== nothing && (suffix *= string(_module)::String)
    if file !== nothing
        _module !== nothing && (suffix *= " ")
        suffix *= contractuser(file)::String
        if line !== nothing
            suffix *= ":$(isa(line, UnitRange) ? "$(first(line))-$(last(line))" : line)"
        end
    end
    !isempty(suffix) && (suffix = "@ " * suffix)

    return color, prefix, suffix
end
