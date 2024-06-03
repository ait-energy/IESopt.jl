@testset "Method ambiguity" begin
    Aqua.test_ambiguities(IESopt)
end

@testset "Persistent tasks" begin
    # Aqua.test_persistent_tasks(IESopt)
end

@testset "All" verbose = true begin
    Aqua.test_all(IESopt; ambiguities=false, persistent_tasks=false)
end
