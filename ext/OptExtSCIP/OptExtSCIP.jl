module OptExtSCIP

import IESopt, SCIP, JuMP

function IESopt._setoptnow(model::JuMP.Model, ::Val{:SCIP}, moa::Bool)
    if moa
        JuMP.set_optimizer(model, () -> IESopt.MOA.Optimizer(SCIP.Optimizer))
    else
        JuMP.set_optimizer(model, SCIP.Optimizer)
    end
    return nothing
end


end
