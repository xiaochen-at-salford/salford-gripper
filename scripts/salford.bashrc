#!/usr/bin/env bash

CATKIN_ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
CATKIN_IN_DOCKER=false

# If inside docker container
if [ -f /.dockerenv ]; then
  CATKIN_IN_DOCKER=true
  CATKIN_ROOT_DIR="/home/hhkb/catkin_ws"
fi

export CATKIN_ROOT_DIR="${WS_ROOT_DIR}"
export CATKIN_IN_DOCKER="${WS_IN_DOCKER}"
# export APOLLO_CACHE_DIR="${APOLLO_ROOT_DIR}/.cache"
# export APOLLO_SYSROOT_DIR="/opt/apollo/sysroot"

export TAB="    " # 4 spaces
: ${VERBOSE:=yes}

BOLD='\033[1m'
RED='\033[0;31m'
BLUE='\033[0;34m'
GREEN='\033[32m'
WHITE='\033[34m'
YELLOW='\033[33m'
NO_COLOR='\033[0m'

function info() 
{
  (echo >&2 -e "[${WHITE}${BOLD}INFO${NO_COLOR}] $*")
}

function error() 
{
  (echo >&2 -e "[${RED}ERROR${NO_COLOR}] $*")
}

function warning() 
{
  (echo >&2 -e "${YELLOW}[WARNING] $*${NO_COLOR}")
}

function ok() 
{
  (echo >&2 -e "[${GREEN}${BOLD} OK ${NO_COLOR}] $*")
}

function print_delim() 
{
  echo "=============================================="
}

function get_now() 
{
  date +%s
}

function time_elapsed_s() 
{
  local start="${1:-$(get_now)}"
  local end="$(get_now)"
  echo "$end - $start" | bc -l
}

function success() {
  print_delim
  ok "$1"
  print_delim
}

function fail() {
  print_delim
  error "$1"
  print_delim
  exit 1
}


function file_ext() {
  local filename="$(basename $1)"
  local actual_ext="${filename##*.}"
  if [[ "${actual_ext}" == "${filename}" ]]; then
    actual_ext=""
  fi
  echo "${actual_ext}"
}

function c_family_ext() {
  local actual_ext
  actual_ext="$(file_ext $1)"
  for ext in "h" "hh" "hxx" "hpp" "cxx" "cc" "cpp" "cu"; do
    if [[ "${ext}" == "${actual_ext}" ]]; then
      return 0
    fi
  done
  return 1
}

function find_c_cpp_srcs() {
  find "$@" -type f -name "*.h" \
    -o -name "*.c" \
    -o -name "*.hpp" \
    -o -name "*.cpp" \
    -o -name "*.hh" \
    -o -name "*.cc" \
    -o -name "*.hxx" \
    -o -name "*.cxx" \
    -o -name "*.cu"
}

function proto_ext() {
  if [[ "$(file_ext $1)" == "proto" ]]; then
    return 0
  else
    return 1
  fi
}

function find_proto_srcs() {
  find "$@" -type f -name "*.proto"
}

function py_ext() {
  if [[ "$(file_ext $1)" == "py" ]]; then
    return 0
  else
    return 1
  fi
}

function find_py_srcs() {
  find "$@" -type f -name "*.py"
}

function bash_ext() {
  local actual_ext
  actual_ext="$(file_ext $1)"
  for ext in "sh" "bash" "bashrc"; do
    if [[ "${ext}" == "${actual_ext}" ]]; then
      return 0
    fi
  done
  return 1
}

function bazel_extended() {
  local actual_ext="$(file_ext $1)"
  if [[ -z "${actual_ext}" ]]; then
    if [[ "${arg}" == "BUILD" || "${arg}" == "WORKSPACE" ]]; then
      return 0
    else
      return 1
    fi
  else
    for ext in "BUILD" "bazel" "bzl"; do
      if [[ "${ext}" == "${actual_ext}" ]]; then
        return 0
      fi
    done
    return 1
  fi
}

function prettier_ext() {
  local actual_ext
  actual_ext="$(file_ext $1)"
  for ext in "md" "json" "yml"; do
    if [[ "${ext}" == "${actual_ext}" ]]; then
      return 0
    fi
  done
  return 1
}

function find_prettier_srcs() {
  find "$@" -type f -name "*.md" \
    -or -name "*.json" \
    -or -name "*.yml"
}

## Prevent multiple entries of my_bin_path in PATH
function add_to_path() {
  if [ -z "$1" ]; then
    return
  fi
  local my_bin_path="$1"
  if [ -n "${PATH##*${my_bin_path}}" ] && [ -n "${PATH##*${my_bin_path}:*}" ]; then
    export PATH=$PATH:${my_bin_path}
  fi
}

## Prevent multiple entries of my_libdir in LD_LIBRARY_PATH
function add_to_ld_library_path() {
  if [ -z "$1" ]; then
    return
  fi
  local my_libdir="$1"
  local result="${LD_LIBRARY_PATH}"
  if [ -z "${result}" ]; then
    result="${my_libdir}"
  elif [ -n "${result##*${my_libdir}}" ] && [ -n "${result##*${my_libdir}:*}" ]; then
    result="${result}:${my_libdir}"
  fi
  export LD_LIBRARY_PATH="${result}"
}

# Exits the script if the command fails.
function run() {
  if [ "${VERBOSE}" = yes ]; then
    echo "${@}"
    "${@}" || exit $?
  else
    local errfile="${APOLLO_ROOT_DIR}/.errors.log"
    echo "${@}" >"${errfile}"
    if ! "${@}" >>"${errfile}" 2>&1; then
      local exitcode=$?
      cat "${errfile}" 1>&2
      exit $exitcode
    fi
  fi
}

#commit_id=$(git log -1 --pretty=%H)
function git_sha1() {
  if [ -x "$(which git 2>/dev/null)" ] &&
    [ -d "${APOLLO_ROOT_DIR}/.git" ]; then
    git rev-parse --short HEAD 2>/dev/null || true
  fi
}

function git_date() {
  if [ -x "$(which git 2>/dev/null)" ] &&
    [ -d "${APOLLO_ROOT_DIR}/.git" ]; then
    git log -1 --pretty=%ai | cut -d " " -f 1 || true
  fi
}

function git_branch() {
  if [ -x "$(which git 2>/dev/null)" ] &&
    [ -d "${APOLLO_ROOT_DIR}/.git" ]; then
    git rev-parse --abbrev-ref HEAD
  else
    echo "@non-git"
  fi
}

function read_one_char_from_stdin() {
  local answer
  read -r -n1 answer
  # Bash 4.x+: ${answer,,} to lowercase, ${answer^^} to uppercase
  echo "${answer}" | tr '[:upper:]' '[:lower:]'
}

function optarg_check_for_opt() {
  local opt="$1"
  local optarg="$2"
  ! [[ -z "${optarg}" || "${optarg}" =~ ^-.* ]]
}
