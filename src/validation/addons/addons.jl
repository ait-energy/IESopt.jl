function _validate_addon(filename::String)
    valid = true

    content = ""
    try
        # TODO: Load the addon file
    catch
        return _vassert(false, "Could not load addon file"; filename=filename)
    end

    try
        # TODO
    catch exception
        valid &= _vassert(false, "An unexpected exception occurred"; filename=filename, exception=exception)
    end

    return valid
end
