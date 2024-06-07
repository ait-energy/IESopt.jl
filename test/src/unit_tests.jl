@testset "Utils" begin
    @test IESopt._is_valid_template_name("") == false
    @test IESopt._is_valid_template_name("fooBar") == false
    @test IESopt._is_valid_template_name("foobar") == false
    @test IESopt._is_valid_template_name("Foo_Bar") == false
    @test IESopt._is_valid_template_name("Foo-Bar") == false
    @test IESopt._is_valid_template_name("FooBar-") == false
    @test IESopt._is_valid_template_name("FooBar1") == false
    @test IESopt._is_valid_template_name("F") == false
    @test IESopt._is_valid_template_name("FooBar") == true
    @test IESopt._is_valid_template_name("Foobar") == true

    @test IESopt._is_valid_component_name("") == false
    @test IESopt._is_valid_component_name("1foobar") == false
    @test IESopt._is_valid_component_name("_foobar") == false
    @test IESopt._is_valid_component_name("foobar_") == false
    @test IESopt._is_valid_component_name("foo-bar") == false
    @test IESopt._is_valid_component_name("foobar.") == false
    @test IESopt._is_valid_component_name("fooBar") == false
    @test IESopt._is_valid_component_name("f") == false
    @test IESopt._is_valid_component_name("foo_Bar") == false
    @test IESopt._is_valid_component_name("f1") == true
    @test IESopt._is_valid_component_name("foo_bar") == true
    @test IESopt._is_valid_component_name("foo") == true
    @test IESopt._is_valid_component_name("fb") == true
end
