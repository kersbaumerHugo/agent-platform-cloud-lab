# Agent Platform Cloud Lab

A reproducible cloud-native infrastructure lab for deploying the Agent Platform.

The project exists to validate a core architectural claim:

> Application architecture must not depend on the infrastructure that runs it.

## Goals

- Provision Azure-shaped infrastructure as code
- Use OpenTofu as the primary IaC engine
- Use Floci AZ as the initial local Azure-compatible environment
- Provision Kubernetes through an AKS-compatible API
- Use Ansible where configuration management adds real value
- Deploy the existing Agent Platform as the workload
- Add CI/CD, GitOps and observability incrementally
- Prove destroy/recreate reproducibility
- Minimize infrastructure coupling inside the Agent Platform

## Architecture

OpenTofu
    ↓
Azure-compatible API
    ↓
Floci AZ
    ↓
AKS / K3s
    ↓
Kubernetes
    ↓
Agent Platform

Later stages will introduce:

GitHub Actions → IaC validation → deployment → GitOps → observability

## Engineering Principles

- Complexity must earn its place
- Infrastructure as Code
- Git as source of truth
- Reproducibility over manual configuration
- Evidence over architectural claims
- Application and infrastructure concerns remain separated

## Acceptance Gates

The project is considered successful when:

1. Infrastructure can be created from an empty environment using code.
2. The Agent Platform can be deployed without meaningful changes to its domain or application layers.
3. A second `tofu plan` after deployment reports no unintended drift.
4. The environment can be destroyed and recreated successfully.
5. CI validates the infrastructure code.
6. Kubernetes deployment is declarative.
7. Infrastructure and application telemetry are observable.
8. Infrastructure-specific concerns remain outside the Agent Platform core.

## Non-goals

- Multi-cloud in V1
- Production-grade HA
- Premature abstractions
- Rebuilding capabilities already owned by the Agent Platform
