"""
A `Virtual` (component) is a component that does not exist in the model, but one that a user might expect to exist.
These are "components" that refer to a template. If a user creates a component "my_storage_foo", of type "Battery", they
might expect (and want) to be able to interact with "my_storage_foo". Since the template is flattened into explicit
`CoreComponent`s in the back, "my_storage_foo" does not actually exist - a problem that these `Virtual`s solve.
"""
@kwdef struct Virtual <: _CoreComponent
    # [Core] ===========================================================================================================
    model::JuMP.Model

    # [Mandatory] ======================================================================================================
    name::_String
    type::_String  # The actual type of the component, e.g., "Battery".

    # [Optional] =======================================================================================================
    # -

    # [Internal] =======================================================================================================
    # -

    # [External] =======================================================================================================
    # -

    # [Optimization Container] =========================================================================================
    _ccoc = _CoreComponentOptContainer()

    # `_ccoc` is kept as container, since that allows attaching stuff directly to the `Virtual`, e.g., in addons.
end

_result_fields(::Virtual) = (:name, :type)

_check(cc::Virtual) = true
_prepare!(::Virtual) = true
_isvalid(cc::Virtual) = true
_setup!(::Virtual) = true

_build_priority(cc::Virtual) = -1  # This means that `Virtual`s are not built.

function Base.getproperty(cc::Virtual, field::Symbol)
    try
        (field == :var) && (return getfield(cc, :_ccoc).variables)
        (field == :con) && (return getfield(cc, :_ccoc).constraints)
        (field == :exp) && (return getfield(cc, :_ccoc).expressions)
        (field == :obj) && (return getfield(cc, :_ccoc).objectives)

        # See if we may be trying to find a component that is "inside" this Virtual?
        cname = "$(getfield(cc, :name)).$field"
        model = getfield(cc, :model)
        haskey(_iesopt(model).model.components, cname) && return component(model, cname)

        return getfield(cc, field)
    catch e
        @critical "Field not found in _CoreComponent" e
    end
end
