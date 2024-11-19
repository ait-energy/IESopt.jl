using IESopt
import JuMP
import HiGHS
import SDDP
import Random
using DataFrames, CSV

model = JuMP.read_from_file("subproblem_127.mof.json")
print(model)

# ======================================================================================================================
# [[ COMPLEX ]]
# ======================================================================================================================

Random.seed!(1234)
_cost = rand(8760 * 4) .* 100.0 .+ 250.0
_demand = max.(0.0, randn(8760 * 4) .* 2.0 .+ 8.5)
_inflow = max.(0.0, randn(8760 * 4) ./ 4.0 .+ 1.5)

df = DataFrame(; cost=_cost, demand=_demand, inflow=_inflow)
CSV.write("examples/files/40/data.csv", df)

####
model = JuMP.Model(HiGHS.Optimizer)
generate!(
    model,
    "examples/40_sddp_complex.iesopt.yaml";
    offset=0,
    count=8760 * 4,
    state_initial=0,
    parametric=true,
    build_cost1=500.0,
    build_cost2=5000.0,
)
JuMP.fix.(get_component(model, "inflow").var.aux_value, _inflow; force=true);
JuMP.fix.(get_component(model, "demand").var.aux_value, _demand; force=true);
true_cost = []
for t in 1:365
    append!(true_cost, [_cost[t * 24 * 4] for _ in 1:(24 * 4)])
end
objs = internal(model).model.objectives
JuMP.@objective(
    model,
    Min,
    sum(get_component(model, "thermal").var.aux_value[t] * true_cost[t] for t in 1:(8760 * 4)) +
    objs["build1_value"].func +
    objs["build2_value"].func
);
optimize!(model)    # 7.3446044558e+07  (15s)
extract_result(model, "build1", "value"; mode="value")  # 10
extract_result(model, "build2", "value"; mode="value")  # 100
####

sddp_model = SDDP.LinearPolicyGraph(; stages=365, sense=:Min, lower_bound=0.0, optimizer=HiGHS.Optimizer) do model, t
    JuMP.@variable(model, 0 <= x_storage, SDDP.State, initial_value = 0)
    JuMP.@variable(model, 0 <= x_storage_cap, SDDP.State, initial_value = 0)

    generate!(
        model,
        "examples/40_sddp_complex.iesopt.yaml";
        offset=(t - 1) * 24 * 4,
        count=24 * 4,
        state_initial="null",
        verbosity=false,
        parametric=true,
        build_cost1=500.0,
        build_cost2=5000.0,
    )

    JuMP.@constraint(model, x_storage.in <= x_storage_cap.in)
    JuMP.@constraint(model, x_storage.out <= x_storage_cap.in)
    # JuMP.@constraint(model, get_component(model, "reservoir").var.state[1] <= x_storage_cap.in)

    JuMP.@constraint(model, get_component(model, "reservoir").var.state[1] == x_storage.in)
    JuMP.@constraint(
        model,
        -JuMP.constraint_object(get_component(model, "reservoir").con.last_state_lb).func == x_storage.out
    )

    if t == 1
        JuMP.@constraint(
            model,
            x_storage_cap.out ==
            x_storage_cap.in + get_component(model, "build1").var.value + get_component(model, "build2").var.value
        )
    else
        JuMP.@constraint(model, x_storage_cap.out == x_storage_cap.in)
    end

    Ω = [1.0]
    P = [1.0]
    SDDP.parameterize(model, Ω, P) do ω
        return
    end

    JuMP.fix.(get_component(model, "inflow").var.aux_value, _inflow[((t - 1) * 24 * 4 + 1):(t * 24 * 4)]; force=true)
    JuMP.fix.(get_component(model, "demand").var.aux_value, _demand[((t - 1) * 24 * 4 + 1):(t * 24 * 4)]; force=true)
    objs = internal(model).model.objectives

    if t == 1
        SDDP.@stageobjective(
            model,
            objs["thermal"].func * _cost[t * 24 * 4] + objs["build1_value"].func + objs["build2_value"].func
        )
    else
        SDDP.@stageobjective(model, objs["thermal"].func * _cost[t * 24 * 4])
    end

    return
end

SDDP.train(sddp_model; iteration_limit=1, add_to_existing_cuts=true)
# 1 iteration, 7.344658e+07, 1.39s, 730 solves

simulations = SDDP.simulate(
    sddp_model,
    50,
    [:x_storage, :x_storage_cap];
    custom_recorders=Dict{Symbol, Function}(
        :build =>
            (model::JuMP.Model) ->
                JuMP.value(get_component(model, "build1").var.value) +
                JuMP.value(get_component(model, "build2").var.value),
        :thermal => (model::JuMP.Model) -> JuMP.value(get_component(model, "thermal").var.aux_value[1]),
    ),
)

sum(map(simulations[1]) do node
    return node[:build]
end)

plt = SDDP.SpaghettiPlot(simulations)
SDDP.add_spaghetti(plt; title="Reservoir volume", ylabel="MWh", interpolate="step") do data
    return data[:x_storage].out
end
SDDP.add_spaghetti(plt; title="Reservoir build", ylabel="MWh", interpolate="step") do data
    return data[:build]
end
SDDP.add_spaghetti(plt; title="Stage objective", ylabel="EUR") do data
    return data[:stage_objective]
end
SDDP.plot(plt, "spaghetti_plot_complex.html")

# ======================================================================================================================
# [[ PATHWAY ]]
# ======================================================================================================================

sddp_model = SDDP.LinearPolicyGraph(; stages=20, sense=:Min, lower_bound=0.0, optimizer=HiGHS.Optimizer) do model, t
    JuMP.@variable(model, 0 <= x_storage, SDDP.State, initial_value = 5)
    JuMP.@variable(model, 0 <= x_storage_cap, SDDP.State, initial_value = 10)

    generate!(
        model,
        "examples/39_sddp_path.iesopt.yaml";
        offset=(t - 1) * 10,
        count=10,
        state_initial="null",
        verbosity=false,
        parametric=true,
        build_cost1=1.0,
        build_cost2=1.0,
    )

    JuMP.@constraint(model, x_storage.in <= x_storage_cap.in)
    JuMP.@constraint(model, x_storage.out <= x_storage_cap.in)
    # JuMP.@constraint(model, get_component(model, "reservoir").var.state[1] <= x_storage_cap.in)

    JuMP.@constraint(model, get_component(model, "reservoir").var.state[1] == x_storage.in)
    JuMP.@constraint(
        model,
        -JuMP.constraint_object(get_component(model, "reservoir").con.last_state_lb).func == x_storage.out
    )

    JuMP.@constraint(
        model,
        x_storage_cap.out ==
        x_storage_cap.in + get_component(model, "build1").var.value + get_component(model, "build2").var.value
    )

    _z = 0
    if t == 20
        _z = JuMP.@variable(model, lower_bound = 0)
        JuMP.@constraint(model, x_storage.out + _z >= 5)
    end

    v = JuMP.fix_value(get_component(model, "inflow").var.aux_value[1])
    objs = internal(model).model.objectives

    Ω = [1.0]
    P = [1.0]
    SDDP.parameterize(model, Ω, P) do ω
        return
    end

    SDDP.@stageobjective(
        model,
        objs["thermal"].func + objs["build1_value"].func + 2 * objs["build2_value"].func + _z * 1e6
    )

    return
end

SDDP.train(sddp_model; iteration_limit=100)

simulations = SDDP.simulate(
    sddp_model,
    100,
    [:x_storage, :x_storage_cap];
    custom_recorders=Dict{Symbol, Function}(
        :build =>
            (model::JuMP.Model) ->
                JuMP.value(get_component(model, "build1").var.value) +
                JuMP.value(get_component(model, "build2").var.value),
        :thermal => (model::JuMP.Model) -> JuMP.value(get_component(model, "thermal").var.aux_value[1]),
    ),
)

plt = SDDP.SpaghettiPlot(simulations)
SDDP.add_spaghetti(plt; title="Reservoir size", ylabel="MWh", interpolate="step") do data
    return data[:x_storage_cap].out
end
SDDP.add_spaghetti(plt; title="Reservoir build", ylabel="MWh", interpolate="step") do data
    return data[:build]
end
SDDP.add_spaghetti(plt; title="Stage objective", ylabel="EUR", interpolate="step") do data
    return data[:stage_objective]
end
SDDP.plot(plt, "spaghetti_plot_pathway.html")

# ======================================================================================================================
# [[ STOCHASTIC PATHWAY ]]
# ======================================================================================================================

sddp_model = SDDP.LinearPolicyGraph(; stages=20, sense=:Min, lower_bound=0.0, optimizer=HiGHS.Optimizer) do model, t
    JuMP.@variable(model, 0 <= x_storage, SDDP.State, initial_value = 5)
    JuMP.@variable(model, 0 <= x_storage_cap, SDDP.State, initial_value = 10)

    generate!(
        model,
        "examples/39_sddp_path.iesopt.yaml";
        offset=(t - 1) * 10,
        count=10,
        state_initial="null",
        verbosity=false,
        parametric=true,
        build_cost1=1.0,
        build_cost2=1.0,
    )

    JuMP.@constraint(model, x_storage.in <= x_storage_cap.in)
    JuMP.@constraint(model, x_storage.out <= x_storage_cap.in)
    # JuMP.@constraint(model, get_component(model, "reservoir").var.state[1] <= x_storage_cap.in)

    JuMP.@constraint(model, get_component(model, "reservoir").var.state[1] == x_storage.in)
    JuMP.@constraint(
        model,
        -JuMP.constraint_object(get_component(model, "reservoir").con.last_state_lb).func == x_storage.out
    )

    JuMP.@constraint(
        model,
        x_storage_cap.out ==
        x_storage_cap.in + get_component(model, "build1").var.value + get_component(model, "build2").var.value
    )

    _z = 0
    if t == 20
        _z = JuMP.@variable(model, lower_bound = 0)
        JuMP.@constraint(model, x_storage.out + _z >= 5)
    end

    v = JuMP.fix_value(get_component(model, "inflow").var.aux_value[1])
    objs = internal(model).model.objectives

    lower = -convert(Int64, floor(t / 5.0 * 2500))
    upper = -0.5 * lower

    Ω = [(capex=i,) for i in lower:10:upper]
    P = [1.0 / length(Ω) for i in 1:length(Ω)]

    SDDP.parameterize(model, Ω, P) do ω
        # JuMP.fix(get_component(model, "inflow").var.aux_value[1], max(0., v + ω.inflow); force=true)
        # SDDP.@stageobjective(model, objs["thermal"].func + _z * 1e4)
        SDDP.@stageobjective(
            model,
            objs["thermal"].func +
            max(5, (t / 5.0 * 2500 + ω.capex) / 20) * (objs["build1_value"].func + 2 * objs["build2_value"].func) +
            _z * 1e6
        )
        return
    end

    return
end

SDDP.train(sddp_model; iteration_limit=500)

simulations = SDDP.simulate(
    sddp_model,
    500,
    [:x_storage, :x_storage_cap];
    custom_recorders=Dict{Symbol, Function}(
        :build =>
            (model::JuMP.Model) ->
                JuMP.value(get_component(model, "build1").var.value) +
                JuMP.value(get_component(model, "build2").var.value),
        :thermal => (model::JuMP.Model) -> JuMP.value(get_component(model, "thermal").var.aux_value[1]),
    ),
)

plt = SDDP.SpaghettiPlot(simulations)
SDDP.add_spaghetti(plt; title="Reservoir size", ylabel="MWh") do data
    return data[:x_storage_cap].out
end
SDDP.add_spaghetti(plt; title="Reservoir build", ylabel="MWh", interpolate="step") do data
    return data[:build]
end
SDDP.add_spaghetti(plt; title="Stage objective", ylabel="EUR") do data
    return data[:stage_objective]
end
SDDP.plot(plt, "spaghetti_plot_stochpathway.html")

# ======================================================================================================================
# [[ STOCHASTIC OPERATIONAL OPTIMIZATION ]]
# ======================================================================================================================

sddp_model = SDDP.LinearPolicyGraph(; stages=52, sense=:Min, lower_bound=0.0, optimizer=HiGHS.Optimizer) do model, t
    JuMP.@variable(model, 0 <= x_storage <= 320, SDDP.State, initial_value = 300)
    generate!(
        model,
        "examples/38_sddp_operational.iesopt.yaml";
        offset=(t - 1),
        count=1,
        state_initial="null",
        verbosity=false,
        parametric=true,
    )

    JuMP.@constraint(model, get_component(model, "reservoir").var.state[1] == x_storage.in)
    JuMP.@constraint(
        model,
        -JuMP.constraint_object(get_component(model, "reservoir").con.last_state_lb).func == x_storage.out
    )

    _z = 0
    if t == 52
        _z = JuMP.@variable(model, lower_bound = 0)
        JuMP.@constraint(model, x_storage.out + _z >= 300)
    end

    v = JuMP.fix_value(get_component(model, "inflow").var.aux_value[1])
    objs = internal(model).model.objectives

    Ω = [
        (
            inflow=round((rand() * 2.0 - 1.0) + ((rand() <= 0.02) * 20); digits=2),
            fuel_multiplier=round(1.0 + rand() * 0.25; digits=2),
        ) for _ in 1:15
    ]
    P = rand(15)
    P /= sum(P)

    SDDP.parameterize(model, Ω, P) do ω
        JuMP.fix(get_component(model, "inflow").var.aux_value[1], max(0.0, v + ω.inflow); force=true)
        SDDP.@stageobjective(model, ω.fuel_multiplier * objs["thermal"].func + _z * 1e4)
        return
    end

    return
end

Ω = [
    (add_inflow_value=0.01, mult_thermal_cost=1.18),
    (add_inflow_value=-0.05, mult_thermal_cost=1.14),
    (add_inflow_value=0.43, mult_thermal_cost=1.07),
    (add_inflow_value=-0.10, mult_thermal_cost=1.06),
    (add_inflow_value=0.00, mult_thermal_cost=1.20),
    (add_inflow_value=0.49, mult_thermal_cost=1.23),
    (add_inflow_value=0.94, mult_thermal_cost=1.16),
    (add_inflow_value=-0.22, mult_thermal_cost=1.18),
    (add_inflow_value=0.00, mult_thermal_cost=1.00),
    (add_inflow_value=0.42, mult_thermal_cost=1.08),
    (add_inflow_value=-1.00, mult_thermal_cost=1.23),
    (add_inflow_value=-0.41, mult_thermal_cost=1.18),
    (add_inflow_value=0.06, mult_thermal_cost=1.14),
    (add_inflow_value=-0.17, mult_thermal_cost=1.13),
    (add_inflow_value=-0.93, mult_thermal_cost=1.05),
]

P = [0.023, 0.143, 0.020, 0.053, 0.015, 0.013, 0.075, 0.105, 0.083, 0.067, 0.008, 0.072, 0.080, 0.141, 0.102]

SDDP.parameterize(model, Ω, P) do ω
    set_parameter("inflow", "value", inflow_value + add_inflow_value)
    SDDP.@stageobjective(model, ω.mult_thermal_cost * objs["thermal"].func)
end

SDDP.train(sddp_model; iteration_limit=500)

# - distribution for cost factors (capex / opex)
# - changing cost factors (capex / opex) over time (E changing)
# - distributional noise on time series (profile cost / values)

# stoch. betriebsoptimierung    : CHECK
# pathway optimization
# stoch. pathway optimization

simulations = SDDP.simulate(
    sddp_model,
    50,
    [:x_storage];
    custom_recorders=Dict{Symbol, Function}(
        :thermal => (model::JuMP.Model) -> JuMP.value(get_component(model, "thermal").var.aux_value[1]),
        :spillage => (model::JuMP.Model) -> JuMP.value(get_component(model, "spill").var.aux_value[1]),
    ),
)

plt = SDDP.SpaghettiPlot(simulations)
SDDP.add_spaghetti(plt; title="Reservoir volume", ylabel="MWh", interpolate="step") do data
    return data[:x_storage].out
end
SDDP.add_spaghetti(plt; title="Thermal generation", ylabel="MWh", interpolate="step") do data
    return data[:thermal]
end
SDDP.add_spaghetti(plt; title="Spillage", ylabel="MWh", interpolate="step") do data
    return data[:spillage]
end
SDDP.add_spaghetti(plt; title="Stage objective", ylabel="EUR", interpolate="step") do data
    return data[:stage_objective]
end
SDDP.plot(plt, "spaghetti_plot_stochopt.html")
