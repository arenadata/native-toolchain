#!/usr/bin/env bash
set -x

usage() {
  echo "
usage: $0 <options>
  Required not-so-options:
     --file-search-version=FILE  specify the path to the file from which you plan to pull the packages versions
     ... [ see source for more similar options ]
  "
  exit 1
}

OPTS=$(getopt \
  -n $0 \
  -o '' \
  -l 'file-search-version:' -- "$@")

if [ $? != 0 ] ; then
    usage
fi

eval set -- "$OPTS"
while true ; do
    case "$1" in
        --file-search-version)
        FILE_SEARCH_VERSION=$2 ; shift 2
        ;;
        --)
        shift ; break
        ;;
        *)
        echo "Unknown option: $1"
        usage
        exit 1
        ;;
    esac
done

for var in FILE_SEARCH_VERSION; do
  if [ -z "$(eval "echo \$$var")" ]; then
    echo Missing param: $var
    usage
  fi
done

function download_dependency() {
  # S3 Base URL
  local S3_BASE_PREFIX="https://native-toolchain.s3.amazonaws.com/source"
  download_url "${S3_BASE_PREFIX}/${1}/${2}" "${3}/${2}"
}

# Downloads a URL (first arg) to a given location (second arg). If a file already exists
# at the location, the download will not be attempted.
function download_url() {
  local URL=$1
  local OUTPUT_PATH="${2-$(basename $URL)}"
  if [[ ! -f "$OUTPUT_PATH" ]]; then
    ARGS=(--progress=dot:giga)
    if [[ $DEBUG -eq 0 ]]; then
      ARGS+=(-q)
    fi
    if [[ -n "$OUTPUT_PATH" ]]; then
      ARGS+=(-O "$OUTPUT_PATH")
    fi
    ARGS+=("$URL")
    wget "${ARGS[@]}"
  fi
}

[ -e $(pwd)/package_version ] && rm -rf $(pwd)/package_version
[ -e $(pwd)/package_name ] && rm -rf $(pwd)/package_name

for file in $FILE_SEARCH_VERSION
do
    cat $file | grep ".*_VERSION" | sed -e 's/export -n.*//g' \
        -e 's/#     pattern:.*//' \
        -e 's/export//g' \
        -e 's/$SOURCE_DIR.*//g' \
        -e 's/\\//g' \
        -e 's/[[:space:]]//g' \
        -e '/^$/d' \
        -e 's|GLOG_VERSION|\nGLOG_VERSION|' \
        -e 's|-p.*||' | sort -u >> package_version
    echo "BINUTILS_VERSION=2.35.1" >> package_version
    echo "GDB_VERSION=12.1" >> package_version
    echo "CMAKE_VERSION=3.22.2" >> package_version
    echo "GCC_VERSION=10.4.0" >> package_version
    echo "MPFR_VERSION=3.1.4" >> package_version
    echo "GMP_VERSION=6.1.0" >> package_version
    echo "MPC_VERSION=1.0.3" >> package_version
    echo "ISL_VERSION=0.18" >> package_version
    echo "CLOOG_VERSION=0.18.1" >> package_version
done

ls source > package_name
echo "gdb" >> package_name
echo "mpfr" >> package_name
echo "gmp" >> package_name
echo "mpc" >> package_name
echo "isl" >> package_name
echo "cloog" >> package_name

mkdir packages-sources
S3_BASE_PREFIX="https://native-toolchain.s3.amazonaws.com/source"

for pkg_name in $(cat package_name)
do
    val=$(echo $pkg_name | tr [:lower:] [:upper:])
    grep $val package_version
    for pkg_version in $(grep $val package_version | cut -d= -f2)
    do
        for expansion in tgz tar.xz tar.gz tar.gz2 zip
        do
          mkdir packages-sources/$pkg_name
          if [ "$pkg_name" == "avro" ]; then
            wget "${S3_BASE_PREFIX}/$pkg_name/$pkg_name-src-$pkg_version.$expansion" --directory-prefix=packages-sources/$pkg_name
          else
            wget "${S3_BASE_PREFIX}/$pkg_name/$pkg_name-$pkg_version.$expansion" --directory-prefix=packages-sources/$pkg_name
          fi
        done
    done
done
