module ResultsDuckDB

import ..IESopt

import JuMP
import DuckDB
import DataFrames

abstract type AbstractAttribute end

struct AttrExtractObjectives <: AbstractAttribute end
struct AttrExtractResults <: AbstractAttribute end
struct AttrExtractMeta <: AbstractAttribute end

function append_component_info!(appender::DuckDB.Appender, cid::Int64, rtid::Int64, rid::Int64, sid::Int64, vt::Int64)
    DuckDB.append(appender, cid)
    DuckDB.append(appender, rtid)
    DuckDB.append(appender, rid)
    DuckDB.append(appender, sid)
    DuckDB.append(appender, vt)

    return nothing
end

function append_component_result!(
    appender::DuckDB.Appender,
    cid::Int64,
    rtid::Int64,
    rid::Int64,
    entry::JuMP.VariableRef;
    has_duals::Bool,
    sid::Int64=-1,
)
    append_component_info!(appender, cid, rtid, rid, sid, 1)
    DuckDB.append(appender, JuMP.value(entry)::Float64)
    DuckDB.end_row(appender)

    has_duals || return nothing

    append_component_info!(appender, cid, rtid, rid, sid, 3)
    DuckDB.append(appender, JuMP.reduced_cost(entry)::Float64)
    DuckDB.end_row(appender)

    return nothing
end

function append_component_result!(
    appender::DuckDB.Appender,
    cid::Int64,
    rtid::Int64,
    rid::Int64,
    entry::JuMP.AffExpr;
    has_duals::Bool,
    sid::Int64=-1,
)
    append_component_info!(appender, cid, rtid, rid, sid, 1)
    DuckDB.append(appender, JuMP.value(entry)::Float64)
    DuckDB.end_row(appender)

    return nothing
end

function append_component_result!(
    appender::DuckDB.Appender,
    cid::Int64,
    rtid::Int64,
    rid::Int64,
    entry::JuMP.ConstraintRef{M, C, S};
    has_duals::Bool,
    sid::Int64=-1,
) where {M, C, S}
    has_duals || return nothing

    append_component_info!(appender, cid, rtid, rid, sid, 4)
    DuckDB.append(appender, JuMP.shadow_price(entry)::Float64)
    DuckDB.end_row(appender)

    return nothing
end

function append_component_result!(
    appender::DuckDB.Appender,
    cid::Int64,
    rtid::Int64,
    rid::Int64,
    entry::Vector{T};
    has_duals::Bool,
) where {T}
    for (t, item) in enumerate(entry)
        append_component_result!(appender, cid, rtid, rid, item::T; has_duals, sid=t::Int64)
    end
end

function db_create_table(db::DuckDB.DB, model::JuMP.Model, ::AttrExtractObjectives)
    DuckDB.execute(db, "CREATE TABLE objectives (name STRING, value DOUBLE)")

    appender = DuckDB.Appender(db, "objectives")
    for (name, objective) in IESopt._iesopt_model(model).objectives
        DuckDB.append(appender, name)
        DuckDB.append(appender, JuMP.value(objective.expr::JuMP.AffExpr))
        DuckDB.end_row(appender)
    end
    return DuckDB.close(appender)
end

function db_create_table(db::DuckDB.DB, model::JuMP.Model, ::AttrExtractMeta)
    a = DuckDB.append
    e = DuckDB.end_row

    DuckDB.execute(
        db,
        "CREATE TABLE meta (\
            name STRING, \
            value UNION(int INT64, float DOUBLE, str STRING, bool BOOLEAN), \
        )",
    )

    meta = DuckDB.Appender(db, "meta")

    a(meta, "iesopt_version"); a(meta, string(pkgversion(IESopt))::String); e(meta)
    a(meta, "solver_name"); a(meta, JuMP.solver_name(model)::String); e(meta)
    a(meta, "termination_status"); a(meta, string(JuMP.termination_status(model))::String); e(meta)
    a(meta, "solver_status"); a(meta, string(JuMP.raw_status(model))::String); e(meta)
    a(meta, "result_count"); a(meta, JuMP.result_count(model)::Int64); e(meta)
    a(meta, "objective_value"); a(meta, JuMP.objective_value(model)::Float64); e(meta)
    a(meta, "solve_time"); a(meta, JuMP.solve_time(model)::Float64); e(meta)
    a(meta, "has_values"); a(meta, JuMP.has_values(model)::Bool); e(meta)
    a(meta, "has_duals"); a(meta, JuMP.has_duals(model)::Bool); e(meta)
    a(meta, "primal_status"); a(meta, Int64(JuMP.primal_status(model))::Int64); e(meta)
    a(meta, "dual_status"); a(meta, Int64(JuMP.dual_status(model))::Int64); e(meta)
    a(meta, "log_iesopt"); a(meta, IESopt._get_iesopt_log(model)::String); e(meta)
    a(meta, "log_solver"); a(meta, IESopt._get_solver_log(model)::String); e(meta)

    DuckDB.close(meta)

    return nothing
end

# TODO: InputData
# TODO: snapshots
# TODO: carriers

function db_create_table(db::DuckDB.DB, model::JuMP.Model, ::AttrExtractResults)
    has_duals = JuMP.has_duals(model)
    rids = Dict{Symbol, Int64}()
    cids = Dict{String, Int64}()

    DuckDB.execute(db, "CREATE TABLE components (id INTEGER, name STRING)")
    DuckDB.execute(db, "CREATE TABLE tag_names (id INTEGER, name STRING)")
    DuckDB.execute(db, "CREATE TABLE tags (tid INTEGER, cid INTEGER)")

    # NOTE: foreign keys cost a lot (A LOT) of time, so they are omitted
    # vt ... value type (1 = primal, 2 = dual, 3 = reduced_cost, 4 = shadow_price)
    DuckDB.execute(db, "CREATE TABLE result_names (id INTEGER, name STRING)")
    DuckDB.execute(
        db,
        "CREATE TABLE results (\
            cid INTEGER, rtid INTEGER, rid INTEGER, sid INTEGER, vt INTEGER, \
            value DOUBLE, \
        )",
    )

    app_components = DuckDB.Appender(db, "components")
    app_results = DuckDB.Appender(db, "results")

    for (name, component) in IESopt._iesopt_model(model).components
        cid = cids[name] = length(cids) + 1

        DuckDB.append(app_components, cid)
        DuckDB.append(app_components, name)
        DuckDB.end_row(app_components)

        for (rtid, result_type) in enumerate([:expressions, :variables, :constraints, :objectives])
            ccoc = getfield(component, :_ccoc)::IESopt._CoreComponentOptContainer
            ccocd = getfield(ccoc, result_type)::IESopt._CoreComponentOptContainerDict
            d = getfield(
                ccocd,
                :dict,
            )::Dict{
                Symbol,
                <:Union{
                    JuMP.AffExpr,
                    Vector{JuMP.AffExpr},
                    JuMP.VariableRef,
                    Vector{JuMP.VariableRef},
                    JuMP.ConstraintRef,
                    Vector{<:JuMP.ConstraintRef},
                },
            }

            for (result, entry) in d
                rid = get!(rids, result, length(rids) + 1)
                append_component_result!(app_results, cid, rtid, rid, entry; has_duals)
            end
        end
    end

    DuckDB.close(app_components)
    DuckDB.close(app_results)

    appender = DuckDB.Appender(db, "result_names")
    for (name, rid) in rids
        DuckDB.append(appender, rid)
        DuckDB.append(appender, string(name))
        DuckDB.end_row(appender)
    end
    DuckDB.close(appender)

    app_tag_names = DuckDB.Appender(db, "tag_names")
    app_tags = DuckDB.Appender(db, "tags")

    tid = 1
    for (tag, cnames) in IESopt._iesopt_model(model).tags
        DuckDB.append(app_tag_names, tid)
        DuckDB.append(app_tag_names, tag)
        DuckDB.end_row(app_tag_names)

        for cname in cnames
            DuckDB.append(app_tags, tid)
            DuckDB.append(app_tags, cids[cname])
            DuckDB.end_row(app_tags)
        end

        tid += 1
    end

    DuckDB.close(app_tag_names)
    DuckDB.close(app_tags)

    return nothing
end

function extract(model::JuMP.Model)
    db = DuckDB.DB(":memory:")

    db_create_table(db, model, AttrExtractMeta())
    db_create_table(db, model, AttrExtractObjectives())
    db_create_table(db, model, AttrExtractResults())

    return db
end

query(db::DuckDB.DB, q::String) = DuckDB.execute(db, q)::DuckDB.QueryResult
query(db::DuckDB.DB, q::String, ::Type{Dict}) = Dict(query(db, q))
query(db::DuckDB.DB, q::String, ::Type{Vector}) = NamedTuple.(query(db, q))
query(db::DuckDB.DB, q::String, ::Type{DataFrames.DataFrame}) = DataFrames.DataFrame(query(db, q))

end
