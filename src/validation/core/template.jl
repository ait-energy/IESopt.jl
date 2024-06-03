function _validate_template_component(name::String, properties::Dict)
    valid = true

    try
        # TODO
    catch exception
        valid &= _vassert(false, "An unexpected exception occured"; location=properties["type"], name=name)
    end

    return valid
end
