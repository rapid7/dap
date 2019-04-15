TEST_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

load "${TEST_DIR}/test_helper/bats-support/load.bash"
load "${TEST_DIR}/test_helper/bats-assert/load.bash"

function setup_workdir() {
  WORK_DIR=`mktemp -d /tmp/output.XXXXXX`
}

function teardown_workdir() {
  cd
  if [ -z "${DISABLE_BATS_TEARDOWN}" ]; then
    test -d $WORK_DIR && rm -Rf $WORK_DIR
  fi
}

function setup() {
  export PATH=/go/bin:/usr/local/go/bin:$PATH
  setup_workdir
}

function teardown() {
  teardown_workdir
}

