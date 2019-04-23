#!/usr/bin/env bats

load ./test_common

@test "rename" {
  run bash -c 'echo world | $DAP_EXECUTABLE lines + rename line=hello + json'
  assert_success
  assert_output '{"hello":"world"}'
}

@test "not_exists" {
  run bash -c "echo '{\"foo\":\"bar\"}' | $DAP_EXECUTABLE json + not_exists foo + json"
  assert_success
  assert_output ''
  run bash -c "echo '{\"bar\":\"bar\"}' | $DAP_EXECUTABLE json + not_exists foo + json"
  assert_success
  assert_output '{"bar":"bar"}'
}

@test "split_comma" {
  run bash -c "echo '{\"foo\":\"bar,baz\"}' | $DAP_EXECUTABLE json + split_comma foo + json | jq -Sc ."
  assert_success
  assert_line --index 0 '{"foo":"bar,baz","foo.word":"bar"}'
  assert_line --index 1 '{"foo":"bar,baz","foo.word":"baz"}'
}

@test "field_split_line" {
  run bash -c "echo '{\"foo\":\"bar\nbaz\"}' | $DAP_EXECUTABLE json + field_split_line foo + json | jq -Sc ."
  assert_success
  assert_output '{"foo":"bar\nbaz","foo.f1":"bar","foo.f2":"baz"}'
}

@test  "not_empty" {
  # only exists in godap currently
  skip
  run bash -c "echo '{\"foo\":\"bar,baz\"}' | $DAP_EXECUTABLE json + not_empty foo + json | jq -Sc ."
  assert_success
  assert_output '{"foo":"bar,baz"}'
}

@test "field_split_tab" {
  run bash -c "echo '{\"foo\":\"bar\tbaz\"}' | $DAP_EXECUTABLE json + field_split_tab foo + json | jq -Sc ."
  assert_success
  assert_output '{"foo":"bar\tbaz","foo.f1":"bar","foo.f2":"baz"}'
}

@test "truncate" {
  run bash -c "echo '{\"foo\":\"bar\tbaz\"}' | $DAP_EXECUTABLE json + truncate foo + json | jq -Sc ."
  assert_success
  assert_output '{"foo":""}'
}

@test "insert" {
  run bash -c "echo '{\"foo\":\"bar\tbaz\"}' | $DAP_EXECUTABLE json + insert a=b + json | jq -Sc ."
  assert_success
  assert_output '{"a":"b","foo":"bar\tbaz"}'
}

@test "field_split_array" {
  run bash -c "echo '{\"foo\":[\"a\",2]}' | $DAP_EXECUTABLE json + field_split_array foo + json | jq -Sc ."
  assert_success
  assert_output '{"foo":["a",2],"foo.f1":"a","foo.f2":2}'
}

@test "exists" {
  run bash -c "echo '{\"foo\":\"bar\tbaz\"}' | $DAP_EXECUTABLE json + exists a + json | jq -Sc ."
  assert_success
  assert_output ''
  run bash -c "echo '{\"foo\":\"bar\tbaz\"}' | $DAP_EXECUTABLE json + exists foo + json | jq -Sc ."
  assert_success
  assert_output '{"foo":"bar\tbaz"}'
}

@test "split_line" {
  run bash -c "echo '{\"foo\":\"bar\nbaz\"}' | $DAP_EXECUTABLE json + split_line foo + json | jq -Sc ."
  assert_success
  assert_line --index 0 '{"foo":"bar\nbaz","foo.line":"bar"}'
  assert_line --index 1 '{"foo":"bar\nbaz","foo.line":"baz"}'
}

@test "select" {
  run bash -c "echo '{\"foo\":\"bar\", \"baz\":\"qux\", \"a\":\"b\"}' | $DAP_EXECUTABLE json + select foo + json | jq -Sc ."
  assert_success
  assert_output '{"foo":"bar"}'
  run bash -c "echo '{\"foo\":\"bar\", \"baz\":\"qux\", \"a\":\"b\"}' | $DAP_EXECUTABLE json + select foo baz + json | jq -Sc ."
  assert_success
  assert_output '{"baz":"qux","foo":"bar"}'
}

@test "remove" {
  run bash -c "echo '{\"foo\":\"bar\", \"baz\":\"qux\", \"a\":\"b\"}' | $DAP_EXECUTABLE json + remove foo baz + json | jq -Sc ."
  assert_success
  assert_output '{"a":"b"}'
}

@test "include" {
  run bash -c "echo '{\"foo\":\"bar\", \"baz\":\"qux\", \"a\":\"b\"}' | $DAP_EXECUTABLE json + include a=c + json | jq -Sc ."
  assert_success
  assert_output ''
  run bash -c "echo '{\"foo\":\"bar\", \"baz\":\"qux\", \"a\":\"b\"}' | $DAP_EXECUTABLE json + include a=b + json | jq -Sc ."
  assert_success
  assert_output '{"a":"b","baz":"qux","foo":"bar"}'
}

@test "transform" {
  run bash -c "echo '{\"foo\":\"bar\"}' | $DAP_EXECUTABLE json + transform foo=base64encode + json | jq -Sc ."
  assert_success
  assert_output '{"foo":"YmFy"}'
}

@test "recog_match" {
  # currently differs from godap, need to figure out which is correct
  skip
  run bash -c "echo '9.8.2rc1-RedHat-9.8.2-0.62.rc1.el6_9.2' | $DAP_EXECUTABLE lines + recog line=dns.versionbind + json | jq -Sc ."
  assert_success
  assert_output '{"line":"9.8.2rc1-RedHat-9.8.2-0.62.rc1.el6_9.2","line.recog.os.cpe23":"cpe:/o:redhat:enterprise_linux:6","line.recog.os.family":"Linux","line.recog.os.product":"Enterprise Linux","line.recog.os.vendor":"Red Hat","line.recog.os.version":"6","line.recog.os.version.version":"9","line.recog.service.cpe23":"cpe:/a:isc:bind:9.8.2rc1","line.recog.service.family":"BIND","line.recog.service.product":"BIND","line.recog.service.vendor":"ISC","line.recog.service.version":"9.8.2rc1"}'
}

@test "recog_nomatch" {
  run bash -c "echo 'should not match' | $DAP_EXECUTABLE lines + recog line=dns.versionbind + json | jq -Sc ."
  assert_success
  assert_output '{"line":"should not match"}'
}

@test "recog_invalid_arg" {
  # currently fails in dap, passes in godap
  skip
  run bash -c "echo 'test' | $DAP_EXECUTABLE lines + recog + json"
  assert_failure
}
