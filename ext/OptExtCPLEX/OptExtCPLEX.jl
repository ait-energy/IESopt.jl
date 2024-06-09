module OptExtCPLEX

import IESopt, CPLEX

struct OptType end

function IESopt._get_solver_module(::OptType)
    return CPLEX
end

end
