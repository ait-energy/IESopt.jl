module OptExtCbc

import IESopt, Cbc

struct OptType end

function IESopt._get_solver_module(::OptType)
    return Cbc
end

end
