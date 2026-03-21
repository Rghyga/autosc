# KatsuDev Xray Only Autoscript

## One click install
```bash
apt update && apt install wget curl -y && wget -qO install https://raw.githubusercontent.com/Rghyga/autosc/master/install && chmod +x install && ./install
```

## Fitur
- Xray only: VMess, VLESS, Trojan
- WS + gRPC
- Panel premium business-grade
- Add / renew / delete / list account
- Email ACME permanen di file install, domain ditanya tiap install
- Output akun clean box

## Konfigurasi permanen sebelum upload ke GitHub
Edit file `install` lalu ganti nilai berikut:
- `DEFAULT_ACME_EMAIL="emailkamu@domain.com"`

Domain **tidak** di-hardcode. Saat install berjalan, domain akan tetap diminta di bawah banner installer.

Repo default sudah diarahkan ke `Rghyga/autosc` branch `master`.

## Struktur menu Xray
- `menu-xray` -> gateway protocol
- `menu-vmess` -> add/renew/delete/list VMess
- `menu-vless` -> add/renew/delete/list VLESS
- `menu-trojan` -> add/renew/delete/list Trojan

## Revisi final
- Path WS disederhanakan menjadi `/vmess`, `/vless`, `/trojan`
- File OpenClash tiap akun otomatis dibuat ke web TLS port `81`
- Link output akun: `https://domain:81/<protocol>-<username>.txt`
- Renew akun ikut refresh file OpenClash, delete akun ikut hapus file web
