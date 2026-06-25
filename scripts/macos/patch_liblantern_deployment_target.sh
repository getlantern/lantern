#!/usr/bin/env bash
set -euo pipefail

xcframework_path="${1:?usage: $0 <Liblantern.xcframework> [x86_64-min-version] [arm64-min-version]}"
x86_64_min_version="${2:-10.15}"
arm64_min_version="${3:-11.0}"
framework_binary="$xcframework_path/macos-arm64_x86_64/Liblantern.framework/Versions/A/Liblantern"

if [[ ! -f "$framework_binary" ]]; then
  echo "Liblantern framework binary not found: $framework_binary" >&2
  exit 1
fi

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

patched_archives=()

patch_object_build_version() {
  local object_path="$1"
  local min_version="$2"

  # vtool refuses to rewrite some gomobile objects because they have no spare
  # load-command padding, so patch the existing version fields in place.
  python3 - "$object_path" "$min_version" <<'PY'
import struct
import sys

path = sys.argv[1]
min_version = sys.argv[2]

LC_VERSION_MIN_MACOSX = 0x24
LC_BUILD_VERSION = 0x32
PLATFORM_MACOS = 1
MH_MAGIC = 0xfeedface
MH_CIGAM = 0xcefaedfe
MH_MAGIC_64 = 0xfeedfacf
MH_CIGAM_64 = 0xcffaedfe


def encoded_version(version):
    parts = [int(part) for part in version.split(".")]
    if not 1 <= len(parts) <= 3:
        raise ValueError(f"invalid version: {version}")
    parts += [0] * (3 - len(parts))
    major, minor, patch = parts
    return (major << 16) | (minor << 8) | patch


with open(path, "r+b") as f:
    data = bytearray(f.read())

    if len(data) < 28:
        print(0)
        sys.exit(0)

    magic_le = struct.unpack_from("<I", data, 0)[0]
    if magic_le in (MH_MAGIC, MH_MAGIC_64):
        endian = "<"
        header_size = 32 if magic_le == MH_MAGIC_64 else 28
    elif magic_le in (MH_CIGAM, MH_CIGAM_64):
        endian = ">"
        header_size = 32 if magic_le == MH_CIGAM_64 else 28
    else:
        print(0)
        sys.exit(0)

    ncmds = struct.unpack_from(endian + "I", data, 16)[0]
    offset = header_size
    minos = encoded_version(min_version)
    patched = 0

    for _ in range(ncmds):
        if offset + 8 > len(data):
            raise ValueError(f"truncated load command in {path}")

        cmd, cmdsize = struct.unpack_from(endian + "II", data, offset)
        if cmdsize < 8 or offset + cmdsize > len(data):
            raise ValueError(f"invalid load command size in {path}")

        if cmd == LC_BUILD_VERSION and cmdsize >= 24:
            platform = struct.unpack_from(endian + "I", data, offset + 8)[0]
            if platform == PLATFORM_MACOS:
                struct.pack_into(endian + "I", data, offset + 12, minos)
                patched += 1
        elif cmd == LC_VERSION_MIN_MACOSX and cmdsize >= 16:
            struct.pack_into(endian + "I", data, offset + 8, minos)
            patched += 1

        offset += cmdsize

    if patched:
        f.seek(0)
        f.write(data)
        f.truncate()

    print(patched)
PY
}

patch_archive_for_arch() {
  local arch="$1"
  local min_version="$2"
  local arch_dir="$tmp_dir/$arch"
  local archive="$arch_dir/Liblantern.a"
  local patched_archive="$arch_dir/Liblantern-patched.a"
  local members_file="$arch_dir/members.txt"
  local extract_dir="$arch_dir/extract"
  local members=()
  local patched_count=0

  mkdir -p "$extract_dir"

  xcrun lipo -thin "$arch" "$framework_binary" -output "$archive"
  xcrun ar -t "$archive" > "$members_file"
  (
    cd "$extract_dir"
    xcrun ar -x "$archive"
  )

  while IFS= read -r member; do
    [[ -z "$member" || "$member" == "__.SYMDEF"* ]] && continue
    [[ -f "$extract_dir/$member" ]] || continue

    members+=("$member")

    local member_patch_count
    member_patch_count="$(patch_object_build_version "$extract_dir/$member" "$min_version")"
    patched_count=$((patched_count + member_patch_count))
  done < "$members_file"

  if [[ "$patched_count" -eq 0 ]]; then
    echo "No build-version load commands found in $archive" >&2
    exit 1
  fi

  (
    cd "$extract_dir"
    xcrun ar -qc "$patched_archive" "${members[@]}"
  )
  xcrun ranlib "$patched_archive"

  patched_archives+=("$patched_archive")
  echo "Patched Liblantern $arch deployment target metadata to macOS $min_version"
}

for arch in $(xcrun lipo -archs "$framework_binary"); do
  case "$arch" in
    x86_64)
      patch_archive_for_arch "$arch" "$x86_64_min_version"
      ;;
    arm64)
      patch_archive_for_arch "$arch" "$arm64_min_version"
      ;;
    *)
      echo "Unsupported Liblantern architecture: $arch" >&2
      exit 1
      ;;
  esac
done

xcrun lipo -create "${patched_archives[@]}" -output "$tmp_dir/Liblantern"
cp "$tmp_dir/Liblantern" "$framework_binary"
