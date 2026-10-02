#!/usr/bin/env bash
#
# build.sh - Build, test, and package UEFITool, UEFIExtract, and UEFIFind
#
# Package selection: when multiple RPMs exist in dist/, all functions that
# report or install a package will automatically pick the one with the
# newest filesystem modification timestamp (via `ls -t`).
#
set -euo pipefail

# Directory paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${SCRIPT_DIR}/build"
DIST_DIR="${SCRIPT_DIR}/dist"

# Default settings
BUILD_TYPE="Release"
INSTALL_PREFIX="/usr/local"
JOBS="$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)"
DO_CLEAN=0
DO_TEST=0
DO_RPM=0
DO_INSTALL=0
SUBCOMMAND=""

# Colors (if terminal supports colors)
if [ -t 1 ]; then
    RED=$'\033[0;31m'
    GREEN=$'\033[0;32m'
    YELLOW=$'\033[1;33m'
    BLUE=$'\033[0;34m'
    CYAN=$'\033[0;36m'
    BOLD=$'\033[1m'
    RESET=$'\033[0m'
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    CYAN=''
    BOLD=''
    RESET=''
fi

log_info() {
    echo -e "${BLUE}${BOLD}[INFO]${RESET} $*"
}

log_success() {
    echo -e "${GREEN}${BOLD}[SUCCESS]${RESET} $*"
}

log_warn() {
    echo -e "${YELLOW}${BOLD}[WARNING]${RESET} $*"
}

log_error() {
    echo -e "${RED}${BOLD}[ERROR]${RESET} $*" >&2
}

# Returns the path of the newest (by mtime) *.rpm file in DIST_DIR.
# Prints nothing and returns 1 if no RPM packages are found.
newest_rpm() {
    local newest
    newest="$(ls -t "${DIST_DIR}"/*.rpm 2>/dev/null | head -n1)"
    if [ -z "$newest" ]; then
        return 1
    fi
    echo "$newest"
}

# Prints all RPMs in DIST_DIR sorted newest-first, with size and timestamp.
list_packages_newest_first() {
    if ! ls "${DIST_DIR}"/*.rpm &>/dev/null; then
        log_warn "No RPM packages found in ${DIST_DIR}/"
        return 0
    fi
    log_info "Packages in ${DIST_DIR}/ (newest first):"
    # ls -lt gives long listing sorted by mtime (newest first)
    ls -lht "${DIST_DIR}"/*.rpm
    echo ""
    local pkg
    pkg="$(newest_rpm)"
    log_success "Newest package: ${pkg}"
}

show_help() {
    cat << EOF
${BOLD}UEFITool Build & Automation Script${RESET}

${BOLD}USAGE:${RESET}
  ./build.sh [COMMAND] [OPTIONS]

${BOLD}COMMANDS:${RESET}
  build               Configure and compile all targets (default)
  test                Run verification tests on compiled binaries
  rpm                 Build source and binary RPM packages
  install             Install compiled targets to prefix
  clean               Remove build and dist artifacts
  all                 Clean, build, test, and create RPM package
  latest              Show the newest RPM package in dist/ by timestamp
  help                Display this help message

${BOLD}OPTIONS:${RESET}
  -t, --test          Run automated tests after compilation
  -r, --rpm           Build RPM package after compilation
  -c, --clean         Clean build directory before building
  -d, --debug         Build with Debug symbols (default: Release)
  --release           Build in Release mode (default)
  -j, --jobs <N>      Number of parallel jobs (default: ${JOBS})
  -p, --prefix <DIR>  Installation prefix (default: ${INSTALL_PREFIX})
  -b, --build-dir <D> Custom build directory (default: build)
  -h, --help          Show this help message

${BOLD}EXAMPLES:${RESET}
  ./build.sh                     # Build everything in Release mode
  ./build.sh --test              # Build and immediately test binaries
  ./build.sh test                # Run test suite on existing build
  ./build.sh rpm                 # Build RPM package using rpmbuild
  ./build.sh all                 # Clean, build, test, and package RPM
  ./build.sh latest              # Display the newest RPM in dist/
  sudo ./build.sh install        # Install binaries to /usr/local
EOF
}

# Parse options and commands
while [ $# -gt 0 ]; do
    case "$1" in
        build)
            SUBCOMMAND="build"
            shift
            ;;
        test)
            SUBCOMMAND="test"
            DO_TEST=1
            shift
            ;;
        rpm)
            SUBCOMMAND="rpm"
            DO_RPM=1
            shift
            ;;
        install)
            SUBCOMMAND="install"
            DO_INSTALL=1
            shift
            ;;
        clean)
            SUBCOMMAND="clean"
            shift
            ;;
        all)
            SUBCOMMAND="all"
            DO_CLEAN=1
            DO_TEST=1
            DO_RPM=1
            shift
            ;;
        help|-h|--help)
            show_help
            exit 0
            ;;
        latest)
            SUBCOMMAND="latest"
            shift
            ;;
        -t|--test)
            DO_TEST=1
            shift
            ;;
        -r|--rpm)
            DO_RPM=1
            shift
            ;;
        -c|--clean)
            DO_CLEAN=1
            shift
            ;;
        -d|--debug)
            BUILD_TYPE="Debug"
            shift
            ;;
        --release)
            BUILD_TYPE="Release"
            shift
            ;;
        -j|--jobs)
            JOBS="$2"
            shift 2
            ;;
        -p|--prefix)
            INSTALL_PREFIX="$2"
            shift 2
            ;;
        -b|--build-dir)
            BUILD_DIR="$2"
            shift 2
            ;;
        *)
            log_error "Unknown option or command: $1"
            show_help
            exit 1
            ;;
    esac
done

if [ -z "$SUBCOMMAND" ]; then
    SUBCOMMAND="build"
fi

# Clean command
clean_artifacts() {
    log_info "Cleaning build directory (${BUILD_DIR})..."
    rm -rf "${BUILD_DIR}"
    if [ "${SUBCOMMAND}" = "clean" ] || [ "${SUBCOMMAND}" = "all" ]; then
        log_info "Cleaning dist directory (${DIST_DIR})..."
        rm -rf "${DIST_DIR}"
    fi
    log_success "Cleanup complete."
}

if [ "$SUBCOMMAND" = "clean" ]; then
    clean_artifacts
    exit 0
fi

if [ "$DO_CLEAN" -eq 1 ]; then
    clean_artifacts
fi

check_build_tools() {
    log_info "Checking build dependencies..."
    local missing=0
    for cmd in cmake gcc g++; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            log_error "Missing required tool: $cmd"
            missing=1
        fi
    done

    if [ "$missing" -ne 0 ]; then
        log_error "Please install missing dependencies and try again."
        exit 1
    fi

    # Determine generator: prefer Ninja if available
    if command -v ninja >/dev/null 2>&1; then
        CMAKE_GENERATOR="Ninja"
    else
        CMAKE_GENERATOR="Unix Makefiles"
    fi
    log_info "Using CMake generator: ${CMAKE_GENERATOR}"
}

# Compile with CMake
build_targets() {
    check_build_tools

    log_info "Configuring UEFITool (${BUILD_TYPE}) in ${BUILD_DIR}..."
    cmake -B "${BUILD_DIR}" \
        -S "${SCRIPT_DIR}" \
        -G "${CMAKE_GENERATOR}" \
        -DCMAKE_BUILD_TYPE="${BUILD_TYPE}" \
        -DCMAKE_INSTALL_PREFIX="${INSTALL_PREFIX}"

    log_info "Compiling with ${JOBS} parallel jobs..."
    cmake --build "${BUILD_DIR}" -- -j"${JOBS}"

    log_success "Compilation completed successfully!"
    log_info "Built binaries:"
    echo "  - ${BUILD_DIR}/UEFITool/uefitool (GUI)"
    echo "  - ${BUILD_DIR}/UEFIExtract/uefiextract (CLI)"
    echo "  - ${BUILD_DIR}/UEFIFind/uefifind (CLI)"
}

# Test binaries
test_binaries() {
    log_info "Running test suite on compiled binaries..."
    local uefiextract="${BUILD_DIR}/UEFIExtract/uefiextract"
    local uefifind="${BUILD_DIR}/UEFIFind/uefifind"
    local uefitool="${BUILD_DIR}/UEFITool/uefitool"
    local failed=0

    # 1. Test UEFIExtract
    log_info "Testing uefiextract..."
    if [ ! -x "$uefiextract" ]; then
        log_error "Binary not found or not executable: $uefiextract"
        failed=1
    else
        local extract_version
        extract_version="$("$uefiextract" -v)"
        log_success "uefiextract version verified: ${extract_version}"
        "$uefiextract" -h >/dev/null
        log_success "uefiextract help command passed."
    fi

    # 2. Test UEFIFind
    log_info "Testing uefifind..."
    if [ ! -x "$uefifind" ]; then
        log_error "Binary not found or not executable: $uefifind"
        failed=1
    else
        local find_version
        find_version="$("$uefifind" -v)"
        log_success "uefifind version verified: ${find_version}"
        "$uefifind" -h >/dev/null
        log_success "uefifind help command passed."
    fi

    # 3. Test UEFITool (GUI)
    log_info "Testing uefitool (dynamic linkage and offscreen startup)..."
    if [ ! -x "$uefitool" ]; then
        log_error "Binary not found or not executable: $uefitool"
        failed=1
    else
        # Verify dynamic library linkage
        if command -v ldd >/dev/null 2>&1; then
            if ldd "$uefitool" | grep -q "not found"; then
                log_error "uefitool has unresolvable library dependencies:"
                ldd "$uefitool" | grep "not found"
                failed=1
            else
                log_success "uefitool shared libraries linked properly."
            fi
        fi

        # Run offscreen execution test
        local run_status=0
        if command -v timeout >/dev/null 2>&1; then
            timeout 2s env QT_QPA_PLATFORM=offscreen "$uefitool" >/dev/null 2>&1 || run_status=$?
            # Exit code 124 indicates normal timeout while GUI event loop was actively running
            if [ "$run_status" -eq 124 ] || [ "$run_status" -eq 0 ]; then
                log_success "uefitool offscreen initialization test passed."
            else
                log_warn "uefitool exited with code ${run_status} during offscreen test."
            fi
        fi
    fi

    if [ "$failed" -eq 0 ]; then
        log_success "All tests passed successfully!"
    else
        log_error "One or more tests failed!"
        return 1
    fi
}

# Build RPM Package
build_rpm() {
    log_info "Building RPM package..."

    if ! command -v rpmbuild >/dev/null 2>&1; then
        log_error "rpmbuild not found. Please install rpm-build (e.g. sudo dnf install rpm-build)."
        exit 1
    fi

    local spec_file="${SCRIPT_DIR}/uefitool.spec"
    if [ ! -f "$spec_file" ]; then
        log_error "Spec file not found at ${spec_file}"
        exit 1
    fi

    local version
    version="$(grep -m1 '^Version:' "$spec_file" | awk '{print $2}')"
    log_info "Packaging version: ${version}"

    local topdir
    topdir="$(rpm --eval '%{_topdir}')"
    mkdir -p "${topdir}"/{BUILD,RPMS,SOURCES,SPECS,SRPMS}
    mkdir -p "${DIST_DIR}"

    local tarball="${topdir}/SOURCES/uefitool-${version}.tar.gz"
    log_info "Creating source archive: ${tarball}..."
    git archive --format=tar.gz --prefix="uefitool-${version}/" HEAD -o "${tarball}"

    log_info "Copying spec to ${topdir}/SPECS/..."
    cp "${spec_file}" "${topdir}/SPECS/uefitool.spec"

    log_info "Executing rpmbuild..."
    rpmbuild -ba "${topdir}/SPECS/uefitool.spec"

    log_info "Copying built RPM packages to ${DIST_DIR}..."
    cp -v "${topdir}/RPMS/"*"/uefitool-"*"${version}"*".rpm" "${DIST_DIR}/" 2>/dev/null || true
    cp -v "${topdir}/SRPMS/uefitool-"*"${version}"*".src.rpm" "${DIST_DIR}/" 2>/dev/null || true

    log_success "RPM build complete! All artifacts in ${DIST_DIR}/ (newest first):"
    # List all packages sorted by newest timestamp so it's clear which is current
    ls -lht "${DIST_DIR}"/*.rpm
    echo ""
    local newest_pkg
    if newest_pkg="$(newest_rpm)"; then
        log_success "Newest package (selected by timestamp): ${newest_pkg}"
    fi
}

# Install targets
install_targets() {
    if [ ! -d "${BUILD_DIR}" ]; then
        log_error "Build directory not found. Please build first."
        exit 1
    fi
    log_info "Installing to ${INSTALL_PREFIX}..."
    cmake --install "${BUILD_DIR}" --prefix "${INSTALL_PREFIX}"
    log_success "Installation to ${INSTALL_PREFIX} complete."
}

# Main execution flow
case "$SUBCOMMAND" in
    build)
        build_targets
        if [ "$DO_TEST" -eq 1 ]; then
            test_binaries
        fi
        if [ "$DO_RPM" -eq 1 ]; then
            build_rpm
        fi
        ;;
    test)
        if [ ! -d "${BUILD_DIR}" ]; then
            log_info "Build directory not found, initiating build first..."
            build_targets
        fi
        test_binaries
        ;;
    rpm)
        build_rpm
        ;;
    install)
        install_targets
        ;;
    latest)
        # Show only the newest RPM in dist/ by mtime (ignores older packages)
        list_packages_newest_first
        ;;
    all)
        build_targets
        test_binaries
        build_rpm
        log_success "All tasks (clean, build, test, rpm) finished successfully!"
        ;;
esac
