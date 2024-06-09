module OptExtCbc

import IESopt, Cbc, JuMP

function IESopt._setoptnow(model::JuMP.Model, ::Val{:Cbc}, moa::Bool)
    if moa
        JuMP.set_optimizer(model, () -> IESopt.MOA.Optimizer(Cbc.Optimizer))
    else
        JuMP.set_optimizer(model, Cbc.Optimizer)
    end
    return nothing
end

end
