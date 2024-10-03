#!/bin/bash
set -x
set -e

# Source the script prelude
source "scripts/_prelude.sh"
source .env

PROJECT_DIR=$(pwd)
SCRIPT_DIR="${PROJECT_DIR}/scripts"
CIRCOM_DIR="${PROJECT_DIR}"

compile_circuit() {
    local circuit_dir=$1
    local circuit_file=$2
    local target_file="$circuit_dir/target/$(basename $circuit_file .circom).r1cs"

    print_action "[core/circom] Compiling $circuit_file example circuit..."
    if [ ! -f "$target_file" ]; then
        "${SCRIPT_DIR}/compile.sh" $circuit_dir $circuit_file
    else
        echo "File $target_file already exists, skipping compilation."
    fi
}

npm_install() {
    local circuit_dir=$1

    if [[ -f "$circuit_dir/package.json" && ! -d "$circuit_dir/node_modules" ]]; then
        echo "Installing npm dependencies for $circuit_dir..."
        (cd "${circuit_dir}" && npm install)
    fi
}

generate_witness() {
    local circuit_dir=$1
    local circuit_name=$2

    pushd $circuit_dir/target > /dev/null
    mkdir -p build
    if [ ! -f "build/${circuit_name}.wtns" ]; then
        if [ ! -f "../input.json"]; then
            node "${circuit_name}_js/generate_witness.js" "${circuit_name}_js/${circuit_name}.wasm" ../${circuit}.json build/${circuit_name}.wtns
        else
            node "${circuit_name}_js/generate_witness.js" "${circuit_name}_js/${circuit_name}.wasm" ../input.json build/${circuit_name}.wtns
        fi
    else
        echo "File build/${circuit_name}.wtns found, skipping witness generation."
    fi
    popd > /dev/null
}

# Check if arguments are provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <circuit-dir> <circuit-name>"
    echo "Example: $0 complex-circuit complex-circuit-100k-100k"
    exit 1
fi

# Read parameters from command line
circuit_dir="${CIRCOM_DIR}/$1"
circuit=$2

# Call functions with the provided parameters
npm_install $circuit_dir
compile_circuit $circuit_dir "${circuit}.circom"
generate_witness $circuit_dir ${circuit}
print_action "[core/circom] Running trusted setup for ${circuit}..."
"${SCRIPT_DIR}/trusted_setup.sh" $circuit_dir $PTAU_NUM $circuit