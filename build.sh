#!/bin/bash

cd "$(dirname "${0}")"
BUILD_DIR="$(pwd)"
cd ->/dev/null

# Overridable build locations
: ${DEFAULT_ZLIB_DIST:="${BUILD_DIR}/zlib"}
: ${OBJDIR_ROOT:="${BUILD_DIR}/target"}
: ${CONFIGS_DIR:="${BUILD_DIR}/configs"}
: ${MAKE_BUILD_PARALLEL:=$(sysctl -n hw.ncpu)}

# Include files which are platform-specific
PLATFORM_SPECIFIC_HEADERS="zconf.h"

print_usage() {
    while [ $# -gt 0 ]; do
        echo "${1}" >&2
        shift 1
        if [ $# -eq 0 ]; then echo "" >&2; fi
    done
    echo "Usage: ${0} [/path/to/zlib-dist] <'copy-windows'|package>"                                        >&2
    echo ""                                                                                                 >&2
    echo "\"/path/to/zlib-dist\" is optional and defaults to:"                                              >&2
    echo "    \"${DEFAULT_ZLIB_DIST}\""                                                                     >&2
    echo ""                                                                                                 >&2
    echo "You can copy the windows outputs to non-windows target directory by running"                      >&2
    echo "\"${0} copy-windows /path/to/windows/target"                                                      >&2
    echo ""                                                                                                 >&2
    echo "You can specify to package the release (after it's already been built) by"                        >&2
    echo "running \"${0} package /path/to/output"                                                           >&2
    echo ""                                                                                                 >&2
    return 1
}

do_copy_windows() {
    [ -d "${1}" ] || {
        print_usage "Invalid windows target directory:" "    \"${1}\""
        exit $?
    }
    mkdir -p "${OBJDIR_ROOT}"
    for WIN_PLAT in $(ls "${1}" | grep 'objdir-windows'); do
        [ -d "${1}/${WIN_PLAT}" -a -d "${1}/${WIN_PLAT}/lib" ] && {
            echo "Copying ${WIN_PLAT}..."
            rm -rf "${OBJDIR_ROOT}/${WIN_PLAT}" || exit $?
            mkdir -p "${OBJDIR_ROOT}/${WIN_PLAT}" || exit $?
            cp -r "${1}/${WIN_PLAT}/lib" "${OBJDIR_ROOT}/${WIN_PLAT}/lib" || exit $?
            cp -r "${1}/${WIN_PLAT}/include" "${OBJDIR_ROOT}/${WIN_PLAT}/include" || exit $?
        } || {
            print_usage "Invalid build target:" "    \"${1}\""
            exit $?
        }
    done
}

do_combine_headers() {
    # Combine the headers into a top-level location
    COMBINED_HEADERS="${OBJDIR_ROOT}/include"
    rm -rf "${COMBINED_HEADERS}"
    mkdir -p "${COMBINED_HEADERS}" || return $?
    COMBINED_PLATS="windows.i386 windows.x86_64"
    for p in ${COMBINED_PLATS}; do
        _P_INC="${OBJDIR_ROOT}/objdir-${p}/include"
        if [ -d "${_P_INC}" ]; then
            cp -r "${_P_INC}/"* ${COMBINED_HEADERS} || return $?
        else
            echo "Platform ${p} has not been built"
            return 1
        fi
    done
    for h in ${PLATFORM_SPECIFIC_HEADERS}; do
        echo "Combining header '${h}'..."
        if [ -f "${COMBINED_HEADERS}/${h}" ]; then
            rm "${COMBINED_HEADERS}/${h}" || return $?
            for p in ${COMBINED_PLATS}; do
                _P_INC="${OBJDIR_ROOT}/objdir-${p}/include"
                if [ -f "${_P_INC}/${h}" ]; then
                    cat "${_P_INC}/${h}" >> "${COMBINED_HEADERS}/${h}" || return $?
                fi
            done
        fi
    done
    find "${OBJDIR_ROOT}/include" -type f -exec dos2unix {} \; || return $?
}

do_package() {
    [ -d "${1}" ] || {
        print_usage "Invalid package output directory:" "    \"${1}\""
        exit $?
    }
    
    # Combine the headers (checks that everything is already built)
    do_combine_headers || return $?
    
    # Build the tarball
    BASE="zlib-$(grep '^set(VERSION' "${PATH_TO_ZLIB_DIST}/CMakeLists.txt" | cut -d'"' -f2 | sed -e 's/ *//g')"
    cp -r "${OBJDIR_ROOT}" "${BASE}" || exit $?
    rm -rf "${BASE}/"*"/build" || exit $?
    find "${BASE}" -name .DS_Store -exec rm {} \; || exit $?
    tar -zcvpf "${1}/${BASE}.tar.gz" "${BASE}" || exit $?
    rm -rf "${BASE}"
}

# Calculate the path to the zlib-dist repository
if [ -d "${1}" ]; then
    cd "${1}"
    PATH_TO_ZLIB_DIST="$(pwd)"
    cd ->/dev/null
    shift 1
else
    PATH_TO_ZLIB_DIST="${DEFAULT_ZLIB_DIST}"
fi
[ -d "${PATH_TO_ZLIB_DIST}" -a -f "${PATH_TO_ZLIB_DIST}/CMakeLists.txt" ] || {
    print_usage "Invalid ZLib directory:" "    \"${PATH_TO_ZLIB_DIST}\""
    exit $?
}

# Call the appropriate function based on target
TARGET="${1}"; shift
case "${TARGET}" in
    "copy-windows")
        do_copy_windows $@
        ;;
    "package")
        do_package $@
        ;;
    *)
        print_usage
        ;;
esac
exit $?
