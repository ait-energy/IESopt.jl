@testset "#35" begin
    model = generate!(joinpath(PATH_TESTFILES, "issues", "35", "config.iesopt.yaml"))
    @test access(get_component(model, "electricity_demand").value) ≈ 7e-6
end

@testset "#38" begin
    model = generate!(joinpath(PATH_TESTFILES, "issues", "38", "config.iesopt.yaml"))
    supplier = get_component(model, "electricity_supply")
    demand_ub = access(supplier.supply.ub)

    @test demand_ub.terms[supplier.size.var.value] ≈ 2.0
    @test demand_ub.constant ≈ 3.0

    optimize!(model)
    @test JuMP.objective_value(model) ≈ 0.0 atol = 0.1
end
