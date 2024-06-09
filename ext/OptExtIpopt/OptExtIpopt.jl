module OptExtIpopt

import IESopt, Ipopt

struct OptType end

function IESopt._get_solver_module(::OptType)
    return Ipopt
end

end
