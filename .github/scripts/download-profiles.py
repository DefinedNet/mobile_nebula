#!/usr/bin/env python3
"""Download the ACTIVE provisioning profile for each of several bundle ids.

Apple-Actions/download-provisioning-profiles sends `filter[identifier]` unpaged,
and that filter is a prefix match. net.defined.mobileNebula is the prefix of
every id in the account, so the app itself, the oldest and shortest, falls off
the default page of twenty and the step reports it as having no ACTIVE profile.

Kept in step with nebula-apple's copy, which takes several bundle ids at once
for its system extension slots.

Writes the same files in the same place as the action, so the check that follows
it and xcodebuild both find what they expect:
$HOME/Library/MobileDevice/Provisioning Profiles/<uuid>.<provisionprofile|mobileprovision>

Bundle ids come from the arguments, or newline separated on stdin.
"""

import argparse
import base64
import os
import pathlib
import sys
import tempfile
import urllib.parse

from asc import Fatal, api, token


def profiles_for(auth_of, bundle_id: str, profile_type: str) -> list:
    """Every ACTIVE profile attached to this bundle id, matching profile_type."""
    # limit=200, Apple's max page. `filter[identifier]` is a prefix match, so net.defined.mobileNebula
    # comes back with every bundle id that starts with it: prod, beta, debug and all their extensions
    # and slots, around forty. Without the limit that spills past the default page and the app id we
    # actually asked for, the oldest and shortest, is not on it, so the exact-match filter below finds
    # nothing and calls the app id missing when it is only unpaged.
    query = urllib.parse.urlencode(
        {"filter[identifier]": bundle_id, "include": "profiles", "limit": 200}
    )
    body = api("GET", f"/bundleIds?{query}", auth_of())

    # A full page means there could be more, and the honest fix then is real pagination. Fail loud
    # rather than silently miss a bundle id that fell off the end.
    if len(body.get("data", [])) >= 200:
        raise Fatal(f"more than 200 bundle ids start with '{bundle_id}'; this needs pagination")

    # Exactly this identifier, not the prefix matches above: without this a slot's profile could be
    # written for the app and the app's for a slot.
    bundles = [b for b in body.get("data", []) if b.get("attributes", {}).get("identifier") == bundle_id]
    if not bundles:
        raise Fatal(f"no App ID registered with bundle id '{bundle_id}'")

    wanted = {rel["id"] for b in bundles for rel in b.get("relationships", {}).get("profiles", {}).get("data", [])}
    out = []
    for item in body.get("included", []):
        if item.get("type") != "profiles" or item["id"] not in wanted:
            continue
        attrs = item.get("attributes", {})
        if attrs.get("profileState") != "ACTIVE":
            continue
        if profile_type and attrs.get("profileType") != profile_type:
            continue
        out.append(attrs)
    if not out:
        raise Fatal(
            f"no ACTIVE {profile_type or 'any-type'} profile for bundle id '{bundle_id}'. "
            "Check the App ID exists, that a profile is attached to it, and that the profile has "
            "not been invalidated by a capability change."
        )
    return out


def write(attrs: dict, into: pathlib.Path) -> pathlib.Path:
    uuid = attrs.get("uuid")
    content = attrs.get("profileContent")
    if not uuid or not content:
        raise Fatal(f"profile '{attrs.get('name')}' came back without a uuid or its content")
    # Same rule the action uses: platform can be absent or UNIVERSAL, so fall back to the type.
    mac = attrs.get("platform") == "MAC_OS" or (attrs.get("profileType") or "").startswith("MAC_")
    path = into / f"{uuid}.{'provisionprofile' if mac else 'mobileprovision'}"
    path.write_bytes(base64.b64decode(content))
    return path


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("bundle_ids", nargs="*", help="bundle ids; newline separated on stdin if absent")
    p.add_argument("--profile-type", default="", help="e.g. MAC_APP_STORE, IOS_APP_STORE")
    args = p.parse_args()

    ids = [b.strip() for b in args.bundle_ids]
    if not ids and not sys.stdin.isatty():
        ids = [line.strip() for line in sys.stdin]
    ids = [b for b in ids if b]
    if not ids:
        raise Fatal("no bundle ids given")

    home = os.environ.get("HOME")
    if not home:
        raise Fatal("HOME is not set, so there is nowhere to install a profile")
    into = pathlib.Path(home) / "Library/MobileDevice/Provisioning Profiles"
    into.mkdir(parents=True, exist_ok=True)

    key_id = os.environ["ASC_KEY_ID"]
    issuer_id = os.environ["ASC_ISSUER_ID"]
    key = os.environ["ASC_PRIVATE_KEY"]
    with tempfile.NamedTemporaryFile("w", suffix=".p8", delete=True) as f:
        f.write(key)
        f.flush()
        # Fresh per call, so twenty slots cannot outlive one token's 15 minutes
        auth_of = lambda: token(key_id, issuer_id, f.name)  # noqa: E731

        for bundle_id in ids:
            for attrs in profiles_for(auth_of, bundle_id, args.profile_type):
                path = write(attrs, into)
                print(f"wrote '{attrs.get('name')}' for {bundle_id} to {path}")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Fatal as e:
        print(f"error: {e}", file=sys.stderr)
        sys.exit(1)
