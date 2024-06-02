# First steps

## Need help?

To be added.

## Overview

IESopt (the framework) consists of various sub-projects. It is a component-based optimization framework, where each
component can be seen as block containing some predefined functionality. There are five "core components": `Connection`,
`Decision`, `Node`, `Profile`, and `Unit`. These will be used to define arbitrary energy system models, similar to how a
general commodity flow model works. Furthermore, they can be combined to create more complicated (non-core) components.

In their most basic form, core components can be described as:

- A `Connection` is used to model arbitrary flows of energy between `Node`s. It allows for limits, costs, delays, ...
- A `Decision` represents a basic decision variable in the model that can be used as input for various other core component's settings, as well as have associated costs.
- A `Node` represents a basic intersection/hub for energy flows. This can for example be some sort of bus (for electrical systems).
- A `Profile` allows representing exogenous functionality with a support for time series data.
- A `Unit` allows transforming one (or many) forms of energy into another one (or many), given some constraints and costs.

For most models, the `Unit`s will pack the most raw functionality, while the other components represent the structure of
the overall model.

## Your first model

To be added (translate from internal version).

### Model config

To be added (translate from internal version).

### Energy carriers

To be added (translate from internal version).

### Model components

To be added (translate from internal version).

### Final config file

To be added (translate from internal version).

### Running the optimization

To be added (translate from internal version).

## Extracting results

To be added (translate from internal version).

### General result structure

To be added (translate from internal version).

### Changing the model config

To be added (translate from internal version).

### Adapting components

To be added (translate from internal version).

### Analyzing the results

To be added (translate from internal version).

### Extracting results directly into `pd.DataFrame`s

To be added (translate from internal version).

## Final thoughts

To be added (translate from internal version).
