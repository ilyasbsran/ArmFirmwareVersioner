#!/usr/bin/env sh

# -e: exit immediately if a command exits with a non-zero status (fail fast)
# -u: treat unset variables as an error and exit immediately (safer scripting)
set -eu

# --- Helpers ---------------------------------------------------------------
# die(): Print an error message to stderr and exit with status 1
# Usage: die "Something went wrong"
die() { echo "Error: $*" >&2; exit 1; }

# --- Generate version header ----------------------------------------------
# Usage:
#   generate_version_header "<TAG>" [<OUTPUT_PATH>]
# Example:
#   generate_version_header "$new_tag"            # -> $SCRIPT_DIR/version.h
#   generate_version_header "$new_tag" "/tmp/x.h" # -> özel yol
generate_version_header() {
  tag="${1:-}"
  out="${2:-}"

  [ -n "$tag" ] || die "generate_version_header: tag is required"

  # Script directory (for default output location)
  SCRIPT_DIR="$(dirname "$0")"
  out="${out:-$SCRIPT_DIR/version.h}"

  # --- Git metadata (from current HEAD) ---
  head="$(git log -1 --pretty=format:%d)"
  commit_id="$(git rev-parse HEAD)" || die "generate_version_header: cannot resolve HEAD"
  datetime="$(git log -1 --pretty=format:%ci)" || die "generate_version_header: cannot get commit date"

  # Format date/time
  date="$(date -d "$datetime" "+%d/%m/%Y")"
  time="$(date -d "$datetime" "+%H:%M:%S")"

  # --- Parse semver from tag (supports V/v, strips suffixes like -rc1) ---
  norm="${tag#[Vv]}"
  norm="$(printf '%s' "$norm" | sed -E 's/[^0-9.].*$//')"
  IFS=. read -r maj_s min_s pat_s <<EOF
$norm
EOF
  maj_s="${maj_s:-0}"; min_s="${min_s:-0}"; pat_s="${pat_s:-0}"

  # Validate & convert to decimal (dash-safe)
  case "$maj_s" in (*[!0-9]*|'') die "Invalid major in tag '$tag'";; esac
  case "$min_s" in (*[!0-9]* )  die "Invalid minor in tag '$tag'";; esac
  case "$pat_s" in (*[!0-9]* )  die "Invalid patch in tag '$tag'";; esac

  major="$(printf '%d' "$maj_s")"
  minor="$(printf '%d' "$min_s")"
  patch="$(printf '%d' "$pat_s")"

  major02="$(printf '%02d' "$major")"
  minor02="$(printf '%02d' "$minor")"
  patch02="$(printf '%02d' "$patch")"

  # --- Emit header file ---
  cat > "$out" <<EOF
#ifndef ARMFWVERSION_VERSION_H_
#define ARMFWVERSION_VERSION_H_

// Git commit information generated automatically by version script
__attribute__((used)) static const char* GIT_INFO       = "Version Information=['$commit_id','$head]'";
__attribute__((used)) static const char* GIT_COMMIT_ID  = "$commit_id";
__attribute__((used)) static const char* GIT_DATE       = "$date";
__attribute__((used)) static const char* GIT_TIME       = "$time";

// Version derived from Git tag (e.g., V01.02.03)
__attribute__((used)) static const char* GIT_VERSION    = "$tag";

// Semantic version components
__attribute__((used)) static const int   VERSION_MAJOR  = $major;
__attribute__((used)) static const int   VERSION_MINOR  = $minor;
__attribute__((used)) static const int   VERSION_PATCH  = $patch;

// Zero-padded string forms (useful for UI/build banners)
__attribute__((used)) static const char* VERSION_MAJOR_STR = "$major02";
__attribute__((used)) static const char* VERSION_MINOR_STR = "$minor02";
__attribute__((used)) static const char* VERSION_PATCH_STR = "$patch02";

#endif // ARMFWVERSION_VERSION_H_
EOF

  echo "Generated header: $out (GIT_VERSION=$tag, $major.$minor.$patch)"
}

# --- Arg parse -------------------------------------------------------------
# Ensure that a bump type argument is provided.
# If no argument is given, print usage and exit with error.
if [ $# -lt 1 ]; then
  die "Usage: $0 <major|minor|patch>"
fi

bump_type="$1"   # can be "major", "minor", or "patch"

case "$bump_type" in
  major|minor|patch)
    echo "Selected bump type: $bump_type"
    ;;
  *)
    die "Bump type must be one of: major, minor, patch"
    ;;
esac

# --- Update refs -----------------------------------------------------------
# Update all remote-tracking branches and fetch all tags to ensure
# we are working with the latest state of the repository.
# If the fetch fails, terminate the script with an error.
git fetch --all --tags --quiet || die "Failed to fetch from remotes."

# --- Detect default branch -------------------------------------------------
# Try to determine the repository's default branch (usually 'main' or 'master')
# by resolving 'origin/HEAD'. Strip the prefix so we only keep the branch name.
default_branch="$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')"

# --- Fallback if origin/HEAD is not set -----------------------------------
# If the default branch could not be detected from 'origin/HEAD',
# try common branch names locally ('main' or 'master').
# If neither exists, fall back to the first local branch found.
if [ -z "${default_branch:-}" ]; then
  if git show-ref --verify --quiet refs/heads/main; then
    default_branch="main"
  elif git show-ref --verify --quiet refs/heads/master; then
    default_branch="master"
  else
    default_branch="$(git for-each-ref --format='%(refname:short)' refs/heads | head -n1)"
  fi
fi

# Ensure that a default branch was successfully detected.
# If 'default_branch' is empty at this point, abort the script.
[ -n "${default_branch:-}" ] || die "Could not detect a default branch."

# --- Switch to default branch ---------------------------------------------
# Switch to the detected default branch.
# Abort if the checkout fails (e.g., branch does not exist locally).
git checkout --quiet "$default_branch" || die "Cannot checkout '$default_branch'."

# --- Resolve HEAD commit on default branch --------------------------------
# Resolve the commit hash of the current HEAD.
# Abort if HEAD cannot be determined.
head_commit="$(git rev-parse HEAD)" || die "Cannot resolve HEAD."

# --- Find the most recent semantic version tag -----------------------------
# List all tags matching the pattern vNN.NN.NN or VNN.NN.NN (two-digit numbers),
# sort them by creation date in descending order, and pick the latest one.
# If no matching tags exist, the result will be empty.
latest_tag="$(git tag -l '[vV][0-9]*.[0-9]*.[0-9]*' --sort=-creatordate | head -n1)"

echo "=== Default branch & latest tag check ==="
echo "Default branch : $default_branch"
echo "HEAD commit    : $head_commit"

# --- Handle 'no tag' case --------------------------------------------------
have_tag=1
if [ -z "$latest_tag" ]; then
  echo "Latest tag     : (none)"
  echo "Result         : No tags found in this repository."
  # start from V01.00.00 as the very first version
  new_tag="V01.00.00"
  have_tag=0
fi

# --- Only try to resolve commit & bump if there was a real tag -------------
if [ "$have_tag" -eq 1 ]; then
  tag_commit="$(git rev-list -n1 "$latest_tag")" || die "Cannot resolve commit for tag '$latest_tag'."
  # ... (normal comparison & bump logic buradan devam)
else
  echo "Next version   : $new_tag"
  # direkt tag yarat & push et
  if git rev-parse -q --verify "refs/tags/$new_tag" >/dev/null; then
    die "Tag '$new_tag' already exists."
  fi
  if ! git remote get-url origin >/dev/null 2>&1; then
    die "No 'origin' remote configured; cannot push the tag."
  fi
  tag_message="Release $new_tag (initial tag)"
  git tag -a "$new_tag" -m "$tag_message" || die "Failed to create tag '$new_tag'."
  echo "Created tag    : $new_tag"
  if ! git push origin "$new_tag"; then
    git tag -d "$new_tag" >/dev/null 2>&1 || true
    die "Failed to push tag '$new_tag' to 'origin'. Local tag removed."
  fi
  echo "Pushed tag     : $new_tag -> origin"
  
  generate_version_header "$new_tag"
  
  exit 0
fi

echo "Latest tag     : $latest_tag"
echo "Tag commit     : $tag_commit"

# --- Comparison & extra context + version bump -----------------------------
# If the current HEAD commit is exactly the same as the latest tag commit:
# - Inform the user that no new changes exist since the last version.
# - Instruct the user to create and push a new commit before bumping.
# - Abort the script without performing a version bump.
if [ -n "${tag_commit:-}" ] && [ "$head_commit" = "$tag_commit" ]; then
  generate_version_header "$latest_tag"
  echo "Result         : ✅ HEAD is exactly at the latest tag ('$latest_tag')."
  echo "Action         : Please create a new commit with your changes and push it, then re-run this script for a version bump."
  die "No version bump performed because HEAD equals the latest tag."
else
  echo "Result         : ❌ HEAD is NOT at the latest tag."

  # Compare the HEAD commit with the latest tag commit (if it exists):
  # - If the tag commit is an ancestor of HEAD, report how many commits ahead HEAD is.
  # - If HEAD is an ancestor of the tag commit, report how many commits behind HEAD is.
  # - If neither is ancestor of the other, their histories have diverged.
  # If no tag exists at all, initialize 'latest_tag' to V00.00.00 as a starting point.
  if [ -n "${tag_commit:-}" ]; then
    # Only print relative position details if we have a tag commit
    if git merge-base --is-ancestor "$tag_commit" "$head_commit"; then
      ahead_count="$(git rev-list --count "$tag_commit..$head_commit")"
      echo "Detail         : HEAD is $ahead_count commit(s) ahead of '$latest_tag'."
    elif git merge-base --is-ancestor "$head_commit" "$tag_commit"; then
      behind_count="$(git rev-list --count "$head_commit..$tag_commit")"
      echo "Detail         : HEAD is $behind_count commit(s) behind '$latest_tag'."
    else
      echo "Detail         : HEAD and '$latest_tag' are on diverged histories."
    fi
  else
    echo "Detail         : No existing tags found; will start from V00.00.00."
    latest_tag="V00.00.00"
  fi

  # ---- Calculate next semver (two-digit, zero-padded) ----------------------
  # Normalize the latest tag string:
  # - Remove any leading 'v' or 'V' character.
  # - Strip everything after the numeric version (e.g. drop '-rc1' or other suffixes),
  #   leaving only the major.minor.patch digits.
  norm="${latest_tag#[Vv]}"
  norm="$(printf '%s' "$norm" | sed -E 's/[^0-9.].*$//')"

  # Split the normalized version string into major, minor, and patch components.
  # Example: "01.02.03" -> major_s="01", minor_s="02", patch_s="03".
  IFS=. read -r major_s minor_s patch_s <<EOF
$norm
EOF
  # Ensure all version components are set.
  # Default to "00" if any of major, minor, or patch is missing.
  major_s="${major_s:-00}"
  minor_s="${minor_s:-00}"
  patch_s="${patch_s:-00}"

  # Validate that each version component contains only digits.
  # - Major: must not be empty and must be numeric.
  # - Minor/Patch: must be numeric (they default to "00" if missing).
  case "$major_s" in (*[!0-9]*|'') die "Invalid major in latest tag '$latest_tag'";; esac
  case "$minor_s" in (*[!0-9]* )  die "Invalid minor in latest tag '$latest_tag'";; esac
  case "$patch_s" in (*[!0-9]* )  die "Invalid patch in latest tag '$latest_tag'";; esac

  # Convert the string components into decimal integers.
  # This strips any leading zeros and makes them safe for arithmetic.
  major="$(printf '%d' "$major_s")"
  minor="$(printf '%d' "$minor_s")"
  patch="$(printf '%d' "$patch_s")"

  # Increment the appropriate version component based on bump_type:
  # - major: increase major, reset minor and patch to 0
  # - minor: increase minor, reset patch to 0
  # - patch: increase patch only
  # Abort if bump_type is invalid (should never happen due to earlier validation).
  case "$bump_type" in
    major) major=$((major + 1)); minor=0; patch=0 ;;
    minor) minor=$((minor + 1)); patch=0 ;;
    patch) patch=$((patch + 1)) ;;
    *) die "Invalid bump type '$bump_type' (expected: major|minor|patch)" ;;
  esac

  # Format the new version tag with a leading 'V' and zero-padded two-digit fields.
  # Example: major=2, minor=3, patch=4 -> "V02.03.04"
  new_tag=$(printf "V%02d.%02d.%02d" "$major" "$minor" "$patch")

  echo "------------------------------------------"
  echo "Selected bump  : $bump_type"
  echo "Previous tag   : $latest_tag"
  echo "Next version   : $new_tag"
  echo "------------------------------------------"

  # --- Create and push tag -------------------------------------------------

  # Safety check: ensure the new tag does not already exist.
  # Abort if a tag with the same name is found.
  if git rev-parse -q --verify "refs/tags/$new_tag" >/dev/null; then
    die "Tag '$new_tag' already exists."
  fi

  # Verify that a remote named 'origin' is configured.
  # Abort if 'origin' does not exist, since we cannot push the new tag without it.
  if ! git remote get-url origin >/dev/null 2>&1; then
    die "No 'origin' remote configured; cannot push the tag."
  fi

  # Create an annotated Git tag for the new version.
  # The tag includes a message noting the version and bump type.
  # Abort if the tag creation fails.
  tag_message="Release $new_tag (bump: $bump_type)"
  if ! git tag -a "$new_tag" -m "$tag_message"; then
    die "Failed to create tag '$new_tag'."
  fi
  echo "Created tag    : $new_tag"

  # Push the new tag to the 'origin' remote.
  # If the push fails, delete the local tag to avoid inconsistencies,
  # then abort with an error message.
  if ! git push -q origin "$new_tag" >/dev/null 2>&1; then
    git tag -d "$new_tag" >/dev/null 2>&1 || true
    die "Failed to push tag '$new_tag' to 'origin'. Local tag removed."
  fi
  echo "Pushed tag     : $new_tag -> origin"
  
  generate_version_header "$new_tag"
  
  exit 0
fi