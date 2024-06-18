# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.3] - 2024-06-18

Relax version requirements on IESoptLib to include all `v0.2.z` versions.

## [1.0.2] - 2024-06-10

Fix solver setup for various workflows.

### Changed

- `IESoptLib` and `HiGHS` are again required dependencies.

## [1.0.1] - 2024-06-09

Added extensions to properly handle loading `IESoptLib` and various solvers.

### Changed

- `IESoptLib` and `HiGHS` are no longer required dependencies.

### Fixed

- Dynamic loading of weakdeps now works properly.

## [1.0.0] - 2024-06-01

### Added

- Initial public release of IESopt.jl
