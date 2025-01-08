using PrecompileTools: @setup_workload, @compile_workload, @recompile_invalidations

# See: https://discourse.julialang.org/t/base-docs-doc-failing-with-1-11-0/121187
# This is a workaround for an issue introduced by Julia 1.11.0, and seems to now be necessary to use `Base.Docs`
# import REPL

using TestItems

# Load the assets module.
include("utils/modules/Assets.jl")

# Setup `HiGHS.jl`, since this is the default solver that users may want to use.
import HiGHS

# Currently we have a proper automatic resolver for the following solver interfaces:
const _ALL_SOLVER_INTERFACES = ["HiGHS", "Gurobi", "Cbc", "GLPK", "CPLEX", "Ipopt", "SCIP"]

# Required for logging, validation, and suppressing unwanted output.
using Logging
import LoggingExtras
using Suppressor
import ArgCheck

# Used to "hotload" code (e.g., addons, Core Templates).
using RuntimeGeneratedFunctions

# Used to parse expressions from strings, and to trick with precompiling indirect dependencies.
import JuliaSyntax
import MacroTools
import RelocatableFolders

# Required during the "build" step, showing progress.
using ProgressMeter

using OrderedCollections

# Required to generate dynamic docs of Core Components.
# import Base.Docs
import Markdown

# Everything JuMP / optimization related.
import JuMP, JuMP.@variable, JuMP.@expression, JuMP.@constraint, JuMP.@objective
import MultiObjectiveAlgorithms as MOA

"""
MathOptInterface.jl
"""
const MOI = JuMP.MOI

# File (and filesystem/git) and data format handling.
import YAML
import JSON
import CSV
import DataFrames
import ZipFile
import SHA

# Used in Benders/Stochastic.
import Printf
import Dates

@testitem "assets" tags = [:unittest] begin
    ex_cfg_file = "01_basic_single_node.iesopt.yaml"

    @test Assets.get_path("templates") isa Assets.RelocatableFolders.Path
    @test Assets.get_path("examples", ex_cfg_file) isa Assets.RelocatableFolders.Path

    @test isdir(Assets.get_path("addons"))
    @test isdir(Assets.get_path("examples"))
    @test isdir(Assets.get_path("templates"))

    @test isfile(Assets.get_path("examples", ex_cfg_file))
end
