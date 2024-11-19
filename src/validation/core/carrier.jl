function _validate_carriers(carriers::Dict)
    valid = true

    try
        # TODO
    catch exception
        valid &= _vassert(false, "An unexpected exception occurred"; location="carriers")
    end

    return valid
end
