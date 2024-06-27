#!/bin/bash

# NOTE: Like update_bindings.sh but for updating a project
# At some point these scripts will be consolidated

# Check if MOPRO_ROOT is set
if [ -z "$MOPRO_ROOT" ]; then
    echo "MOPRO_ROOT is not set. Please set it to your local mopro repository."
    exit 1
fi

# Source the script prelude
source "${MOPRO_ROOT}/scripts/_prelude.sh"

# Check if toml-cli is installed
if ! command -v toml &> /dev/null; then
    echo -e "${RED}toml (toml-cli) is not installed. Please install it to continue.${DEFAULT}"
    exit 1
fi

# Function to read value from TOML file and remove quotes
read_toml() {
    toml get "$1" "$2" | tr -d '"'
}

# NOTE: This is quite noisy so turning off by default
# Coloring the -x output (commands)
DEBUG_COLOR="${DEFAULT}"
trap 'echo -e ${DEBUG_COLOR}${BASH_COMMAND}${DEFAULT}' DEBUG

# Check if a configuration file was passed as an argument
if [ "$#" -ne 1 ]; then
    echo -e "\n${RED}Usage: $0 path/to/config.toml${DEFAULT}"
    exit 1
fi

# Read the path to the TOML configuration file from the first argument
CONFIG_FILE="$1"

# XXX: This isn't necessarily propagated to `cargo build` build process,
# so we pass it explicitly. Consider using `source` instead of `export`.
# Export the configuration file path as an environment variable
export BUILD_CONFIG_PATH="$(pwd)/$CONFIG_FILE"

# Print which configuration file is being used
echo "Using build configuration file: $BUILD_CONFIG_PATH"

# Read configurations from TOML file
DEVICE_TYPE=$(read_toml "$CONFIG_FILE" "build.ios_device_type")
BUILD_MODE=$(read_toml "$CONFIG_FILE" "build.build_mode")
USE_DYLIB=$(read_toml "$CONFIG_FILE" "dylib.use_dylib")
DYLIB_NAME=$(read_toml "$CONFIG_FILE" "dylib.name")

# # Assert we're in the project root
# if [[ ! -d "mopro-ffi" || ! -d "mopro-core" ]]; then
#     echo -e "${RED}Error: This script must be run from the project root directory that contains mopro-ffi and mopro-core folders.${DEFAULT}"
#     exit 1
# fi

# Determine architecture based on device type
case $DEVICE_TYPE in
    "x86_64")
        ARCHITECTURE="x86_64-apple-ios"
        ;;
    "simulator")
        ARCHITECTURE="aarch64-apple-ios-sim"
        ;;
    "device")
        ARCHITECTURE="aarch64-apple-ios"
        ;;
    *)
        echo -e "${RED}Error: Invalid device type specified in config: $DEVICE_TYPE${DEFAULT}"
        exit 1
        ;;
esac

# Determine library directory based on build mode
case $BUILD_MODE in
    "debug")
        LIB_DIR="debug"
        ;;
    "release")
        LIB_DIR="release"
        ;;
    *)
        echo -e "${RED}Error: Invalid build mode specified in config: $BUILD_MODE${DEFAULT}"
        exit 1
        ;;
esac

# Check dylib usage and name
if [[ "$USE_DYLIB" == true ]]; then
    if [[ -z "$DYLIB_NAME" ]]; then
        echo -e "${RED}Error: Dylib name not specified in config while 'use_dylib' is set to true.${DEFAULT}"
        exit 1
    fi
fi

print_action "Updating mopro-ffi bindings and library ($BUILD_MODE $DEVICE_TYPE)..."

PROJECT_DIR=$(pwd)
TARGET_DIR=${PROJECT_DIR}/target
MOPROKIT_DIR=${PROJECT_DIR}/ios/MoproKit

# Dylib directory and settings
if [[ "$USE_DYLIB" == true ]]; then
    mkdir -p ${TARGET_DIR}/${ARCHITECTURE}/${BUILD_MODE}
    export TARGET_DIR
    export BUILD_MODE
fi

# NOTE: Here we assume mopro.udl stays the same, for adjusting this we need to
# Expand core to also include the udl file with mopro-ffi etc

# Generate Swift bindings
print_action "Generating Swift bindings..."
uniffi-bindgen generate ${MOPRO_ROOT}/mopro-ffi/src/mopro.udl --language swift --out-dir ${TARGET_DIR}/SwiftBindings

# Build mopro-ffi
cd "${MOPRO_ROOT}/mopro-ffi"
if [[ "$USE_DYLIB" == true ]]; then
    # Build dylib
    print_action "Building mopro-ffi with dylib flag ($BUILD_MODE)..."
    if [[ "$BUILD_MODE" == "debug" ]]; then
        cargo build --target ${ARCHITECTURE} --features dylib
    elif [[ "$BUILD_MODE" == "release" ]]; then
        cargo build --release --target ${ARCHITECTURE} --features dylib
    fi
else
    print_action "Building mopro-ffi static library ($BUILD_MODE)..."
    if [[ "$BUILD_MODE" == "debug" ]]; then
        cargo build --target ${ARCHITECTURE}
    elif [[ "$BUILD_MODE" == "release" ]]; then
        cargo build --release --target ${ARCHITECTURE}
    fi
fi

# Print appropriate message based on device type
if [[ "$DEVICE_TYPE" == "x86_64" ]]; then
    print_action "Using $ARCHITECTURE libmopro_ffi.a ($LIB_DIR) static library..."
    print_warning "This only works on iOS simulator (x86_64)"
elif [[ "$DEVICE_TYPE" == "simulator" ]]; then
    print_action "Using $ARCHITECTURE libmopro_ffi.a ($LIB_DIR) static library..."
    print_warning "This only works on iOS simulator (ARM64)"
elif [[ "$DEVICE_TYPE" == "device" ]]; then
    print_action "Using $ARCHITECTURE libmopro_ffi.a ($LIB_DIR) static library..."
    print_warning "This only works on iOS devices (ARM64)"
fi

cp ${MOPRO_ROOT}/target/${ARCHITECTURE}/${LIB_DIR}/libmopro_ffi.a ${TARGET_DIR}/

# TODO: Also include export command, separate fro mthis probably
print_action "Copying Swift bindings and static library to MoproKit..."
cp ${TARGET_DIR}/SwiftBindings/moproFFI.h ${MOPROKIT_DIR}/Include/
cp ${TARGET_DIR}/SwiftBindings/mopro.swift ${MOPROKIT_DIR}/Bindings/
cp ${TARGET_DIR}/SwiftBindings/moproFFI.modulemap ${MOPROKIT_DIR}/Resources/
cp ${TARGET_DIR}/libmopro_ffi.a ${MOPROKIT_DIR}/Libs/

# TODO: Improve CLI, positional arguments a bit messy
# Dylib assets
if [[ "$USE_DYLIB" == true ]]; then
    print_action "Copying dynamic library asset (${DYLIB_NAME})..."
    cp "${PROJECT_DIR}/target/${ARCHITECTURE}/${LIB_DIR}/${DYLIB_NAME}" "${TARGET_DIR}/"
    cp "${TARGET_DIR}/${DYLIB_NAME}" "${MOPROKIT_DIR}/Libs/"
    # Fix dynamic lib install paths
    # NOTE: Xcode might already do this for us; verify this
    install_name_tool -id "@rpath/${DYLIB_NAME}" "${MOPROKIT_DIR}/Libs/${DYLIB_NAME}"
    codesign -f -s "${APPLE_SIGNING_IDENTITY}" "${MOPROKIT_DIR}/Libs/${DYLIB_NAME}"
fi

print_action "Done! Please re-build your project in Xcode."