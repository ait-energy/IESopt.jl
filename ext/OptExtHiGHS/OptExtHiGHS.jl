module OptExtHiGHS

import IESopt, HiGHS

struct OptType end

function IESopt._get_solver_module(::OptType)
    return HiGHS
end

end
