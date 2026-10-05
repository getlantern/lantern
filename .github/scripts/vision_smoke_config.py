import argparse
import os
from pathlib import Path
import re
import sys
import tempfile
from urllib.parse import parse_qs, unquote, urlsplit


def select_vision_url(raw):
    for candidate in re.split(r"\s+|,(?=[a-zA-Z][a-zA-Z0-9+.-]*://)", raw.strip()):
        candidate = candidate.strip("\ufeff\u200b\u200c\u200d\u2060\"'`<>")
        if re.search(r"%(?![A-Fa-f0-9]{2})", candidate):
            continue
        try:
            url = urlsplit(candidate)
            query = parse_qs(url.query, keep_blank_values=True)
            if (
                url.scheme != "vless"
                or not url.hostname
                or not url.username
                or url.password is not None
                or not url.port
                or query.get("flow") != ["xtls-rprx-vision"]
                or query.get("security") not in (["tls"], ["reality"])
                or query.get("type", ["tcp"]) != ["tcp"]
            ):
                continue
            insecure = {
                "allowinsecure", "insecure", "skipcertverify",
                "skipcertverification",
            }
            if any(
                key.lower().replace("_", "").replace("-", "") in insecure
                and any(
                    value.lower() not in {"0", "false", "no"}
                    for value in values
                )
                for key, values in query.items()
            ):
                continue
            if query.get("security") == ["reality"] or "pbk" in query:
                if len(query.get("pbk", [])) != 1 or not re.fullmatch(
                    r"[A-Za-z0-9_-]{43}", query["pbk"][0]
                ):
                    continue
                short_ids = query.get("sid", [""])
                if len(short_ids) != 1 or not re.fullmatch(
                    r"(?:[A-Fa-f0-9]{2}){0,8}", short_ids[0]
                ):
                    continue
            return candidate.replace(",", "%2C")
        except ValueError:
            continue
    raise ValueError(
        "JOIN_SERVER_CONFIG_URLS must contain a valid vless:// URL with "
        "flow=xtls-rprx-vision, TCP transport, security=tls or reality, "
        "certificate verification enabled, and a valid Reality public key "
        "when applicable"
    )


def write_private_config(path, value):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary = tempfile.mkstemp(
        prefix=".vision-server-urls-", dir=path.parent
    )
    try:
        with os.fdopen(descriptor, "w") as output:
            output.write(value + "\n")
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output")
    parser.add_argument("--mask", action="store_true")
    args = parser.parse_args()
    try:
        selected = select_vision_url(os.environ.get("JOIN_SERVER_CONFIG_URLS", ""))
        if args.mask:
            username = urlsplit(selected).username
            for value in dict.fromkeys((
                selected, selected.split("#", 1)[0], username, unquote(username)
            )):
                escaped = (
                    value.replace("%", "%25")
                    .replace("\r", "%0D")
                    .replace("\n", "%0A")
                )
                print("::add-mask::" + escaped, flush=True)
        if args.output:
            write_private_config(args.output, selected)
    except ValueError as error:
        print(str(error), file=sys.stderr)
        return 2
    except OSError:
        print(
            "Could not write the protected Vision smoke configuration file",
            file=sys.stderr,
        )
        return 2
    print("Validated secure VLESS-Vision smoke configuration")
    return 0


if __name__ == "__main__":
    sys.exit(main())
