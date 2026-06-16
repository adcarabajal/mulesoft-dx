# Flex Gateway Performance Benchmark

POC harness for benchmarking Flex Gateway on EKS. See
[design doc](../docs/superpowers/specs/2026-05-19-W-21368048-flex-gateway-benchmark-design.md).

## Quick start

    cp .env.example .env
    make push-upstream   # one-time: build & push the upstream image to ECR
    make benchmark       # full run

## Targets

Run `make help`.
