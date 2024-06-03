function _validate_unit(name::String, properties::Dict)
    valid = true

    try
        # TODO
    catch exception
        valid &= _vassert(false, "An unexpected exception occured"; location="Unit", name=name)
    end

    return valid
end
