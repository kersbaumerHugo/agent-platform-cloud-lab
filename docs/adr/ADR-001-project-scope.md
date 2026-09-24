# ADR-001: Project Scope and Infrastructure Boundary

- Status: Accepted
- Date: 2026-09-24

## Context

The Agent Platform has been designed around explicit architectural boundaries and the principle that application concerns should remain independent from deployment infrastructure.

That claim now needs to be tested against a real infrastructure lifecycle.

## Decision

Create a separate repository responsible for infrastructure and deployment concerns.

The first implementation will use:

- Azure as the target cloud model
- Floci AZ as the local Azure-compatible environment
- OpenTofu as the primary Infrastructure as Code engine
- Kubernetes as the workload orchestration layer
- Ansible only where configuration management is justified
- Agent Platform as an external workload

## Boundary

This repository owns:

- infrastructure provisioning
- networking
- Kubernetes infrastructure
- deployment configuration
- infrastructure secrets integration
- observability infrastructure
- CI/CD infrastructure workflows

The Agent Platform repository owns:

- domain logic
- application logic
- agent orchestration
- model/provider abstractions
- evaluation
- retrieval
- execution contracts

Infrastructure changes must not require meaningful modifications to the Agent Platform domain or application layers.

## Acceptance Criterion

A change between supported infrastructure environments should primarily affect adapters, configuration or deployment artifacts.

If migrating infrastructure requires changes to core domain logic, the architectural boundary must be reviewed.

## Consequences

### Positive

- Infrastructure becomes independently testable.
- Architectural portability becomes measurable.
- Cloud and platform engineering skills can be exercised against a real workload.
- Infrastructure complexity does not pollute the Agent Platform.

### Negative

- Two repositories must evolve together.
- Deployment contracts between repositories must be explicitly versioned.
- Some integration testing becomes cross-repository.

## Principle

Complexity must earn its place.
