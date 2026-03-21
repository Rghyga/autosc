# Analisis Autoscript Lama

## Temuan utama
1. Permission gate disalin ke banyak file sehingga maintenance berat dan mudah drift.
2. Modifikasi konfigurasi Xray memakai `sed` langsung ke JSON, rapuh jika format berubah.
3. Arsitektur bercampur antara SSH, Xray, L2TP, WG, bot, dan website sehingga installer tidak fokus.
4. UX pembuatan akun belum konsisten bersih; output final dan input kadang bercampur.
5. State akun tersebar di log, quota file, lock file, dan JSON tanpa satu metadata source yang rapi.
6. Banyak duplikasi script WS/HTTP/SPLIT/GRPC dengan pola serupa, sehingga boros maintenance.
7. Ada penggunaan `chmod +x` pada file JSON/log yang tidak relevan.
8. Beberapa info panel berpotensi tertukar atau keliru karena pengambilan IP/status service yang tidak konsisten.

## Arah desain versi baru
- Fokus Xray only: VMess, VLESS, Trojan.
- Metadata akun per user di `/etc/katsu-xray/accounts/<protocol>/`.
- Update database Xray via Python JSON handler.
- Panel premium box style.
- Output detail akun lengkap: host, IP, lokasi, port, link, OpenClash.


## Revisi setelah feedback
- Installer diubah ke repo `Rghyga/autosc` branch `master`.
- Mode SSL installer diubah ke permanent default, bukan pilihan interaktif.
- Nilai email/domain permanen disiapkan lewat konstanta `DEFAULT_ACME_EMAIL` dan `DEFAULT_DOMAIN` pada file `install`.
