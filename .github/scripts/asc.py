"""Shared App Store Connect plumbing: a signed JWT and a JSON request.

No pip dependencies; the JWT signing shells out to openssl, the same shape as
ansible's bin/apple-certs/cert. Credentials come from ASC_KEY_ID, ASC_ISSUER_ID
and ASC_PRIVATE_KEY (the .p8 content itself).
"""

import base64
import datetime as dt
import json
import os
import subprocess
import urllib.error
import urllib.request

# Overridable so the tests can point at a local stand-in. Nothing sets it in CI.
API = os.environ.get("ASC_API_BASE", "https://api.appstoreconnect.apple.com/v1")


class Fatal(Exception):
    pass


def _b64url(raw: bytes) -> str:
    return base64.urlsafe_b64encode(raw).rstrip(b"=").decode()


def _der_to_raw(der: bytes) -> bytes:
    """ECDSA signatures come back DER encoded, JWS wants raw r||s."""
    if der[0] != 0x30:
        raise Fatal("signature was not a DER sequence")
    idx = 2 if der[1] < 0x80 else 2 + (der[1] & 0x7F)
    out = b""
    for _ in range(2):
        if der[idx] != 0x02:
            raise Fatal("expected a DER integer in the signature")
        length = der[idx + 1]
        val = der[idx + 2 : idx + 2 + length]
        val = val.lstrip(b"\x00").rjust(32, b"\x00")
        out += val
        idx += 2 + length
    return out


def token(key_id: str, issuer_id: str, key_path: str) -> str:
    now = int(dt.datetime.now(dt.timezone.utc).timestamp())
    header = {"alg": "ES256", "kid": key_id, "typ": "JWT"}
    # Apple rejects anything longer than 20 minutes
    payload = {"iss": issuer_id, "iat": now, "exp": now + 15 * 60, "aud": "appstoreconnect-v1"}
    signing_input = f"{_b64url(json.dumps(header).encode())}.{_b64url(json.dumps(payload).encode())}"
    der = subprocess.run(
        ["openssl", "dgst", "-sha256", "-sign", key_path],
        input=signing_input.encode(),
        capture_output=True,
        check=True,
    ).stdout
    return f"{signing_input}.{_b64url(_der_to_raw(der))}"


def api(method: str, path: str, auth: str, body=None):
    req = urllib.request.Request(
        f"{API}{path}",
        method=method,
        data=json.dumps(body).encode() if body else None,
        headers={"Authorization": f"Bearer {auth}", "Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(req) as resp:
            raw = resp.read()
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as e:
        detail = e.read().decode()
        try:
            errors = json.loads(detail).get("errors", [])
            detail = "; ".join(f"{x.get('title')}: {x.get('detail')}" for x in errors) or detail
        except json.JSONDecodeError:
            pass
        raise Fatal(f"App Store Connect said {e.code}: {detail}")
    except urllib.error.URLError as e:
        raise Fatal(f"could not reach App Store Connect: {e.reason}")
