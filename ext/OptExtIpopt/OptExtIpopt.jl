module OptExtIpopt

import IESopt, Ipopt, JuMP

function IESopt._setoptnow(model::JuMP.Model, ::Val{:Ipopt}, moa::Bool)
    if moa
        JuMP.set_optimizer(model, () -> IESopt.MOA.Optimizer(Ipopt.Optimizer))
    else
        JuMP.set_optimizer(model, Ipopt.Optimizer)
    end
    return nothing
end

end
