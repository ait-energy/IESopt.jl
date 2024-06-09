module OptExtCPLEX

import IESopt, CPLEX, JuMP

function IESopt._setoptnow(model::JuMP.Model, ::Val{:CPLEX}, moa::Bool)
    if moa
        JuMP.set_optimizer(model, () -> IESopt.MOA.Optimizer(CPLEX.Optimizer))
    else
        JuMP.set_optimizer(model, CPLEX.Optimizer)
    end
    return nothing
end

end
