function _validate_connection(name::String, properties::Dict)
    valid = true

    try
        # TODO
    catch exception
        valid &= _vassert(false, "An unexpected exception occurred"; location="Connection", name=name)
    end

    return valid
end
