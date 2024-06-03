include("variables.jl")
include("constraints.jl")
include("print.jl")

# todo: this currently cannot handle multi-dimensional var
# todo: this currently can not handle variables where some timesteps are fixed (e.g. due to initial conditions; add this)

import Tectonic

function texify(model; filename::String, component::String="")
    prefix = component

    tex = ""
    tex *= "\\documentclass[8pt,fleqn]{extarticle}\n"
    tex *= "\\usepackage[a4paper, margin=1in]{geometry}\n\n"
    tex *= "\\usepackage{physics,amsmath,breqn}\n\\usepackage[theorems]{tcolorbox}\n\n"
    tex *= "\\setlength\\parindent{0pt}\n\n\\newtcolorbox{constrbox}[1][]{colback=white, #1}\n\n"
    tex *= "\\begin{document}\n\n"
    if prefix == ""
        tex *= "This is a full model summary.\\\\~\\\\\n\n"
    else
        tex *= "This is a model summary of \\textbf{$prefix}.\\\\~\\\\\n\n"
    end
    tex *= "\\tableofcontents\n\n"

    tex *= "%\n%\n%\n"
    tex *= "\\clearpage \\section{Objective function}\n\n" * _obj_tostring(model)

    # todo: this is type-unstable, see JuMP documentation, which means we could optimize this
    constraints = [
        constraint for constraint in JuMP.all_constraints(model; include_variable_in_set_constraints=false) if
        startswith(JuMP.name(constraint), prefix)
    ]

    # Sort components by name.
    components = _iesopt(model).model.components
    sorted_comp_names = sort(keys(components))

    # Prepare all variables.
    variable_list = _describe_variables(model; prefix=prefix)

    for cname in sorted_comp_names
        component = components[cname]
        escaped_comp_name = replace(cname, "_" => "\\_")

        tex *= "%\n%\n%\n"
        tex *= "\\clearpage \\section{Sub-component: \\textbf{$escaped_comp_name}}\n\n"
        tex *= "\\subsection{Variables}\n"
        tex *= _vars_tostring(variable_list, cname)
        tex *= "\n\n"
        tex *= "\\subsection{Constraints}\n"

        groups = _group_constraints([c for c in constraints if startswith(JuMP.name(c), cname)])
        descr = Dict{Symbol, Vector}()
        for (group, val) in groups
            constr = _parse_base_name(group)[2]
            if !haskey(descr, constr)
                descr[constr] = []
            end
            push!(descr[constr], val)
        end
        sorted_descr_keys = sort([it for it in keys(descr)])

        for k in sorted_descr_keys
            for g in descr[k]
                escaped_constraint_name = replace(String(k), "_" => "\\_")

                if length(g.constraints) == 1
                    if isnothing(g.indices[1])
                        tex *= "\\textit{$escaped_constraint_name}\n"
                    else
                        tex *= "\\textit{$escaped_constraint_name} | \$t = $(g.indices[1])\$\n"
                    end
                    tex *= _constr_group_equal_tostring(g; fixed_t=true)
                    tex *= "\n\n"
                else
                    tex *= "\\textit{$escaped_constraint_name} | \$\\forall t \\in \\{$(g.indices[1]),\\dots,$(g.indices[end])\\}\$\n"
                    tex *= _constr_group_tostring(g)
                    tex *= "\n\n"
                end

                tex *= "\\vspace{2em}"
            end
        end
    end

    tex *= "\n\n\\end{document}"

    folder = dirname(filename)
    tempname = joinpath(folder, "_tmp_texify")

    open("$(tempname).tex", "w") do file
        return write(file, tex)
    end
    Tectonic.tectonic() do bin
        Tectonic.run(`$bin $(tempname).tex --chatter minimal`)
        return mv("$(tempname).pdf", filename; force=true)
    end
end
