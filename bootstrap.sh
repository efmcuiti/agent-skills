#!/usr/bin/env bash
#
# Restore the third-party skills this tree depends on.
#
# Only first-party skills are tracked in git (see .gitignore); everything below
# is installed by the `skills` CLI into ~/.agents/skills and recorded in
# .skill-lock.json. See README.md for why each of these is here.
#
# Usage:
#   ./bootstrap.sh                              # installs for codex and cursor
#   SKILLS_AGENTS="codex cursor warp" ./bootstrap.sh

set -euo pipefail

read -r -a AGENTS <<<"${SKILLS_AGENTS:-codex cursor}"

# Hard dependencies of gh-sdlc, plus the user-invoked skills worth typing.
MATTPOCOCK_SKILLS=(
  codebase-design
  domain-modeling
  grill-me
  grill-with-docs
  grilling
  handoff
  improve-codebase-architecture
  prototype
  writing-for-agents
)

VERCEL_SKILLS=(
  find-skills
)

# The CLI declares engines.node >=22.20.0. Older majors have worked in practice,
# so warn rather than refuse.
node_major="$(node -p 'process.versions.node.split(".")[0]' 2>/dev/null || echo 0)"
if [ "$node_major" -lt 22 ]; then
  echo "warning: node $(node -v 2>/dev/null || echo 'not found') is below the skills CLI's engine requirement (>=22.20.0)" >&2
fi

agent_flags=()
for agent in "${AGENTS[@]}"; do
  agent_flags+=(-a "$agent")
done

install_from() {
  local source="$1"
  shift
  local skill_flags=()
  local skill
  for skill in "$@"; do
    skill_flags+=(-s "$skill")
  done
  echo "==> $source: $*"
  npx --yes skills@latest add "$source" -g "${agent_flags[@]}" "${skill_flags[@]}" -y
}

install_from mattpocock/skills "${MATTPOCOCK_SKILLS[@]}"
install_from vercel-labs/skills "${VERCEL_SKILLS[@]}"

echo
echo "Done. Verify with: npx skills@latest list -g"
