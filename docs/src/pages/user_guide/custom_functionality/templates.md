# Templates

_"Core Templates"_ are pre- or user-defined templates, that group and/or reparameterize IESopt.jl `CoreComponent`s, or
even other Core Templates. They are used to define more complex building blocks, that can be used in the optimization
model.

## General structure

A Core Template is defined by a YAML file, ending in `.iesopt.template.yaml`, that may contain the following entries:

1. `parameters` (optional): a dictionary of parameters that can be used to reparameterize the template
2. `functions` (optional): `validate`, `prepare`, and `finalize` functions, containing Julia code
3. `files` (optional): files can be loaded here "on demand" similar to the top-level config

Further exactly one of the following entries is required:

- `components`: a dictionary of components that are part of the template, or
- `component`: a single component that is part of the template

### Example: A simple template

```yaml
parameters:
  some_custom_param: null
  another_one: 100.0
  one_more: heat

components:
  a_node:
    type: Node

  b_node:
    type: Node
```

To be added (more details).

## [Validate](@id manual_templates_validate)

To be added (explanation).

```yaml
validation: |
  @check parameters["carrier"] isa String
  @check parameters["carrier"] in ["heat", "electricity"]
```

To be added (more examples).

## [Prepare](@id manual_templates_prepare)

To be added (explanation).

## [Finalize](@id manual_templates_finalize)

To be added (explanation).
