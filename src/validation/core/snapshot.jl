function _validate_snapshots(carriers::Dict)
    valid = true

    try
        # TODO
    catch exception
        valid &= _vassert(false, "An unexpected exception occurred"; location="snapshots")
    end

    return valid
end
