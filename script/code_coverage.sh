#!/usr/bin/env bash

set -e
#set -x

main() {
  if ! [[ -d .git ]]; then printError "Error: not in root of repo\n"; show_help; fi

  case $1 in
    --help)
        show_help
        ;;
    --report)
        runReport
        ;;
    *)
        runTests
        ;;
  esac
}

show_help() {
    printf "usage: %s [--help] [--report]

Tool for running tests with code coverage.
(run from root of repo)

where:

    --report
        run a coverage report (run code coverage first)
        (requires lcov installed)
    --help
        print this message

requires coverage package
(install with 'pub global activate coverage')
" "$(basename "$0")"
    exit 1
}

# run tests with code coverage
runTests () {
  local test_path="test/all_tests.dart"
  local coverage_dir="coverage"
  # clear coverage directory
  rm -rf "$coverage_dir"
  mkdir "$coverage_dir"

  OBS_PORT=9292

  # Run the coverage collector to generate the JSON coverage report.
  echo "Listening for coverage report on port $OBS_PORT..."
  pub global run coverage:collect_coverage \
    --port=$OBS_PORT \
    --out="$coverage_dir"/coverage.json \
    --wait-paused \
    --resume-isolates &

  # Start tests in one VM.
  echo "Running tests with code coverage..."
  dart --disable-service-auth-codes \
    --enable-vm-service=$OBS_PORT \
    --pause-isolates-on-exit \
    "$test_path"

  echo "Generating LCOV report..."
  pub global run coverage:format_coverage \
    --lcov \
    --in="$coverage_dir"/coverage.json \
    --out="$coverage_dir"/lcov.info \
    --packages=.packages \
    --report-on=lib
}

runReport() {
  if [[ -f "coverage/lcov.info" ]]; then
    genhtml -o coverage coverage/lcov.info --no-function-coverage -q
    open coverage/index.html
  else
    printError "Error: coverage has not been run.\n"
    show_help
  fi
}

printError() {
  local msg=$1
  local red
  local none
  # output in red
  red=$(tput setaf 1)
  none=$(tput sgr0)
  printf "%s$msg%s" "${red}" "${none}"
}

main "$@"