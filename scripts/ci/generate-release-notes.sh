#!/usr/bin/env bash
set -euo pipefail

# Generate AI-powered release notes using the Claude API.
# Called from the release workflow after builds complete.
#
# Environment variables:
#   ANTHROPIC_API_KEY:  Claude API key
#   RELEASE_TAG:        current release tag (e.g., v9.0.21)
#   BUILD_TYPE:         production, beta, or nightly
#   GITHUB_SHA:         current commit SHA
#
# Outputs release notes markdown to stdout.
# Falls back to a basic changelog if the API call fails.

RELEASE_TAG="${RELEASE_TAG:?RELEASE_TAG required}"
BUILD_TYPE="${BUILD_TYPE:?BUILD_TYPE required}"
GITHUB_SHA="${GITHUB_SHA:?GITHUB_SHA required}"

# Verify jq is available (needed for JSON construction and response parsing)
if ! command -v jq >/dev/null 2>&1; then
  echo "Warning: jq not found, generating basic changelog" >&2
  echo "## Changes"
  echo ""
  git log --oneline -50 | while read -r line; do echo "- $line"; done
  exit 0
fi

# Find the previous release tag to determine the commit range
find_previous_tag() {
  local current_tag="$1"
  local build_type="$2"

  case "$build_type" in
    production)
      # Previous production tag, optionally with platform suffix
      git tag --sort=-version:refname | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+(-(windows|macos|linux|android|ios))?$' | grep -Fvx "$current_tag" | head -1
      ;;
    beta)
      # Previous beta or production tag, including optional platform suffix
      git tag --sort=-version:refname | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+(-beta[0-9A-Za-z._-]*)?(-(windows|macos|linux|android|ios))?$' | grep -Fvx "$current_tag" | head -1
      ;;
    nightly)
      # Previous nightly, beta, or production tag
      git tag --sort=-version:refname | grep -Fvx "$current_tag" | head -1
      ;;
  esac
}

PREV_TAG=$(find_previous_tag "$RELEASE_TAG" "$BUILD_TYPE")
if [[ -z "$PREV_TAG" ]]; then
  echo "Warning: No previous tag found, using last 50 commits" >&2
  GIT_LOG=$(git log --oneline -50)
else
  GIT_LOG=$(git log --oneline "${PREV_TAG}..${GITHUB_SHA}")
fi

COMMIT_COUNT=$(echo "$GIT_LOG" | wc -l | tr -d ' ')

# Collect dependency changes from sub-repos (radiance, lantern-box, etc.)
# When go.mod bumps a dependency, extract what changed in that dependency
# by comparing the old and new versions via the GitHub compare API.
DEP_CHANGES=""
collect_dep_changes() {
  local repo="$1"  # e.g., getlantern/radiance
  local short="${repo##*/}"  # e.g., radiance

  # Extract old and new pseudo-version hashes from go.mod diff
  local mod_diff
  mod_diff=$(git diff "${PREV_TAG}..${GITHUB_SHA}" -- go.mod 2>/dev/null || true)
  [[ -z "$mod_diff" ]] && return

  local old_hash new_hash
  old_hash=$(echo "$mod_diff" | grep "^-.*github.com/${repo}" | grep -oE '[a-f0-9]{12}$' | head -1 || true)
  new_hash=$(echo "$mod_diff" | grep "^+.*github.com/${repo}" | grep -oE '[a-f0-9]{12}$' | head -1 || true)

  [[ -z "$old_hash" || -z "$new_hash" || "$old_hash" == "$new_hash" ]] && return

  # Fetch commit log between the two versions via GitHub API
  local compare
  compare=$(curl -sf "https://api.github.com/repos/${repo}/compare/${old_hash}...${new_hash}" \
    -H "Accept: application/vnd.github.v3+json" \
    ${GH_TOKEN:+-H "Authorization: token ${GH_TOKEN}"} 2>/dev/null || true)

  [[ -z "$compare" ]] && return

  local commits
  commits=$(echo "$compare" | jq -r '.commits[]? | .commit.message | split("\n")[0]' 2>/dev/null | head -20 || true)

  if [[ -n "$commits" ]]; then
    DEP_CHANGES="${DEP_CHANGES}

### ${short} changes (${old_hash:0:7}..${new_hash:0:7}):
${commits}"
  fi
}

# Check key dependencies for changes
if [[ -n "$PREV_TAG" ]]; then
  for repo in getlantern/radiance getlantern/lantern-box getlantern/sing-box-minimal getlantern/kindling getlantern/fronted; do
    collect_dep_changes "$repo"
  done
fi

# If no API key, fall back to basic changelog
if [[ -z "${ANTHROPIC_API_KEY:-}" ]]; then
  echo "Warning: ANTHROPIC_API_KEY not set, generating basic changelog" >&2
  echo "## Changes since ${PREV_TAG:-initial}"
  echo ""
  echo "$GIT_LOG" | while read -r line; do
    echo "- $line"
  done
  exit 0
fi

# Build the Claude API request
SYSTEM_PROMPT="You are a release notes writer for Lantern, a censorship circumvention VPN app. Write concise, user-friendly release notes from git commit logs. Group changes into categories like Bug Fixes, Improvements, Infrastructure, etc. Focus on user-visible changes and significant engineering improvements. Skip trivial commits (typo fixes, CI tweaks, merge commits). Write in past tense. Keep it brief — aim for 5-15 bullet points max. Do NOT include commit hashes or PR numbers in the output."

DEP_SECTION=""
if [[ -n "$DEP_CHANGES" ]]; then
  DEP_SECTION="

The following changes were made in Lantern's core dependencies (these are separate repos whose changes are pulled into the main app via dependency updates):
${DEP_CHANGES}
"
fi

USER_PROMPT="Generate release notes for Lantern ${BUILD_TYPE} release ${RELEASE_TAG}.

Changes in the main lantern repo since ${PREV_TAG:-initial} (${COMMIT_COUNT} commits):

${GIT_LOG}
${DEP_SECTION}
Write release notes in markdown format with categorized sections. Include significant changes from dependencies — they often contain the most important bug fixes and features."

# Call Claude API
RESPONSE=$(curl -s https://api.anthropic.com/v1/messages \
  -H "content-type: application/json" \
  -H "x-api-key: ${ANTHROPIC_API_KEY}" \
  -H "anthropic-version: 2023-06-01" \
  -d "$(jq -n \
    --arg system "$SYSTEM_PROMPT" \
    --arg user "$USER_PROMPT" \
    '{
      model: "claude-haiku-4-5",
      max_tokens: 2048,
      system: $system,
      messages: [{role: "user", content: $user}]
    }')" 2>&1)

# Extract the text content from the response
NOTES=$(echo "$RESPONSE" | jq -r '.content[0].text // empty' 2>/dev/null)

if [[ -z "$NOTES" ]]; then
  echo "Warning: Claude API call failed, falling back to basic changelog" >&2
  echo "API response: $RESPONSE" >&2
  echo "## Changes since ${PREV_TAG:-initial}"
  echo ""
  echo "$GIT_LOG" | while read -r line; do
    echo "- $line"
  done
  exit 0
fi

echo "$NOTES"
