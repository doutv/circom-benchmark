#!/bin/bash
# Usage: benchmark.sh <circuit-name>
# Example: benchmark.sh complex-circuit

source .env
source "scripts/_prelude.sh"

# Check if arguments are provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <circuit-dir> <circuit-name>"
    echo "Example: $0 complex-circuit complex-circuit-100k-100k"
    exit 1
fi

CIRCUIT_DIR="$1"
CIRCUIT_NAME="$2"

# Single thread: sudo systemd-run --scope -p CPUQuota=100% ./shell_scripts/benchmark.sh
SAMPLE_SIZE=10

avg_time() {
    # usage: avg_time n command ...
    TIME=(/usr/bin/time -f "mem %M\ntime %e\ncpu %P")
    n=$1; shift
    (($# > 0)) || return                   # bail if no command given
    echo "$@"
    for ((i = 0; i < n; i++)); do
        "${TIME[@]}" "$@" 2>&1
        # | tee /dev/stderr
    done | awk '
        /^mem [0-9]+/ { mem = mem + $2; nm++ }
        /^time [0-9]+\.[0-9]+/ { time = time + $2; nt++ }
        /^cpu [0-9]+%/  { cpu  = cpu  + substr($2,1,length($2)-1); nc++}
        END    {
             if (nm>0) printf("mem %d MB\n", mem/nm/1024);
             if (nt>0) printf("time %f s\n", time/nt);
             if (nc>0) printf("cpu %d \n",  cpu/nc)
           }'
}

function RapidServer() {
  pushd "$CIRCUIT_DIR/target" > /dev/null

  # Create a symbolic link to rename final.zkey
  ln -s ${CIRCUIT_NAME}_final.zkey $CIRCUIT_NAME.zkey > /dev/null 2>&1 || true
  # Kill the proverServer if it is running on 9080 port
  kill -9 $(lsof -t -i:9080) > /dev/null 2>&1 || true
  # Start the prover server in the background
  ${proverServer} 9080 "$CIRCUIT_NAME".zkey > ../../rapidsnark.log 2>&1 &
  # Save the PID of the proverServer to kill it later
  PROVER_SERVER_PID=$!
  # Give the server some time to start
  sleep 3

  # Run the prover client and get the average time
  avg_t=$(avg_time $SAMPLE_SIZE node ${REQ} ../input.json $CIRCUIT_NAME | grep "time")

  # Get prover server CPU and memory usage
  ps_output=$(ps -p `pidof proverServer` -o %cpu,vsz --no-headers)
  avg_cpu=$(echo $ps_output | awk '{print $1"%"}')
  # avg_mem=$(echo $ps_output | awk '{$2=int($2/1024)"M"; print $2}')
  mem=$(grep -E 'VmPeak' /proc/`pidof proverServer`/status | awk '{print $2/1024 "MB"}' | numfmt --field=2 --format="%.2f")
  echo peak mem ${mem}
  echo ${avg_t}
  echo cpu ${avg_cpu}

  # Kill the proverServer
  kill $PROVER_SERVER_PID
  popd > /dev/null
}

echo "Sample Size =" $SAMPLE_SIZE

echo "========== RapidSnark Server  =========="
RapidServer