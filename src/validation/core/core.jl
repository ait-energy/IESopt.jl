include("carrier.jl")
include("connection.jl")
include("decision.jl")
include("node.jl")
include("profile.jl")
include("snapshot.jl")
include("template.jl")
include("unit.jl")

function _validate_component(name::Any, properties::Dict)
    valid = true

    valid &= _vassert(name isa String, "Component name must be a string"; component=name)

    type = get(properties, "type", "")

    if type == ""
        valid &= _vassert(false, "Component is missing `type`"; component=name)
    elseif type == "Connection"
        valid &= _validate_connection(name, properties)
    elseif type == "Decision"
        valid &= _validate_decision(name, properties)
    elseif type == "Node"
        valid &= _validate_node(name, properties)
    elseif type == "Profile"
        valid &= _validate_profile(name, properties)
    elseif type == "Unit"
        valid &= _validate_unit(name, properties)
    else
        valid &= _validate_template_component(name, properties)
    end

    return valid
end
