function _validate_carriers(carriers::Dict)
    valid = true

    try
        # TODO
    catch exception
        valid &= _vassert(false, "An unexpected exception occured"; location="carriers")
    end

    return valid
end
