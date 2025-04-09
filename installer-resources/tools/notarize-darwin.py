#!/usr/bin/env python3

import argparse
import json
import os
import subprocess
import sys
import time


description = """
Notarizes a dmg file and staples the resulting notarization ticket to the file. The arguments are
passed to the xcrun notarytool utility, so more info can be obtained through 'xcrun notarytool --help'.

Requires Python 3.
"""

epilog = """
Note that if the password is provided through the keychain, you may be prompted to enter your login
password on every request to Apple's servers. A workaround is to pass the password in via something
like:
    --password `security find-generic-password -s <password-name> -w`
"""


# Time between calls to Apple's servers, polling for results of notarization.
POLL_WAIT_SECONDS = 30

# Max consecutive failures allowed.
POLL_MAX_RETRIES = 3

DEV_NULL = open(os.devnull, 'w')

def print_stderr(*objects):
    print("%s:" % os.path.basename(__file__), *objects, file=sys.stderr)


def get_notary_call(command, param_list):

    cmd = ["xcrun", "notarytool", command] + param_list + ["--output-format", "json"]
    com_process = subprocess.run(cmd, text=True, capture_output=True)

    com_result = com_process.returncode
    com_stdout = com_process.stdout

    if com_result != 0:
        print_stderr(f"Error results: {com_process.stderr}")
    print_stderr(f"{command} results: {com_stdout}")

    try:
        output_json = json.loads(com_stdout)
        return com_result, output_json
    except json.decoder.JSONDecodeError as e:
        print(com_stdout, file=sys.stderr)
        print_stderr(f"Error running {command}, please check your credentials and inputs")
        print(e)
        raise e


def get_info(credentials, request_id):
    try:
        return get_notary_call("info",[ request_id, 
                "--apple-id", credentials["username"],
                "--password", credentials["password"],
                "--team-id", credentials["team-id"]
                ]
            )
    except json.decoder.JSONDecodeError as e:
        print_stderr(f"Error fetching request info for {request_id}")
        exit(1)


def upload_file(credentials, filepath):
    try:
        return get_notary_call("submit",[ 
                "--apple-id", credentials["username"],
                "--password", credentials["password"],
                "--team-id", credentials["team-id"], filepath]
            )
    except json.decoder.JSONDecodeError as e:
        print_stderr(f"Error uploading {filepath}")
        exit(1)


def get_log(credentials, request_id):
    try:
        return get_notary_call("log",[ request_id, 
                "--apple-id", credentials["username"],
                "--password", credentials["password"],
                "--team-id", credentials["team-id"]
                ]
            )
    except json.decoder.JSONDecodeError as e:
        print_stderr(f"Error fetching log for {request_id}")
        exit(1)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        description=description,
        epilog=epilog,
        formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("dmgfile")
    parser.add_argument("-u", "--username", dest="username", required=True,
        help="Apple ID used for the Apple Developer Program.")
    parser.add_argument("-a", "--team-id ", dest="team_id", required=True,
        help="Developer Team ID used for the Apple Developer Program.")
    parser.add_argument("-p", "--password", dest="password", required=True,
        help="May be provided through keychain or env var; see 'xcrun notarytool --help'.")
    parser.add_argument("-t", "--max-wait-time", dest="max_wait_time", type=int, default=120,
        help="The maximum amount of time (in minutes) to wait for a notarization result.")
    args = parser.parse_args()

    validate_result = subprocess.call(
        ["xcrun", "stapler", "validate", args.dmgfile], stdout=DEV_NULL, stderr=DEV_NULL)
    if validate_result == 0:
        print_stderr("file already has notarization ticket attached - nothing to do")
        exit(0)

    print_stderr("uploading to notary servers...")

    credentials = { "username": args.username,
                    "password": args.password,
                    "team-id": args.team_id}

    upload_result, upload_json = upload_file(credentials, args.dmgfile)
    message = upload_json.get("message")

    print_stderr(f"Upload process complete, message: {message}")

    if upload_result == 0:
        print_stderr("upload complete")
        request_id = upload_json.get("id")
        if not request_id:
            print_stderr("Request id not found in upload output, aborting")
            exit(1)

    else:

        if "already been uploaded" in message:
            print_stderr("already uploaded")
            exit(1)
        else:
            print(upload_json, file=sys.stderr)
            print_stderr("upload failed")
            exit(upload_result)

    print_stderr("polling servers for result (this may take some time)...")
    last_poll = time.time()
    poll_end = time.time() + args.max_wait_time * 60
    consecutive_retries = 0
    processing_complete = False
    while not processing_complete and time.time() < poll_end:

        print_stderr("polling results: ")
        info_result, info_json = get_info(credentials, request_id)

        if info_result != 0:
            consecutive_retries += 1
            if consecutive_retries >= POLL_MAX_RETRIES:
                print(info_json, file=sys.stderr)
                print_stderr("%d consecutive failures polling for status; giving up" % POLL_MAX_RETRIES)
                exit(1)
            time.sleep(POLL_WAIT_SECONDS)
            continue
        consecutive_retries = 0

        status = info_json.get("status").lower()
        if not status:
            print(info_json, file=sys.stderr)
            print_stderr("Status not present, malformed info response")
            exit(1)
        
        if status == "success" or status == "accepted":
            print_stderr("notarization succeeded")
            processing_complete = True

        elif status == "invalid":
            print_stderr("notarization failed")

            log_result, log_json = get_log(credentials, request_id)
            issues = log_json.get("issues")
            if not issues:
                print_stderr("found no issues in log file")
                print_stderr("request_id:", request_id)
            print_stderr("issues:")
            for issue in issues:
                print(issue, file=sys.stderr)
            exit(1)
            
        elif status == "in progress":
            time.sleep(POLL_WAIT_SECONDS)
        else:
            print_stderr("Unknown Status in log")
            print_stderr(info_json)
            exit(1)

    print_stderr("pulling log file...")

    try:
        log_result, log_json = get_log(credentials, request_id)
        issues = info_json.get("issues")

        if issues is None or len(issues) == 0:
            print_stderr("found no issues in log file")
        else:
            print_stderr("found issues in log file:")
            for issue in issues:
                print(issue, file=sys.stderr)
    except Exception as e:
        print(info_json, file=sys.stderr)
        print_stderr("failed to retrieve log file", e)

    print_stderr("stapling notarization ticket to file")
    staple_result = subprocess.call(["xcrun", "stapler", "staple", args.dmgfile])
    if staple_result != 0:
        print_stderr("failed to staple notarization ticket")
        exit(1)
