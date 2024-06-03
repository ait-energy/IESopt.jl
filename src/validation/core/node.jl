function _validate_node(name::String, properties::Dict)
    valid = true

    try
        # TODO
    catch exception
        valid &= _vassert(false, "An unexpected exception occured"; location="Node", name=name)
    end

    return valid
end
