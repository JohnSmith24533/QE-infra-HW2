#!/usr/bin/env bash
# Build and install Quantum ESPRESSO whether this script is inside q-e or beside it.
# This script is independent of the caller's current working directory.

set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
if [[ -n "${QE_SOURCE_DIR:-}" ]]; then
    SOURCE_DIR="${QE_SOURCE_DIR}"
    WORK_ROOT="${SCRIPT_DIR}"
elif [[ -f "${SCRIPT_DIR}/configure" && -f "${SCRIPT_DIR}/CMakeLists.txt" ]]; then
    SOURCE_DIR="${SCRIPT_DIR}"
    WORK_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd -P)"
else
    SOURCE_DIR="${SCRIPT_DIR}/q-e"
    WORK_ROOT="${SCRIPT_DIR}"
fi
readonly SOURCE_DIR WORK_ROOT
readonly BUILD_DIR="${QE_BUILD_DIR:-${WORK_ROOT}/build-make}"
readonly INSTALL_PREFIX="${QE_INSTALL_PREFIX:-${WORK_ROOT}/install}"
readonly GCC_MODULE="${QE_GCC_MODULE:-gcc/10.4.0}"
readonly MPI_MODULE="${QE_MPI_MODULE:-openmpi/5.0.2}"

log()   { printf '[qe-install] %s\n' "$*"; }
fatal() { printf '[qe-install] ERROR: %s\n' "$*" >&2; exit 1; }

on_error() {
    local status=$?
    printf '[qe-install] ERROR: command failed at line %s (exit %s)\n' \
        "${BASH_LINENO[0]}" "${status}" >&2
    exit "${status}"
}
trap on_error ERR

initialize_modules() {
    if ! type module >/dev/null 2>&1; then
        local init
        for init in /etc/profile.d/modules.sh /usr/share/Modules/init/bash /usr/share/lmod/lmod/init/bash; do
            if [[ -r "${init}" ]]; then
                # shellcheck disable=SC1090
                source "${init}"
                break
            fi
        done
    fi
    type module >/dev/null 2>&1 || fatal \
        "the environment-modules command is unavailable; initialize Lmod/Modules and retry"
}

load_toolchain() {
    initialize_modules

    module is-avail "${GCC_MODULE}" 2>/dev/null || fatal \
        "required module '${GCC_MODULE}' is unavailable"
    module load "${GCC_MODULE}"

    # The GCC module adds its matching MPI module directory to MODULEPATH.
    module is-avail "${MPI_MODULE}" 2>/dev/null || fatal \
        "required module '${MPI_MODULE}' is unavailable after loading '${GCC_MODULE}'"
    module load "${MPI_MODULE}"
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || fatal "required command '$1' was not found in PATH"
}

choose_jobs() {
    if [[ -n "${QE_JOBS:-}" ]]; then
        [[ "${QE_JOBS}" =~ ^[1-9][0-9]*$ ]] || fatal "QE_JOBS must be a positive integer"
        printf '%s\n' "${QE_JOBS}"
        return
    fi

    local jobs=1
    if command -v nproc >/dev/null 2>&1; then
        jobs="$(nproc)"
    elif command -v getconf >/dev/null 2>&1; then
        jobs="$(getconf _NPROCESSORS_ONLN 2>/dev/null || printf '1')"
    fi

    # Avoid unexpectedly consuming an entire shared login node. Override with QE_JOBS.
    (( jobs > 8 )) && jobs=8
    printf '%s\n' "${jobs}"
}

[[ -f "${SOURCE_DIR}/CMakeLists.txt" ]] || fatal \
    "Quantum ESPRESSO source tree not found at '${SOURCE_DIR}'"
[[ -w "${WORK_ROOT}" ]] || fatal "working directory '${WORK_ROOT}' is not writable"

load_toolchain
for tool in make git mpicc mpifort; do
    require_command "${tool}"
done

jobs="$(choose_jobs)"

log "source:  ${SOURCE_DIR}"
log "build:   ${BUILD_DIR}"
log "prefix:  ${INSTALL_PREFIX}"
log "jobs:    ${jobs}"
log "C:       $(command -v mpicc)"
log "Fortran: $(command -v mpifort)"

if [[ -f "${SOURCE_DIR}/.gitmodules" ]]; then
    log "initializing required git submodules"
    git -C "${SOURCE_DIR}" submodule update --init --recursive
fi

if [[ "${QE_CLEAN_BUILD:-0}" == "1" ]]; then
    case "${BUILD_DIR}" in
        /|"${SCRIPT_DIR}"|"${SOURCE_DIR}")
            fatal "refusing to clean unsafe build directory '${BUILD_DIR}'"
            ;;
    esac
    log "removing the previous build tree"
    rm -rf -- "${BUILD_DIR}"
fi

mkdir -p "${BUILD_DIR}" "${INSTALL_PREFIX}"

log "configuring Quantum ESPRESSO"
configure_options=(
    "--prefix=${INSTALL_PREFIX}"
    --enable-parallel
    --with-scalapack=no
)
if [[ "${QE_ENABLE_OPENMP:-1}" == "1" ]]; then
    configure_options+=(--enable-openmp)
fi
(
    cd "${BUILD_DIR}"
    CC="$(command -v mpicc)" \
    FC="$(command -v mpifort)" \
    F77="$(command -v mpifort)" \
    MPIF90="$(command -v mpifort)" \
        "${SOURCE_DIR}/configure" "${configure_options[@]}"
)

log "building Quantum ESPRESSO"
make -C "${BUILD_DIR}" -j "${jobs}" ${QE_MAKE_TARGETS:-all}

log "installing Quantum ESPRESSO"
make -C "${BUILD_DIR}" install

[[ -x "${INSTALL_PREFIX}/bin/pw.x" ]] || fatal \
    "installation finished but '${INSTALL_PREFIX}/bin/pw.x' is missing"

log "installation completed successfully"
log "executables: ${INSTALL_PREFIX}/bin"
log "for this shell: export PATH=\"${INSTALL_PREFIX}/bin:\${PATH}\""
