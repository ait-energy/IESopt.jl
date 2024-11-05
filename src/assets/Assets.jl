module Assets

using RelocatableFolders

"""
    get_path(asset_type::String)

Get the path to the asset type folder. Currently supports: "addons", "examples", "templates".

# Arguments
- `asset_type::String`: The asset type.

# Returns
- `RelocatableFolders.Path`: The path to the asset folder, already using `normpath`. `Path` implements an automatic conversion to `String`.

# Example
```julia
Assets.get_path("templates")
```
"""
function get_path(asset_type::String)
    return (@path normpath(@__DIR__, asset_type))::RelocatableFolders.Path
end

"""
    get_path(asset_type::String, asset_name::String)

Get the path to the asset file, specified by the asset type and asset name. Currently supports the following types:
"addons", "examples", "templates".

# Arguments
- `asset_type::String`: The asset type.
- `asset_name::String`: The asset name.

# Returns
- `RelocatableFolders.Path`: The path to the asset file, already using `normpath`. `Path` implements an automatic conversion to `String`.

# Example
```julia
Assets.get_path("examples", "08_basic_investment.iesopt.yaml")
```
"""
function get_path(asset_type::String, asset_name::String)
    return (@path normpath(get_path(asset_type), asset_name))::RelocatableFolders.Path
end

end # module
