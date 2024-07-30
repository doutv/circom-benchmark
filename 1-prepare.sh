#!/bin/bash

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
    node "${circuit_name}_js/generate_witness.js" "${circuit_name}_js/${circuit_name}.wasm" ../input.json build/${circuit_name}.wtns
    popd > /dev/null
}

# Check if arguments are provided
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <circuit>"
    exit 1
fi

# Read parameters from command line
circuit=$1
circuit_dir="${CIRCOM_DIR}/$1"

# Call functions with the provided parameters
npm_install $circuit_dir
compile_circuit $circuit_dir "${circuit}.circom"
generate_witness $circuit_dir ${circuit}
print_action "[core/circom] Running trusted setup for ${circuit}..."
"${SCRIPT_DIR}/trusted_setup.sh" $circuit_dir $PTAU_NUM $circuit