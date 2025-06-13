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

@testset "#95" begin
    DataFrames = IESopt.DataFrames
    CSV = IESopt.CSV
    JuMP = IESopt.JuMP

    data = normpath(Assets.get_path("examples"), "files", "example_data.csv")
    cfg = String(Assets.get_path("examples", "07_csv_filestorage.iesopt.yaml"))

    df = CSV.read(data, DataFrames.DataFrame; stringtype=String)
    df_mod = copy(df)
    df_mod[!, "ex07_plant_wind_availability_factor"] .= 0

    @test JuMP.objective_value(IESopt.run(cfg; virtual_files=Dict("data" => df_mod))) ≈ 7.69679225e6 atol = 0.1

    config = Dict("optimization.snapshots.count" => 168)
    obj = JuMP.objective_value(IESopt.run(cfg; config))
    @test JuMP.objective_value(IESopt.run(cfg; virtual_files=Dict("data" => df), config)) ≈ obj atol = 0.1

    config = Dict("optimization.snapshots.count" => 168, "optimization.snapshots.offset" => 168)
    obj = JuMP.objective_value(IESopt.run(cfg; config))
    @test JuMP.objective_value(IESopt.run(cfg; virtual_files=Dict("data" => df), config)) ≈ obj atol = 0.1
end
