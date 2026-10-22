#!/bin/sh
set -eu
: "${FSTAR_EXPECT_VERSION:=}"
test -d /evidence && test -w /evidence || { echo 'INFRASTRUCTURE ERROR: /evidence not writable' >&2; exit 90; }
version="$(fstar.exe --version)" || { echo 'INFRASTRUCTURE ERROR: fstar.exe unavailable' >&2; exit 91; }
printf '%s\n' "$version" > /evidence/version.txt
actual="$(printf '%s\n' "$version" | sed -n '1p')"
if [ -n "$FSTAR_EXPECT_VERSION" ]; then
  printf '%s\n' "$actual" | grep -Fx "F* $FSTAR_EXPECT_VERSION" >/dev/null || { echo "VERSION MISMATCH: $actual" >&2; exit 92; }
fi
sha256sum /poc/src/*.fst > /evidence/sources.sha256
printf 'test,exit,classification\n' > /evidence/summary.csv
printf '%s\n' "$actual"
for name in SigeltInductive NoLemma NoNormalization; do
  if fstar.exe "/poc/src/$name.fst" > "/evidence/$name.log" 2>&1; then rc=0; else rc=$?; fi
  printf '%s\n' "$rc" > "/evidence/$name.exit"
  case "$name" in
    SigeltInductive)
      if [ "$rc" -eq 0 ] && grep -q 'Verified module: SigeltInductive' "/evidence/$name.log"; then
        classification=accepted
        display='ACCEPTED (contradiction)'
      else
        echo "FAIL: main PoC did not verify (exit=$rc); see /evidence/$name.log" >&2
        exit 20
      fi ;;
    *)
      if [ "$rc" -ne 0 ] && grep -q 'Failed to prove: Prims.l_False' "/evidence/$name.log"; then
        classification=expected_proof_rejection
        display='REJECTED (expected)'
      else
        echo "FAIL: control $name did not fail with expected proof error (exit=$rc)" >&2
        exit 21
      fi ;;
  esac
  printf '%s,%s,%s\n' "$name" "$rc" "$classification" >> /evidence/summary.csv
  printf '  %-19s %s\n' "$name" "$display"
done
printf '%s\n' 'RESULT: #4480 REPRODUCED (main accepted; both controls rejected)'
