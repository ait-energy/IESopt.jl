module OptExtGurobi

import IESopt, Gurobi, JuMP

function IESopt._setoptnow(model::JuMP.Model, ::Val{:Gurobi}, moa::Bool)
    if moa
        JuMP.set_optimizer(model, () -> IESopt.MOA.Optimizer(Gurobi.Optimizer))
    else
        JuMP.set_optimizer(model, Gurobi.Optimizer)
    end
    return nothing
end

end
