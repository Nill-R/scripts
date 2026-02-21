#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later OR MIT

"""
Sync monitors from one Uptime Kuma instance to one or more target instances.

Requirements:
    pip install uptime-kuma-api

Usage example:
    python uptime_kuma_sync.py \
        --source-url http://kuma-source:3001 \
        --source-user admin \
        --source-pass secret \
        --target http://kuma-a:3001 admin:secret \
        --target http://kuma-b:3001 admin:secret

    # Wipe all monitors on the target first, then sync:
    python uptime_kuma_sync.py \
        --source-url http://kuma-source:3001 \
        --source-user admin \
        --source-pass secret \
        --target http://kuma-a:3001 admin:secret \
        --purge

Notes:
- Matches monitors by name (common sane denominator).
- Skips existing monitors unless --update is provided.
- DNS monitors are skipped (incompatible conditions field in newer Kuma).
- Group hierarchy is preserved: groups are synced first, then child
  monitors are linked to the correct parent group on the target.
- Paused monitors stay paused on the target.
- All existing notifications on the target are attached to every synced monitor.
"""

import argparse
import sys
from typing import Dict, List

from uptime_kuma_api import UptimeKumaApi

# Monitor types to skip during sync (they require fields like `conditions`
# that the uptime-kuma-api library cannot properly populate).
SKIP_TYPES = {"dns"}

# Fields that the library's _build_monitor_data() does NOT accept but
# newer Uptime Kuma servers require as NOT NULL in their SQLite schema.
# We inject these into the data dict after the library builds it.
EXTRA_REQUIRED_FIELDS = {
    "conditions": "[]",        # NOT NULL in newer Kuma, must be a JSON string
}


# -----------------------------
# Helpers
# -----------------------------

def login(url: str, username: str, password: str) -> UptimeKumaApi:
    api = UptimeKumaApi(url)
    api.login(username, password)
    return api


def index_by_name(monitors: List[Dict]) -> Dict[str, Dict]:
    return {m.get("name"): m for m in monitors if m.get("name")}


def _monitor_type_str(mon: Dict) -> str:
    """Return monitor type as a plain string, regardless of enum/str."""
    t = mon.get("type", "")
    return str(t.value) if hasattr(t, "value") else str(t)


def _get_all_target_notification_ids(api: UptimeKumaApi) -> List[int]:
    """Return a list of all notification IDs on the target instance."""
    notifications = api.get_notifications()
    return [n["id"] for n in notifications]


def build_add_payload(
    src_monitor: Dict,
    parent_id: int = None,
    notification_ids: List[int] = None,
) -> Dict:
    """
    Prepare payload for add_monitor.
    We copy fields that _build_monitor_data accepts and ensure
    required NOT NULL fields are always present.
    """

    # All fields accepted by _build_monitor_data in uptime-kuma-api
    allowed_fields = {
        "type",
        "name",
        "description",
        "url",
        "hostname",
        "port",
        "interval",
        "retryInterval",
        "resendInterval",
        "maxretries",
        "timeout",
        "keyword",
        "invertKeyword",
        "method",
        "httpBodyEncoding",
        "body",
        "headers",
        "jsonPath",
        "expectedValue",
        "ignoreTls",
        "upsideDown",
        "maxredirects",
        "accepted_statuscodes",
        "expiryNotification",
        "proxyId",
        "authMethod",
        "basic_auth_user",
        "basic_auth_pass",
        "authDomain",
        "authWorkstation",
        "tlsCert",
        "tlsKey",
        "tlsCa",
        "oauth_auth_method",
        "oauth_token_url",
        "oauth_client_id",
        "oauth_client_secret",
        "oauth_scopes",
        "packetSize",
        "dns_resolve_server",
        "dns_resolve_type",
        "mqttUsername",
        "mqttPassword",
        "mqttTopic",
        "mqttSuccessMessage",
        "databaseConnectionString",
        "databaseQuery",
        "docker_container",
        "docker_host",
        "radiusUsername",
        "radiusPassword",
        "radiusSecret",
        "radiusCalledStationId",
        "radiusCallingStationId",
        "game",
        "gamedigGivenPortOnly",
        "grpcUrl",
        "grpcEnableTls",
        "grpcServiceName",
        "grpcMethod",
        "grpcProtobuf",
        "grpcBody",
        "grpcMetadata",
        "kafkaProducerBrokers",
        "kafkaProducerTopic",
        "kafkaProducerMessage",
        "kafkaProducerSsl",
        "kafkaProducerAllowAutoTopicCreation",
        "kafkaProducerSaslOptions",
    }

    # Copy only allowed + non-null fields
    payload = {
        k: v
        for k, v in src_monitor.items()
        if k in allowed_fields and v is not None
    }

    # Kuma sometimes requires explicit type
    payload.setdefault("type", src_monitor.get("type", "http"))

    # accepted status codes default
    payload.setdefault("accepted_statuscodes", ["200-299"])

    # Set parent group on the target (already remapped by the caller)
    if parent_id is not None:
        payload["parent"] = parent_id

    # Attach all target notifications to the monitor
    if notification_ids:
        payload["notificationIDList"] = notification_ids

    return payload


def _add_monitor_patched(api: UptimeKumaApi, payload: Dict) -> dict:
    """
    Add a monitor while injecting extra fields that the library
    doesn't know about but newer Kuma requires (e.g. `conditions`).

    Works around the library's strict parameter list in _build_monitor_data.
    """
    from uptime_kuma_api.api import (
        _convert_monitor_input,
        _check_arguments_monitor,
        Event,
    )

    data = api._build_monitor_data(**payload)
    _convert_monitor_input(data)
    _check_arguments_monitor(data)

    # Inject extra required fields that the library doesn't support yet
    for field, default in EXTRA_REQUIRED_FIELDS.items():
        if field not in data or data[field] is None:
            data[field] = default

    with api.wait_for_event(Event.MONITOR_LIST):
        return api._call('add', data)


def _edit_monitor_patched(api: UptimeKumaApi, monitor_id: int, payload: Dict) -> dict:
    """
    Edit a monitor while injecting extra fields that the library
    doesn't know about but newer Kuma requires (e.g. `conditions`).
    """
    from uptime_kuma_api.api import (
        _convert_monitor_input,
        _check_arguments_monitor,
        Event,
    )

    data = api._build_monitor_data(**payload)
    _convert_monitor_input(data)
    _check_arguments_monitor(data)

    # Inject extra required fields
    for field, default in EXTRA_REQUIRED_FIELDS.items():
        if field not in data or data[field] is None:
            data[field] = default

    data["id"] = monitor_id

    with api.wait_for_event(Event.MONITOR_LIST):
        return api._call('editMonitor', data)


# -----------------------------
# Purge
# -----------------------------

def purge_all_monitors(api: UptimeKumaApi) -> None:
    """Delete every monitor on the target instance."""
    monitors = api.get_monitors()
    if not monitors:
        print("  (no monitors to delete)")
        return

    # Delete children first, then groups, to avoid constraint issues.
    children = [m for m in monitors if m.get("parent") is not None]
    groups   = [m for m in monitors if m.get("parent") is None]

    for mon in children + groups:
        name = mon.get("name", f"id={mon['id']}")
        try:
            api.delete_monitor(mon["id"])
            print(f"  [DELETE] {name}")
        except Exception as e:
            print(f"  [ERROR]  deleting {name}: {e}", file=sys.stderr)

    print(f"  Purged {len(children) + len(groups)} monitor(s).")


# -----------------------------
# Core sync logic
# -----------------------------

def sync(
    source_api: UptimeKumaApi,
    target_api: UptimeKumaApi,
    update: bool = False,
) -> None:
    src_monitors = source_api.get_monitors()

    # Get all notification IDs on the target to attach to every monitor
    target_notification_ids = _get_all_target_notification_ids(target_api)
    if target_notification_ids:
        print(f"Found {len(target_notification_ids)} notification(s) on target, "
              f"will attach to all monitors.")

    # Separate groups from regular monitors, skip DNS
    src_groups = []
    src_regular = []
    dns_skipped = 0

    for m in src_monitors:
        mtype = _monitor_type_str(m)
        if mtype in SKIP_TYPES:
            dns_skipped += 1
            print(f"[SKIP-TYPE] {m.get('name')} (type={mtype})")
            continue
        if mtype == "group":
            src_groups.append(m)
        else:
            src_regular.append(m)

    # ------------------------------------------------------------------
    # Phase 1: sync groups first so we can map source→target group IDs
    # ------------------------------------------------------------------
    tgt_monitors = target_api.get_monitors()
    tgt_index = index_by_name(tgt_monitors)

    # source group name → target group id  (after creation / lookup)
    group_name_to_target_id: Dict[str, int] = {}

    created = 0
    skipped = 0
    updated = 0
    errors = 0
    paused_count = 0

    for grp in src_groups:
        name = grp.get("name")
        if not name:
            continue

        is_paused = not grp.get("active", True)
        payload = build_add_payload(grp, notification_ids=target_notification_ids)

        if name in tgt_index:
            group_name_to_target_id[name] = tgt_index[name]["id"]
            if update:
                try:
                    _edit_monitor_patched(
                        target_api, tgt_index[name]["id"], payload
                    )
                    updated += 1
                    print(f"[UPDATE] {name} (group)")
                except Exception as e:
                    errors += 1
                    print(f"[ERROR]  {name}: {e}", file=sys.stderr)
            else:
                skipped += 1
                print(f"[SKIP] {name} (group) already exists")
            continue

        try:
            result = _add_monitor_patched(target_api, payload)
            new_id = result["monitorID"]
            group_name_to_target_id[name] = new_id
            created += 1
            print(f"[CREATE] {name} (group)")

            # Pause the monitor if it was paused on source
            if is_paused:
                target_api.pause_monitor(new_id)
                paused_count += 1
                print(f"[PAUSE]  {name} (group)")

        except Exception as e:
            errors += 1
            print(f"[ERROR]  {name}: {e}", file=sys.stderr)

    # Build source group id → group name lookup (to resolve parent for children)
    src_group_id_to_name: Dict[int, str] = {
        g["id"]: g["name"] for g in src_groups if g.get("name")
    }

    # ------------------------------------------------------------------
    # Phase 2: sync regular monitors, attaching them to correct groups
    # ------------------------------------------------------------------
    # Re-fetch target monitors to include newly created groups
    tgt_monitors = target_api.get_monitors()
    tgt_index = index_by_name(tgt_monitors)

    for src in src_regular:
        name = src.get("name")
        if not name:
            continue

        is_paused = not src.get("active", True)

        # Resolve parent group on the target
        target_parent_id = None
        src_parent = src.get("parent")
        if src_parent is not None:
            parent_name = src_group_id_to_name.get(src_parent)
            if parent_name and parent_name in group_name_to_target_id:
                target_parent_id = group_name_to_target_id[parent_name]

        payload = build_add_payload(
            src,
            parent_id=target_parent_id,
            notification_ids=target_notification_ids,
        )

        if name in tgt_index:
            if update:
                try:
                    _edit_monitor_patched(
                        target_api, tgt_index[name]["id"], payload
                    )
                    updated += 1
                    print(f"[UPDATE] {name}")
                except Exception as e:
                    errors += 1
                    print(f"[ERROR]  {name}: {e}", file=sys.stderr)
            else:
                skipped += 1
                print(f"[SKIP] {name} already exists")
            continue

        try:
            result = _add_monitor_patched(target_api, payload)
            new_id = result["monitorID"]
            created += 1
            print(f"[CREATE] {name}")

            # Pause the monitor if it was paused on source
            if is_paused:
                target_api.pause_monitor(new_id)
                paused_count += 1
                print(f"[PAUSE]  {name}")

        except Exception as e:
            errors += 1
            print(f"[ERROR]  {name}: {e}", file=sys.stderr)

    print(
        f"\nDone: created={created}, updated={updated}, "
        f"skipped={skipped}, errors={errors}, "
        f"dns_skipped={dns_skipped}, paused={paused_count}"
    )


# -----------------------------
# CLI
# -----------------------------

def parse_target(value: List[str]):
    """
    Parse --target entries of form:
        URL USER:PASS
    """
    if len(value) != 2 or ":" not in value[1]:
        raise argparse.ArgumentTypeError("--target requires: URL user:pass")

    url = value[0]
    user, passwd = value[1].split(":", 1)
    return url, user, passwd


def main():
    parser = argparse.ArgumentParser(description="Sync Uptime Kuma monitors")

    parser.add_argument("--source-url", required=True)
    parser.add_argument("--source-user", required=True)
    parser.add_argument("--source-pass", required=True)

    parser.add_argument(
        "--target",
        nargs=2,
        action="append",
        metavar=("URL", "USER:PASS"),
        help="Target Kuma instance",
        required=True,
    )

    parser.add_argument(
        "--update",
        action="store_true",
        help="Update existing monitors",
    )

    parser.add_argument(
        "--purge",
        action="store_true",
        help="Delete ALL monitors on every target before syncing",
    )

    args = parser.parse_args()

    try:
        print("Connecting to source...")
        source_api = login(args.source_url, args.source_user, args.source_pass)

        for tgt in args.target:
            url, user, passwd = parse_target(tgt)
            print(f"\n=== Sync to {url} ===")

            target_api = login(url, user, passwd)

            if args.purge:
                print("  Purging all monitors on target...")
                purge_all_monitors(target_api)
                # Reconnect to reset cached event data after purge
                target_api.disconnect()
                target_api = login(url, user, passwd)

            sync(source_api, target_api, update=args.update)

    except Exception as e:
        import traceback
        print("Fatal error:", repr(e), file=sys.stderr)
        traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    main()
