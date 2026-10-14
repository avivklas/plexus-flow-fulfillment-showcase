# Smart Fulfillment Showcase: Polyglot Distributed Sagas with Plexus-Flow

[![Plexus-Flow](https://img.shields.io/badge/orchestrator-Plexus--Flow-blue.svg)](https://github.com/avivklas/plexus-flow)
[![Go Version](https://img.shields.io/badge/go-1.27+-00ADD8.svg)](https://golang.org)
[![Python Version](https://img.shields.io/badge/python-3.11+-3776AB.svg)](https://www.python.org)
[![Semantics](https://img.shields.io/badge/semantics-Exactly--Once%20(EOS)-green.svg)](https://github.com/avivklas/plexus)

A production-style showcase demonstrating **distributed sagas, multi-step DAG workflows, and polyglot microservices** running on [Plexus-Flow](https://github.com/avivklas/plexus-flow).

Microservices written in **Go** and **Python** coordinate via gRPC to execute an e-commerce fulfillment pipeline with **native Exactly-Once Semantics (EOS)** and **automatic LIFO Saga rollback** when failures or AI fraud anomalies occur.

---

## Architecture Overview

Modern architectures leverage different languages for what they do best:
- **Go Services**: High-throughput transaction state machines, warehouse holds, payment authorizations, and courier dispatch.
- **Python Services**: Machine Learning inference, behavioral fraud scoring, tax and customer data enrichment, and invoice generation.

### Why Plexus-Flow?
- **Zero External Dependencies**: Replaces Temporal, Kafka, ZooKeeper, and Redis locks with an embedded Raft graph and gRPC worker broker.
- **Polyglot Microservices**: Services run in isolated processes or containers, exchanging typed data through DAG dependency pipes.
- **First-Class Sagas**: Automatic reverse-order compensation (`void-authorization`, `release-inventory`) on failure with audit logs.
- **Out-of-the-Box Visual Observability**: Live web dashboard (`http://localhost:8080`) mapping the flow, attempts, durations, and traces.

---

## Workflow DAG Topology

```
                              PLEXUS-FLOW ENGINE (Raft Graph + gRPC Broker)
                                                   │
                       ┌───────────────────────────┴───────────────────────────┐
                       ▼                                                       ▼
           GO FULFILLMENT SERVICE                                   PYTHON AI & DATA SERVICE
         (Inventory, Payment, Shipping)                            (Risk Scoring, Telemetry, PDF)
                       │                                                       │
                       └───────────────────────────┬───────────────────────────┘
                                                   │
                                     WORKFLOW DAG TOPOLOGY
                                                   │
                                      [1. step-reserve-inventory]
                                             (Go Worker)
                                      Compensate: release-inventory
                                                   │
                                                   ▼
                                      [2. step-authorize-payment]
                                             (Go Worker)
                                      Compensate: void-authorization
                                                   │
                                ┌──────────────────┴──────────────────┐
                                ▼                                     ▼
                   [3a. step-evaluate-fraud-risk]       [3b. step-enrich-order-telemetry]
                          (Python AI Worker)                 (Python Intelligence)
                                │                                     │
                                └──────────────────┬──────────────────┘
                                                   ▼
                                      [4. step-dispatch-shipment]
                                             (Go Worker)
                                      Compensate: cancel-shipment
                                                   │
                                                   ▼
                                      [5. step-generate-receipt]
                                           (Python Worker)
```

---

## Quick Start: One-Command Automated Showcase

Run the entire showcase end-to-end:
```bash
chmod +x run_showcase.sh
./run_showcase.sh
```

This will:
1. Start the Plexus-Flow consensus engine and worker broker.
2. Boot the Go Fulfillment Worker (gRPC -> `127.0.0.1:9090`).
3. Boot the Python AI & Intelligence Worker (gRPC -> `127.0.0.1:9090`).
4. Execute **Scenario 1: Happy Path Flow** (Go + Python services cooperate to full success).
5. Execute **Scenario 2: Distributed Saga Rollback** (Python AI model flags fraud; Go payment and inventory services automatically compensate in reverse order).

---

## Running Manually in Separate Terminals

To observe each service's live log streams:

### 1. Start Plexus-Flow Engine
```bash
../plexus-flow/bin/plexus-flow --http-addr=127.0.0.1:8080 --grpc-addr=127.0.0.1:9090
```
*Open `http://127.0.0.1:8080` to access the live dashboard.*

### 2. Start Go Fulfillment Worker
```bash
go run ./go worker --grpc-addr=127.0.0.1:9090 --domain=fulfillment
```

### 3. Start Python AI & Intelligence Worker
```bash
uv run python python/services.py --grpc-addr=127.0.0.1:9090 --domain=ai
```

### 4. Submit Workflows

#### Happy Path Flow (Full Success):
```bash
go run ./go submit --order-id=ORD-HAPPY-1001
```
*Or using the Python launcher:*
```bash
uv run python python/launcher.py --order-id=ORD-HAPPY-1002
```

#### Simulated AI Fraud Rejection (Automatic Saga Rollback):
```bash
uv run python python/launcher.py --order-id=ORD-FRAUD-2001 --simulate-fraud
```
*Or using the Go launcher:*
```bash
go run ./go submit --order-id=ORD-FRAUD-2002 --simulate-fraud
```

---

## Pure Go Mode & Pure Python Mode

Both worker implementations can also serve all activities independently:
- **100% Go Fleet**: `go run ./go worker --domain=all`
- **100% Python Fleet**: `uv run python python/services.py --domain=all`

---

## License

MIT License. Built on [Plexus-Flow](https://github.com/avivklas/plexus-flow) and [Plexus](https://github.com/avivklas/plexus).
