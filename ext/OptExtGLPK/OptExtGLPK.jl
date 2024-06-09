module OptExtGLPK

import IESopt, GLPK

struct OptType end

function IESopt._get_solver_module(::OptType)
    return GLPK
end

end
