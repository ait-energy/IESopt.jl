struct FileLogger <: AbstractLogger
    logger::Logging.SimpleLogger
end

function FileLogger(path::String)
    return FileLogger(Logging.SimpleLogger(open(path, "w")))
end

function Logging.handle_message(filelogger::FileLogger, args...; kwargs...)
    Logging.handle_message(filelogger.logger, args...; kwargs...)
    return flush(filelogger.logger.stream)
end
Logging.shouldlog(filelogger::FileLogger, arg...) = true
Logging.min_enabled_level(filelogger::FileLogger) = Logging.Info
Logging.catch_exceptions(filelogger::FileLogger) = Logging.catch_exceptions(filelogger.logger)

function save_close_filelogger(model::JuMP.Model)
    try
        if _iesopt(model).logger isa LoggingExtras.TeeLogger
            tl = _iesopt(model).logger
            if length(tl.loggers) == 2
                if tl.loggers[2] isa IESopt.FileLogger
                    if isopen(tl.loggers[2].logger.stream)
                        @info "Savely closing the file logger's iostream"
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
    verbosity = _iesopt_config(model).verbosity

    logger = (
        if verbosity == "warning"
            Logging.ConsoleLogger(Logging.Warn; meta_formatter=_new_metafmt)
        elseif verbosity == true
            Logging.ConsoleLogger(Logging.Info; meta_formatter=_new_metafmt)
        elseif verbosity == false
            Logging.ConsoleLogger(Logging.Error; meta_formatter=_new_metafmt)
        else
            @warn "Unsupported `verbosity` config. Choose from `true`, `false` or `warning`. Falling back to `true`." verbosity =
                verbosity
            Logging.ConsoleLogger(Logging.Info; meta_formatter=_new_metafmt)
        end
    )

    if _iesopt_config(model).optimization.high_performance
        _iesopt(model).logger = logger
    else
        log_file = "$(_iesopt_config(model).names.scenario).log"
        log_path = normpath(mkpath(_iesopt_config(model).paths.results), log_file)
        if isfile(log_path)
            @error "Log file already exists, and we do not know whether the file"
        end
        _iesopt(model).logger = LoggingExtras.TeeLogger(logger, FileLogger(log_path))
    end
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
