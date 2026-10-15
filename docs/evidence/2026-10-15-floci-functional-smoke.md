# Functional smoke and rollback — Floci AWS

Date: 2026-10-15
Environment: Local Floci AWS emulator

## Positive deployment

Release: v1.3.0
- Health check: passed
- Version check: passed
- Functional smoke: 2+3=5 and 7+4=11
- Deployment: approved

## Negative deployment

Release: v1.4.0-badlogic
- Health check: passed
- Version check: passed
- Functional smoke: failed (2+3 returned 6)
- Deployment exit code: 1
- Automatic rollback: successful

## Recovery evidence

- Recovered version: v1.3.0
- Functional smoke after rollback: passed
- OpenTofu: No changes

## Scope

These tests validate the release-gating and rollback
mechanism using a simulated EC2 container.

They do not establish full Agent Platform correctness,
AWS networking parity, or release persistence after
instance replacement.
