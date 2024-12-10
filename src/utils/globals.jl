@kwdef mutable struct _GlobalSettings
    parameters::Dict{String, Any} = Dict{String, Any}()
    config::Dict{String, Any} = Dict{String, Any}()
    addons::Dict{String, Any} = Dict{String, Any}()
    carriers::Dict{String, Any} = Dict{String, Any}()
    components::Dict{String, Any} = Dict{String, Any}()
    load_components::Dict{String, Any} = Dict{String, Any}()
    skip_validation::Bool = false
end

const _global_settings = _GlobalSettings()

"""
    set_global!(type::String, key::String, @nospecialize(value))

Set a global setting for IESopt. These will be used as defaults for every subsequent function call (that supports
these). User passed settings will override these defaults.

# Arguments
- `type::String`: The type of global setting. Currently supports: "parameters", "config", "addons", "carriers", "components", "load_components".
- `key::String`: The key of the global setting.
- `value`: The value of the global setting.

# Example
```julia
set_global!("config", "general.verbosity.core", "error")
```
"""
function set_global!(type::String, key::String, value)
    @nospecialize

    sym_type = Symbol(type)
    if !hasproperty(_global_settings, sym_type)
        error("Invalid type for IESopt's global settings: `$type`")
    end

    getproperty(_global_settings, sym_type)[key] = value

    return nothing
end

"""
    set_global!(type::String, value::Bool)

Set a global setting for IESopt. These will be used as defaults for every subsequent function call (that supports
these). User passed settings will override these defaults.

# Arguments
- `type::String`: The type of global setting. Currently supports: "skip_validation".
- `value::Bool`: The value of the global setting.

# Example
```julia
set_global!("skip_validation", true)
```
"""
function set_global!(type::String, value::Bool)
    sym_type = Symbol(type)
    if !hasproperty(_global_settings, sym_type)
        error("Invalid type for IESopt's global settings: `$type`")
    end

    setproperty!(_global_settings, sym_type, value)

    return nothing
end

function get_global(type::String)
    sym_type = Symbol(type)
    if !hasproperty(_global_settings, sym_type)
        error("Invalid type for IESopt's global settings: `$type`")
    end

    return getproperty(_global_settings, sym_type)
end

@testitem "globals" tags = [:general] begin
    @test IESopt.get_global("skip_validation") == false
    IESopt.set_global!("skip_validation", true)
    @test IESopt.get_global("skip_validation") === true
    IESopt.set_global!("skip_validation", false)
    @test IESopt.get_global("skip_validation") === false

    @test isempty(IESopt.get_global("config"))
    IESopt.set_global!("config", "general.verbosity.core", "info")
    @test IESopt.get_global("config")["general.verbosity.core"] === "info"
    delete!(IESopt.get_global("config"), "general.verbosity.core")
    @test haskey(IESopt.get_global("config"), "general.verbosity.core") === false
end
