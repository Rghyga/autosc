#!/usr/bin/env python3
import json
import sys
from pathlib import Path

DB = Path('/etc/xray/config.json')


def load():
    return json.loads(DB.read_text())


def save(data):
    DB.write_text(json.dumps(data, indent=2) + "\n")


def mapping(proto):
    return {
        'vmess': ['vmess-ws', 'vmess-grpc'],
        'vless': ['vless-ws', 'vless-grpc'],
        'trojan': ['trojan-ws', 'trojan-grpc'],
    }[proto]


def add_user(proto, email, uuid_or_password, expiry):
    data = load()
    tags = set(mapping(proto))
    for inbound in data.get('inbounds', []):
        if inbound.get('tag') not in tags:
            continue
        settings = inbound.setdefault('settings', {})
        clients = settings.setdefault('clients', [])
        clients = [c for c in clients if c.get('email') != email]
        if proto == 'trojan':
            clients.append({'password': uuid_or_password, 'email': email, 'expiry': expiry})
        elif proto == 'vmess':
            clients.append({'id': uuid_or_password, 'alterId': 0, 'email': email, 'expiry': expiry})
        else:
            clients.append({'id': uuid_or_password, 'email': email, 'flow': '', 'expiry': expiry})
        settings['clients'] = clients
    save(data)


def remove_user(proto, email):
    data = load()
    tags = set(mapping(proto))
    for inbound in data.get('inbounds', []):
        if inbound.get('tag') not in tags:
            continue
        settings = inbound.setdefault('settings', {})
        settings['clients'] = [c for c in settings.get('clients', []) if c.get('email') != email]
    save(data)


if __name__ == '__main__':
    if len(sys.argv) < 4:
        raise SystemExit('usage: xray_db.py add|del <proto> <user> [uuid] [expiry]')
    if sys.argv[1] == 'add':
        add_user(sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5])
    elif sys.argv[1] == 'del':
        remove_user(sys.argv[2], sys.argv[3])
    else:
        raise SystemExit('invalid action')
