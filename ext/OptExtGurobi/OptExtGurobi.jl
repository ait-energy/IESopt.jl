module OptExtGurobi

import IESopt, Gurobi

struct OptType end

function IESopt._get_solver_module(::OptType)
    return Gurobi
end

end
