function _validate_connection(name::String, properties::Dict)
    valid = true

    try
        # TODO
    catch exception
        valid &= _vassert(false, "An unexpected exception occured"; location="Connection", name=name)
    end

    return valid
end
