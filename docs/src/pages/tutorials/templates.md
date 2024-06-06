# Creating Templates

Templates are a powerful feature of IESopt that allow you to define new types of "components" by yourself. This makes
use of the existing `CoreComponent`s, and combines them in multiple ways, which allows for a high degree of flexibility
without having to write any mathematical model yourself.

This tutorial will guide you through the process of creating a new template, and we will do that on the example of
creating the `HeatPump` template (a template shipped via IESoptLib).

## The basic structure

A template is defined by a YAML file, similar to the `config.iesopt.yaml` file that you already know. First, we need to
think about the parameters that we want to define for our heat pump. Let's create a new file for that. The pre-defined
one in IESoptLib is called `HeatPump`, so we need a different name: Templates must always have a unique name.

Possiblities for that could be:

- `CustomHeatPump`, if you do not have any more details
- `GroundSourceHeatPump`, if we want to implement a ground-source heat pump with different parameters/features than the
  standard one
- `FooHeatPump`, if you need it specifically for a project called "Foo"

!!! info "Naming conventions"
    Templates follow a naming convention similar to `PascalCase`:
    - The name must start with an upper-case letter
    - It must consist of at least two letters
    - Numbers and special characters are not allowed

Let's go with `CustomHeatPump` for now. Create a new file `CustomHeatPump.iesopt.template.yaml` (if you are already
working on a model, the best place to put this would be a `templates/` folder), and add the following lines:

```yaml
parameters:
  p_nom: null
  electricity_from: null
  heat_from: null
  heat_to: null
  cop: null
```

This defines the basic parameters that we want to use for our heat pump. The `null` values indicate that they all
default to `nothing` in Julia, which corresponds to `None` in Python. Let's go through them:

- `p_nom`: The nominal power of the heat pump, which will be specified on the electricity input side
- `electricity_from`: The `Node` that this heat pump is connected to for electricity input
- `heat_from`: The `Node` that this heat pump is connected to for heat input
- `heat_to`: The `Node` that this heat pump is connected to for heat output
- `cop`: The coefficient of performance of the heat pump

Next, we will set up the actual component. This is done in the `component` section of the template file. Let's add the
following lines:

```yaml
component:
  type: Unit
  inputs: {electricity: <electricity_from>, heat: <heat_from>}
  outputs: {heat: <heat_to>}
  conversion: 1 electricity + (1 - <cop>) heat -> <cop> heat
  capacity: <p_nom> in:electricity
```

This defines the component that we want to create. The `type` is `Unit`, which is a core component type in IESopt that
you are already familiar with. Instead of providing fixed values, we make use of the parameters that we defined above.
This is done by using the `<...>` syntax.

That's it! You have created a new template. You can now use this template in your model configuration, as you would with
any other component. For example, you could add the following lines to your `config.iesopt.yaml` file:

```yaml
# other parts of the configuration file
# ...

components:
  # some other components
  # ...

  heat_pump:
    template: CustomHeatPump
    parameters:
      p_nom: 10
      electricity_from: electricity
      heat_from: ambient
      heat_to: heating
      cop: 3
```

## Accounting for different configurations

But wait. What if you want to have different configurations for your heat pump? For example, you might want to have a
heat pump that does not explicitly consume any heat, because they low-temperature heat source is not explicitly modeled.
Currently, the template does not allow for that, because the `heat_from` parameter is mandatory.

Why do we know it is mandatory? Because it is used in the `inputs` section of the `Unit` definition. But that is not
clear, or transparent. Before we continue, we will fill in the mandatory documentation fields for the template. We do
that by adding the following information directly at the beginning of the template file, right before the `parameters`:

```yaml
# # Heat Pump

# A heat pump that consumes electricity and heat, and produces heat.

# ## Parameters
# - `p_nom`: The nominal power (electricity) of the heat pump.
# - `electricity_from`: The `Node` that this heat pump is connected to for electricity input.
# - `heat_from`: The `Node` that this heat pump is connected to for heat input.
# - `heat_to`: The `Node` that this heat pump is connected to for heat output.
# - `cop`: The coefficient of performance of the heat pump.

# ## Components
# _to be added_

# ## Usage
# _to be added_

# ## Details
# _to be added_

parameters:
  # ...
```

!!! info "Docstring format"
    All of that is actually just Markdown inserted into your template. However, make sure to stick to separating the
    leading `#` from the actual text by a space, as this is required for IESopt to better understand your documentation.

Now, every user of the template will see this information, and they will notice, that none of the parameters are marked
as optional. As you see, there are a lot of other sections to be added, but we will fill them out at the end, after we
have finished the template, see the section on [finalizing the docstring](#Finalizing-the-docstring).

Let's continue with accounting for different configurations. We will cover the following steps:

1. Making the `heat_from` parameter optional
2. Extending the template to allow for sizing the heat pump (an investment decision)
3. Handling more complex COP configurations

### Optional parameter

While there are multiple ways to make a parameter optional, we will make use of the most powerful one, so that you are
able to apply it for your models as well. For that, we will add "complex" functionalities to the template, which is done
using three different "functions":

1. `validate`: This function is called when the template is parsed, and it is used to check if the parameters are valid.
   If they are not, an error is thrown. This helps to inform the user of any misconfiguration.
2. `prepare`: This function is called when the template is instantiated, and it is used to prepare the component for
   usage. This can be used to set default values, or to calculate derived parameters (which we will use to tackle the
   three additions mentioned above).
3. `finalize`: This function is called when the template is finalized, and it enables a wide range of options. We will
    use this to allow a smooth result extraction for the heat pump, but you could also use it to add additional (more
    complex) constraints to the component, or even modify the model's objective function.

Let's start by adding the `functions` entry (which we suggest doing at the end of the file):

```yaml
# ... the whole docstring ...

parameters:
  # ...

component:
  # ...

functions:
  validate: |
    # ... we will put the validation code here ...
  prepare: |
    # ... we will put the preparation code here ...
  finalize: |
    # ... we will put the finalization code here ...
```

> The `|` at the end of the line indicates that the following lines are a multiline string. This is a YAML feature that
> allows you to write more complex code in a more readable way.

Let's start by filling out the validation function. Everything you do and write here, is interpreted as Julia code, and
compiled directly into your model. This means that you can use all the power of Julia, but also that you need to be
careful with what you do. You have access to certain helper functions and constants, which we will introduce here. If
you have never written a line of Julia code, don't worry. We will guide you through this - it's actually (at least for
the parts that you will need) extremely similar to Python.

#### Validation

The validation function is used to check if the parameters are valid. Add the following code to the `validate` section:

```yaml
functions:
  validate: |
    # Check if `p_nom` is non-negative.
    @check get("p_nom") isa Number
    @check get("p_nom") >= 0

    # Check if the `Node` parameters are `String`s, where `heat_from` may also be `nothing`.
    @check get("electricity_from") isa String
    @check get("heat_from") isa String || isnothing(get("heat_from"))
    @check get("heat_to") isa String

    # Check if `cop` is positive.
    @check get("cop") isa Number
    @check get("cop") > 0
  # ... the rest of the template ...
```

Let's go through this step by step:

- You can start comments (as separate line or inline) with `#`, as you would in Python.
- You can use `get("some_param")` to access the value of a parameter.
- You can use `@check` to check if a condition is met. If it is not, an error will be thrown. All statements starting
  with `@` are so called "macros", which are just "special" functions. You can do `@check(condition)` or
  `@check condition`, since macros do not require parentheses.
- You can use `isa` to check if a value is of a certain type. This is similar to `isinstance` in Python. While it is a
  special keyword, if you prefer, you can also call it in a more conventional way: `isa(get("p_nom"), Number)`.
- Data types are capitalized in Julia, so it is `String` instead of `string`, and `Number` is a superset of all numeric
  types (if necessary you could instead, e.g., check for `get("some_param") isa Int`).
- Logical operators are similar to Python, so `||` is like `or`, and `&&` is like `and`.
- If all checks pass, the template is considered valid, and the model can be built.

#### Preparation

Next, we will add the preparation function. This function is used to prepare the component for usage. Since we would
like to make the `heat_from` parameter optional, and we would like to account for optional sizing, we will first modify
the parameters accordingly:

```yaml
parameters:
  p_nom: null
  p_nom_max: null
  electricity_from: null
  heat_from: null
  heat_to: null
  cop: null
  _inputs: null
  _conversion: null
  _capacity: null
  _invest: null
```

One step at a time. We added the following parameters:

- `p_nom_max`: The maximum nominal power of the heat pump. This is optional, and if not specified, it will default to
  `p_nom`, which will disable the sizing feature.
- `_inputs`: This is an internal / private parameter (since it starts with an underscore), which we will user later.
  These parameters are not exposed to the user, and can not be set or modified from the outside.
- `_capacity`: This is another internal parameter, which we will use to store the capacity of the heat pump (which could
  now either bne `p_nom` or whatever the investment decision results in).
- `_conversion`: This is another internal parameter, which we will use to store the conversion formula.

Before we can actually add the code for the `prepare` function, we need to modify our component definition, as well.
We (1) will change from `component` to `components` (since it now contains more than just one), (2) will add a
`Decision` that should handle the sizing / investment, and modify the `Unit` slightly:

```yaml
components:
  unit:
    type: Unit
    inputs: <_inputs>
    outputs: {heat: <heat_to>}
    conversion: <_conversion>
    capacity: <_capacity> in:electricity
  
  decision:
    type: Decision
    enabled: <_invest>
    lb: <p_nom>
    ub: <p_nom_max>
```

So ... a lot of changes. Let's go through them step by step:

- We changed `component` to `components`, because we now have multiple components.
- We added a `unit` component, which is the actual heat pump. We replaced the fixed values with the internal parameters.
- We added a new component `decision`, which is a `Decision`. This component is used to handle investment
  decisions. It is enabled if `_invest` evaluates to `true`. It has a lower bound `lb` and an upper bound `ub`, which
  are the minimum and maximum values that the decision can take. In our case, the decision is the nominal power of the
  heat pump, which can be between `p_nom` and `p_nom_max`.

!!! info "Naming the components"
    The names of the components are arbitrary, and you can choose whatever you like. However, it is recommended to use
    meaningful names, so that you can easily understand what the component does. Component names follow a naming
    convention similar to `snake_case`: They must start with a lower-case letter, and can contain numbers and
    underscores (but are not allowed to end in an `_`). They can further contain `.`, but this is "dangerous" and an
    expert feature, that you should not use unless you know what it does, and why you need it.

Onto the actual functionality. Let's add the `prepare` function, and add additional validation code:

```yaml
functions:
  validate: |
    # ... the previous validation code ...

    # Check if `p_nom_max` is either `nothing` or at least `p_nom`.
    @check isnothing(get("p_nom_max")) || (get("p_nom_max") isa Number && get("p_nom_max") >= get("p_nom"))
  prepare: |
    # Determine if investment should be enabled.

```

## Finalizing the docstring

To be added.
