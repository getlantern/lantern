#!/usr/bin/env python3
"""Generate deterministic neutral Android icon resources for stealth variants."""

from __future__ import annotations

import argparse
import colorsys
import hashlib
import json
import secrets
from pathlib import Path


def hash_bytes(seed: str) -> bytes:
    return hashlib.sha256(seed.encode("utf-8")).digest()


def color_from_hash(data: bytes, offset: int, sat: float, light: float) -> str:
    hue = int.from_bytes(data[offset : offset + 2], "big") / 65535
    red, green, blue = colorsys.hls_to_rgb(hue, light, sat)
    return "#{:02X}{:02X}{:02X}".format(
        round(red * 255),
        round(green * 255),
        round(blue * 255),
    )


def shape_paths(data: bytes, primary: str, secondary: str, accent: str) -> str:
    template = data[4] % 4
    if template == 0:
        return f"""
    <path android:fillColor="{primary}" android:pathData="M54,14 L92,54 L54,94 L16,54 Z"/>
    <path android:fillColor="{secondary}" android:pathData="M54,28 L78,54 L54,80 L30,54 Z"/>
    <path android:fillColor="{accent}" android:pathData="M47,47 L61,47 L61,61 L47,61 Z"/>
"""
    if template == 1:
        return f"""
    <path android:fillColor="{primary}" android:pathData="M22,24 L86,24 L86,84 L22,84 Z"/>
    <path android:fillColor="{secondary}" android:pathData="M34,36 L74,36 L74,72 L34,72 Z"/>
    <path android:fillColor="{accent}" android:pathData="M42,46 L66,46 L66,62 L42,62 Z"/>
"""
    if template == 2:
        return f"""
    <path android:fillColor="{primary}" android:pathData="M54,12 L78,22 L96,46 L88,74 L64,94 L36,90 L16,68 L14,38 L34,18 Z"/>
    <path android:fillColor="{secondary}" android:pathData="M54,28 L70,36 L82,54 L74,72 L54,80 L34,72 L26,54 L38,36 Z"/>
    <path android:fillColor="{accent}" android:pathData="M54,43 L65,54 L54,65 L43,54 Z"/>
"""
    return f"""
    <path android:fillColor="{primary}" android:pathData="M18,74 L42,22 L66,74 Z"/>
    <path android:fillColor="{secondary}" android:pathData="M48,74 L66,34 L90,74 Z"/>
    <path android:fillColor="{accent}" android:pathData="M44,74 L58,48 L72,74 Z"/>
"""


def write_text(path: Path, value: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(value.strip() + "\n", encoding="utf-8")


def generate(seed: str, output_res_dir: Path) -> dict[str, str]:
    data = hash_bytes(seed)
    background = color_from_hash(data, 0, 0.46, 0.30)
    primary = color_from_hash(data, 6, 0.42, 0.74)
    secondary = color_from_hash(data, 10, 0.36, 0.58)
    accent = color_from_hash(data, 14, 0.56, 0.82)

    values_dir = output_res_dir / "values"
    drawable_dir = output_res_dir / "drawable"
    legacy_mipmap_dir = output_res_dir / "mipmap-anydpi"
    mipmap_dir = output_res_dir / "mipmap-anydpi-v26"

    write_text(
        values_dir / "stealth_icon_colors.xml",
        f"""
<resources>
    <color name="stealth_launcher_background">{background}</color>
</resources>
""",
    )

    write_text(
        drawable_dir / "stealth_launcher_foreground.xml",
        f"""
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp"
    android:height="108dp"
    android:viewportWidth="108"
    android:viewportHeight="108">
{shape_paths(data, primary, secondary, accent)}
</vector>
""",
    )

    write_text(
        drawable_dir / "stealth_notification_icon.xml",
        """
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="24dp"
    android:height="24dp"
    android:viewportWidth="24"
    android:viewportHeight="24">
    <path android:fillColor="#FFFFFFFF" android:pathData="M12,3 L21,12 L12,21 L3,12 Z"/>
    <path android:fillColor="#00000000" android:pathData="M12,8 L16,12 L12,16 L8,12 Z"/>
</vector>
""",
    )

    adaptive_icon = """
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/stealth_launcher_background"/>
    <foreground android:drawable="@drawable/stealth_launcher_foreground"/>
    <monochrome android:drawable="@drawable/stealth_notification_icon"/>
</adaptive-icon>
"""
    write_text(mipmap_dir / "stealth_ic_launcher.xml", adaptive_icon)
    write_text(mipmap_dir / "stealth_ic_launcher_round.xml", adaptive_icon)

    legacy_icon = f"""
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp"
    android:height="108dp"
    android:viewportWidth="108"
    android:viewportHeight="108">
    <path android:fillColor="{background}" android:pathData="M0,0 L108,0 L108,108 L0,108 Z"/>
{shape_paths(data, primary, secondary, accent)}
</vector>
"""
    write_text(legacy_mipmap_dir / "stealth_ic_launcher.xml", legacy_icon)
    write_text(legacy_mipmap_dir / "stealth_ic_launcher_round.xml", legacy_icon)

    metadata = {
        "seedSha256": hashlib.sha256(seed.encode("utf-8")).hexdigest(),
        "background": background,
        "primary": primary,
        "secondary": secondary,
        "accent": accent,
        "launcherIcon": "@mipmap/stealth_ic_launcher",
        "roundLauncherIcon": "@mipmap/stealth_ic_launcher_round",
        "notificationIcon": "@drawable/stealth_notification_icon",
    }
    write_text(
        output_res_dir.parent / "stealth-icon-metadata.json",
        json.dumps(metadata, indent=2, sort_keys=True),
    )
    return metadata


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--seed",
        default="",
        help="private per-variant seed; random if omitted",
    )
    parser.add_argument(
        "--output-res-dir",
        type=Path,
        required=True,
        help="Android generated resource directory",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    seed = args.seed or secrets.token_urlsafe(24)
    metadata = generate(seed, args.output_res_dir)
    print(
        "Generated stealth Android icons:",
        args.output_res_dir,
        metadata["seedSha256"],
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
