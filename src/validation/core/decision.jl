function _validate_decision(name::String, properties::Dict)
    valid = true

    try
        # TODO
    catch exception
        valid &= _vassert(false, "An unexpected exception occurred"; location="Decision", name=name)
    end

    return valid
end
