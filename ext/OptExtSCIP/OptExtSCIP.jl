module OptExtSCIP

import IESopt, SCIP

struct OptType end

function IESopt._get_solver_module(::OptType)
    return SCIP
end

end
