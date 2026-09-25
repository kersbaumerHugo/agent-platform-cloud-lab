# ADR-002: Local Emulation Is Evidence, Not Proof of Cloud Parity

* Status: Accepted
* Date: 2026-09-25

## Context

The Agent Platform Cloud Lab uses Floci AZ as a local Azure-compatible control plane.

This allows the project to exercise Infrastructure as Code workflows locally using the same `azurerm` provider and Azure-shaped APIs that would be used against Microsoft Azure.

During the first OpenTofu lifecycle test, a manual drift experiment attempted to add a tag directly to an emulated Azure Resource Group.

The API accepted the request, but the tag was not persisted or returned by subsequent reads.

As a result, OpenTofu correctly reported no drift because the observable infrastructure state had not changed.

This demonstrated an important property of the lab:

> API compatibility does not imply complete behavioral parity with the real cloud platform.

An emulator may implement some behaviors faithfully, simplify others, mock some resources, or omit specific attributes and lifecycle semantics.

Therefore, a successful test against the local emulator is meaningful evidence that the infrastructure contract works, but it is not sufficient proof that the same behavior will be identical in real Azure.

## Decision

Treat local cloud emulation as a distinct validation layer rather than as a complete substitute for real-cloud validation.

The project will distinguish between:

1. **Local compatibility evidence**

   * OpenTofu configuration is syntactically and structurally valid.
   * Providers can initialize and communicate with the expected API contract.
   * Core create, read, update and delete workflows can be exercised.
   * Infrastructure dependencies and resource relationships can be tested.
   * Drift and reconciliation behavior can be tested when supported by the emulator.

2. **Cloud parity evidence**

   * Provider behavior is validated against real Azure APIs.
   * Azure-specific lifecycle behavior is exercised.
   * Authentication, authorization and RBAC are validated.
   * Real networking, routing and security behavior are validated.
   * Cloud-managed services are tested under their real control-plane and data-plane semantics.

Local tests MUST NOT be described as proof of Azure production parity unless the relevant behavior has also been validated against real Azure.

## Validation Model

The project will use progressive validation:

```text
Static validation
    ↓
Local emulation
    ↓
Integration testing
    ↓
Real-cloud validation
```

Each layer answers a different question.

### Static validation

Examples:

* `tofu fmt`
* `tofu validate`
* policy checks
* linting

Question answered:

> Is the configuration internally valid?

### Local emulation

Examples:

* Floci AZ
* AzureRM provider against local ARM-compatible APIs
* local lifecycle testing
* local drift experiments

Question answered:

> Does the infrastructure definition behave correctly against the supported cloud API contract?

### Integration testing

Examples:

* Kubernetes workloads
* networking relationships
* application deployment
* observability
* cross-component lifecycle tests

Question answered:

> Do the infrastructure components work together as expected?

### Real-cloud validation

Examples:

* Azure sandbox or development subscription
* constrained and disposable environments
* representative provisioning tests

Question answered:

> Does the architecture behave correctly under the actual Azure implementation?

## Evidence Levels

Project documentation and CI results should make the validation level explicit.

For example:

```text
Validated: static
Validated: local-emulator
Validated: integration
Validated: azure
```

A result validated only with Floci AZ should not be represented as Azure-validated.

## Emulator Limitations

When emulator behavior differs from Azure behavior, the project should:

1. Confirm whether the difference originates from:

   * the Infrastructure as Code configuration,
   * the provider,
   * the emulator,
   * or the real cloud contract.

2. Document meaningful emulator limitations when they affect architectural conclusions.

3. Prefer tests that exercise observable behavior supported by the emulator.

4. Avoid modifying production-oriented IaC solely to work around emulator-specific behavior unless the workaround is isolated behind an explicit local-environment boundary.

5. Escalate critical assumptions to real-cloud validation when emulator fidelity is insufficient.

## Architectural Principle

The emulator is a testing adapter, not the architecture itself.

Infrastructure code should remain primarily designed for the target cloud contract.

The local environment exists to provide fast and inexpensive feedback while preserving that contract as closely as practical.

This follows the project principles:

> Complexity Must Earn Its Place.

and

> Evidence-Gated Architecture.

A passing emulator test is evidence.

A production-parity claim requires stronger evidence.

## Consequences

### Positive

* Prevents false confidence from local-only testing.
* Makes validation claims explicit and auditable.
* Allows fast local development without pretending the emulator is Azure.
* Encourages targeted real-cloud testing instead of duplicating the entire development workflow in Azure.
* Makes emulator limitations part of the engineering evidence rather than hidden exceptions.
* Preserves infrastructure portability by keeping the emulator behind the cloud API boundary.

### Negative

* Some behaviors will require an Azure environment to validate fully.
* Additional validation stages increase CI/CD complexity.
* Certain emulator-specific limitations may require separate tests or documented exceptions.
* Local test success can no longer be treated as the final acceptance criterion for cloud-specific behavior.

## Rejected Alternatives

### Treat Floci AZ as equivalent to Azure

Rejected because API compatibility does not guarantee full behavioral parity.

### Avoid local emulation and test only against Azure

Rejected because it would increase cost, feedback time and operational friction for development and CI.

### Add emulator-specific behavior throughout the IaC

Rejected because it would couple infrastructure definitions to the testing implementation rather than to the Azure contract.

## Acceptance Criteria

This decision is considered correctly implemented when:

* local-emulator results are clearly distinguished from Azure validation;
* emulator limitations that affect conclusions are documented;
* the same primary IaC remains usable against the intended Azure environment;
* critical cloud-specific assumptions receive real-cloud validation before being considered production-proven;
* emulator-specific workarounds remain isolated and do not leak unnecessarily into the core infrastructure design.
