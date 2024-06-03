function _validate_snapshots(carriers::Dict)
    valid = true

    try
        # TODO
    catch exception
        valid &= _vassert(false, "An unexpected exception occured"; location="snapshots")
    end

    return valid
end
