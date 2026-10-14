#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${SCRIPT_DIR}"
PLEXUS_FLOW_DIR="${SCRIPT_DIR}/../plexus-flow"
DATA_DIR="/tmp/smart-fulfillment-data"

HTTP_ADDR="127.0.0.1:8080"
GRPC_ADDR="127.0.0.1:9090"
RAFT_ADDR="127.0.0.1:9000"
ACT_RAFT_ADDR="127.0.0.1:9001"

CYAN="\033[36m"
GREEN="\033[32m"
YELLOW="\033[33m"
PURPLE="\033[35m"
RED="\033[31m"
BOLD="\033[1m"
RESET="\033[0m"

echo -e "${CYAN}${BOLD}"
echo "  ____                       _     _____      _  __ _ _ _                      _   "
echo " / ___| _ __ ___   __ _ _ __| |_  |  ___|   _| |/ _(_) | |_ __ ___   ___ _ __ | |_ "
echo " \___ \| '_ \` _ \ / _\` | '__| __| | |_ | | | | | |_| | | | '_ \` _ \ / _ \ '_ \| __|"
echo "  ___) | | | | | | (_| | |  | |_  |  _|| |_| | |  _| | | | | | | | |  __/ | | | |_ "
echo " |____/|_| |_| |_|\__,_|_|   \__| |_|   \__,_|_|_| |_|_|_|_| |_| |_|\___|_| |_|\__|"
echo -e "${RESET}"
echo -e "${BOLD}Plexus-Flow Showcase: Distributed Sagas & Multi-Step Workflow Orchestration${RESET}"
echo -e "Polyglot Microservices: Go (Fulfillment) + Python (AI Risk) via Raft Graph\n"

# Cleanup function
PIDS=()
cleanup() {
    echo -e "\n${YELLOW}[Teardown] Shutting down showcase background processes...${RESET}"
    for pid in "${PIDS[@]}"; do
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null || true
        fi
    done
    wait 2>/dev/null || true
    echo -e "${GREEN}[Teardown] Clean exit.${RESET}"
}
trap cleanup EXIT INT TERM

# 1. Build or locate plexus-flow binary
echo -e "${CYAN}[1/5] Checking Plexus-Flow server binary...${RESET}"
if [ ! -f "${PLEXUS_FLOW_DIR}/bin/plexus-flow" ]; then
    echo "Building plexus-flow binary from ${PLEXUS_FLOW_DIR}..."
    (cd "${PLEXUS_FLOW_DIR}" && go build -o bin/plexus-flow ./cmd/plexus-flow)
fi
BINARY="${PLEXUS_FLOW_DIR}/bin/plexus-flow"

# 2. Reset data directory
rm -rf "${DATA_DIR}"
mkdir -p "${DATA_DIR}"

# 3. Start Plexus-Flow Server in background
echo -e "${CYAN}[2/5] Starting Plexus-Flow consensus engine & worker broker...${RESET}"
"${BINARY}" \
    --http-addr="${HTTP_ADDR}" \
    --grpc-addr="${GRPC_ADDR}" \
    --raft-addr="${RAFT_ADDR}" \
    --act-raft-addr="${ACT_RAFT_ADDR}" \
    --data-dir="${DATA_DIR}" > /tmp/showcase-plexus-server.log 2>&1 &
SERVER_PID=$!
PIDS+=("$SERVER_PID")

# Wait for server leadership
echo -n "Waiting for Raft consensus leadership..."
for i in {1..40}; do
    if curl -s "http://${HTTP_ADDR}/api/v1/cluster/status" | grep -q '"is_leader":true'; then
        echo -e " ${GREEN}Leader active!${RESET}"
        break
    fi
    sleep 0.25
done

# 4. Start Go Fulfillment Worker (Inventory, Payment, Shipping)
echo -e "${CYAN}[3/5] Starting Go Fulfillment Worker (gRPC -> ${GRPC_ADDR})...${RESET}"
cd "${REPO_ROOT}"
go run ./go worker \
    --grpc-addr="${GRPC_ADDR}" \
    --worker-id="go-fulfillment-service" \
    --domain=fulfillment > /tmp/showcase-go-worker.log 2>&1 &
GO_WORKER_PID=$!
PIDS+=("$GO_WORKER_PID")

# 5. Start Python AI & Intelligence Worker (Fraud Model, Telemetry, Invoicing)
echo -e "${CYAN}[4/5] Starting Python AI & Intelligence Worker (gRPC -> ${GRPC_ADDR})...${RESET}"
cd "${REPO_ROOT}"
uv run python python/services.py \
    --grpc-addr="${GRPC_ADDR}" \
    --worker-id="python-ai-service" \
    --domain=ai > /tmp/showcase-py-worker.log 2>&1 &
PY_WORKER_PID=$!
PIDS+=("$PY_WORKER_PID")

# Let workers connect and register
sleep 1.2
echo -e "${GREEN}Both Go & Python microservices connected and registered activities via gRPC!${RESET}"
echo -e "${PURPLE}[Dashboard] Open http://${HTTP_ADDR} in your browser to view the visual DAG graph & traces!${RESET}\n"

# -----------------------------------------------------------------------------
# DEMO 1: Polyglot Happy Path
# -----------------------------------------------------------------------------
echo -e "${CYAN}========================================================================${RESET}"
echo -e "${BOLD}[DEMO 1] POLYGLOT COLLABORATION: Happy Path Flow${RESET}"
echo -e "  1. Go Worker:      Reserves Inventory hold (SKU: QUANTUM-GPU-9000)"
echo -e "  2. Go Worker:      Pre-authorizes payment on customer card"
echo -e "  3. Python Worker:  Evaluates AI Fraud Risk model in parallel with"
echo -e "  4. Python Worker:  Enriching customer telemetry and tax matrix"
echo -e "  5. Go Worker:      Dispatches courier shipment with generated airway bill"
echo -e "  6. Python Worker:  Synthesizes order invoice and audit receipt"
echo -e "${CYAN}========================================================================${RESET}"

cd "${REPO_ROOT}"
go run ./go submit \
    --http-addr="http://${HTTP_ADDR}" \
    --order-id="ORD-HAPPY-9001"

sleep 1.5

# -----------------------------------------------------------------------------
# DEMO 2: AI Fraud Detection -> Automatic Saga Rollback
# -----------------------------------------------------------------------------
echo -e "${CYAN}========================================================================${RESET}"
echo -e "${BOLD}[DEMO 2] DISTRIBUTED SAGA ROLLBACK: AI Fraud Detection Rejection${RESET}"
echo -e "  1. Go Worker:      Reserves Inventory hold"
echo -e "  2. Go Worker:      Pre-authorizes payment on customer card"
echo -e "  3. Python Worker:  AI Fraud Model flags transaction anomaly (score=0.96)"
echo -e "                     -> Raises PermanentFailure(code='FRAUD_DETECTED')"
echo -e "  4. Plexus-Flow:    Triggering automatic reverse-order compensation (LIFO):"
echo -e "     - Go Worker:    Compensating 'void-authorization' (releasing hold)"
echo -e "     - Go Worker:    Compensating 'release-inventory' (restocking item)"
echo -e "  Result: System returns to clean state with ZERO orphaned holds!"
echo -e "${CYAN}========================================================================${RESET}"

cd "${REPO_ROOT}"
uv run python python/launcher.py \
    --http-addr="http://${HTTP_ADDR}" \
    --order-id="ORD-FRAUD-ROLLBACK-9002" \
    --simulate-fraud

BLOCK_MODE=true
for arg in "$@"; do
    if [ "$arg" == "--no-block" ]; then
        BLOCK_MODE=false
    fi
done

echo -e "\n${GREEN}${BOLD}Showcase demo runs completed!${RESET}"
echo -e "${PURPLE}Services remain active and running in background.${RESET}"
echo -e "👉 Visit ${BOLD}http://${HTTP_ADDR}${RESET} to explore live traces, DAG visualizer, and audit timelines."

if [ "$BLOCK_MODE" = true ]; then
    echo -e "${YELLOW}Press Ctrl+C to shut down all showcase services.${RESET}\n"
    # Keep server and workers running so the user can interact with the dashboard
    while kill -0 "$SERVER_PID" 2>/dev/null; do
        sleep 1
    done
fi
