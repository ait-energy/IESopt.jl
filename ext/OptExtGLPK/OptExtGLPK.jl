module OptExtGLPK

import IESopt, GLPK, JuMP

function IESopt._setoptnow(model::JuMP.Model, ::Val{:GLPK}, moa::Bool)
    if moa
        JuMP.set_optimizer(model, () -> IESopt.MOA.Optimizer(GLPK.Optimizer))
    else
        JuMP.set_optimizer(model, GLPK.Optimizer)
    end
    return nothing
end

end
