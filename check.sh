#!/bin/sh
# Everything that must pass before a change is done.
#
# No build system: `odin build` picks up every file in a folder, so this script
# only decides the order and the exit code. See ADR-013 §6.
set -e

: "${ODIN_ROOT:?set ODIN_ROOT to your Odin checkout (core: imports fail without it)}"
export PATH="$ODIN_ROOT:$PATH"

echo "--- vet"
for pkg in obs model render preflight; do
	odin check "src/$pkg" -no-entry-point -vet -strict-style
done
odin check src/tutor -vet -strict-style

echo "--- tests"
for pkg in obs model render preflight; do
	odin test "src/$pkg"
done

echo "--- build"
odin build src/tutor -out:odin-tutor

echo "--- schemas"
python3 - <<'PY'
import glob, json, sys
try:
    import jsonschema
except ImportError:
    print("jsonschema not installed; skipping validation")
    sys.exit(0)

observation = json.load(open("schemas/observation-v1.schema.json"))
trace = json.load(open("schemas/trace-v1.schema.json"))
jsonschema.Draft202012Validator.check_schema(observation)
jsonschema.Draft202012Validator.check_schema(trace)

failed = False
for path in glob.glob("fixtures/observations/*.json"):
    errors = list(jsonschema.Draft202012Validator(observation).iter_errors(json.load(open(path))))
    print(("FAIL " if errors else "ok   ") + path)
    for e in errors[:3]:
        print("   ", list(e.path)[:4], e.message[:120])
    failed = failed or bool(errors)
sys.exit(1 if failed else 0)
PY

echo
echo "all green"
