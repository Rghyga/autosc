#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE="/etc/katsu-xray/config.env"
DB_FILE="/etc/xray/config.json"
BASE_DIR="/etc/katsu-xray"
WEB_ROOT="/var/www/openclash"

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[1;33m'
blue='\033[0;34m'
cyan='\033[0;36m'
white='\033[1;37m'
nc='\033[0m'

load_env(){ [ -f "$CONFIG_FILE" ] && . "$CONFIG_FILE"; }
need_root(){ [ "${EUID:-0}" -eq 0 ] || { echo -e "${red}Run as root${nc}"; exit 1; }; }
pause(){ echo; read -n 1 -s -r -p "Press any key to continue..."; }
clear_screen(){ clear; }
repeat_char(){ local n="$1" ch="$2"; printf "%${n}s" "" | tr ' ' "$ch"; }

line(){ repeat_char "${1:-66}" '-'; }
ui_top(){ echo -e "${cyan}+$(line 66)+${nc}"; }
ui_mid(){ echo -e "${cyan}+$(line 66)+${nc}"; }
ui_bottom(){ echo -e "${cyan}+$(line 66)+${nc}"; }
ui_row(){ local txt="$1"; printf "${cyan}|${nc} %-66s ${cyan}|${nc}\n" "$txt"; }
ui_kv(){ local label="$1" value="$2"; printf "${cyan}|${nc} ${white}%-16s${nc}: %-47s ${cyan}|${nc}\n" "$label" "$value"; }
ui_wrap(){ local text="$1"; while IFS= read -r line; do printf "${cyan}|${nc} %-66s ${cyan}|${nc}\n" "$line"; done < <(printf '%s\n' "$text" | fold -s -w 66); }

panel_header(){
  local title="$1"
  clear_screen
  ui_top
  ui_row "$title"
  ui_mid
}
panel_footer(){ ui_bottom; }
panel_row(){ ui_kv "$1" "$2"; }
menu_item(){ printf "${cyan}|${nc} %-66s ${cyan}|${nc}\n" "$1"; }
section_title(){ ui_row "$1"; ui_mid; }

server_ip(){ curl -fsSL ipv4.icanhazip.com 2>/dev/null || hostname -I | awk '{print $1}'; }
country_name(){ curl -fsSL ipinfo.io/city 2>/dev/null || echo "N/A"; }
isp_name(){ curl -fsSL ipinfo.io/org 2>/dev/null | sed 's/^[0-9]* //' || echo "N/A"; }
ensure_deps(){ command -v jq >/dev/null || { echo "jq is required"; exit 1; }; command -v python3 >/dev/null || { echo "python3 is required"; exit 1; }; }

protocol_path(){ case "$1" in vmess) echo "$VMESS_WS_PATH";; vless) echo "$VLESS_WS_PATH";; trojan) echo "$TROJAN_WS_PATH";; *) return 1;; esac; }
grpc_service(){ case "$1" in vmess) echo "$VMESS_GRPC_SERVICE";; vless) echo "$VLESS_GRPC_SERVICE";; trojan) echo "$TROJAN_GRPC_SERVICE";; *) return 1;; esac; }
username_exists(){ [ -f "$BASE_DIR/accounts/$1/$2.json" ]; }

json_escape(){ python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$1"; }
url_encode(){ python3 -c 'import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1], safe=""))' "$1"; }

save_account_meta(){
  local proto="$1" user="$2" uuid="$3" expired="$4" ip_limit="$5" quota="$6"
  mkdir -p "$BASE_DIR/accounts/$proto" "$BASE_DIR/iplimit/$proto" "$BASE_DIR/quota/$proto"
  jq -n \
    --arg protocol "$proto" \
    --arg username "$user" \
    --arg uuid "$uuid" \
    --arg expired "$expired" \
    --arg ip_limit "$ip_limit" \
    --arg quota_gb "$quota" \
    '{protocol:$protocol,username:$username,uuid:$uuid,expired:$expired,ip_limit:$ip_limit,quota_gb:$quota_gb}' \
    > "$BASE_DIR/accounts/$proto/$user.json"
  printf '%s\n' "$ip_limit" > "$BASE_DIR/iplimit/$proto/$user"
  printf '%s\n' "$quota" > "$BASE_DIR/quota/$proto/$user"
}

remove_account_meta(){
  rm -f "$BASE_DIR/accounts/$1/$2.json" "$BASE_DIR/iplimit/$1/$2" "$BASE_DIR/quota/$1/$2" "$WEB_ROOT/$1-$2.txt"
}

openclash_url(){ printf 'https://%s:%s/%s-%s.txt' "$DOMAIN" "$OPENCLASH_PORT" "$1" "$2"; }

build_links(){
  local proto="$1" user="$2" uuid="$3"
  local path gservice uri_path tls_link ntls_link grpc_link tls_json ntls_json grpc_json
  path="$(protocol_path "$proto")"
  gservice="$(grpc_service "$proto")"
  uri_path="$(url_encode "$path")"
  case "$proto" in
    vmess)
      tls_json=$(jq -cn --arg ps "$user" --arg add "$DOMAIN" --arg port "$XRAY_TLS_PORT" --arg id "$uuid" --arg host "$DOMAIN" --arg path "$path" '{v:"2",ps:$ps,add:$add,port:$port,id:$id,aid:"0",net:"ws",path:$path,type:"none",host:$host,tls:"tls"}')
      ntls_json=$(jq -cn --arg ps "$user" --arg add "$DOMAIN" --arg port "$XRAY_NTLS_PORT" --arg id "$uuid" --arg host "$DOMAIN" --arg path "$path" '{v:"2",ps:$ps,add:$add,port:$port,id:$id,aid:"0",net:"ws",path:$path,type:"none",host:$host,tls:"none"}')
      grpc_json=$(jq -cn --arg ps "$user" --arg add "$DOMAIN" --arg port "$XRAY_GRPC_PORT" --arg id "$uuid" --arg s "$gservice" '{v:"2",ps:$ps,add:$add,port:$port,id:$id,aid:"0",net:"grpc",type:"none",host:"",path:"",tls:"tls",sni:$add,serviceName:$s}')
      tls_link="vmess://$(printf '%s' "$tls_json" | base64 -w 0)"
      ntls_link="vmess://$(printf '%s' "$ntls_json" | base64 -w 0)"
      grpc_link="vmess://$(printf '%s' "$grpc_json" | base64 -w 0)"
      ;;
    vless)
      tls_link="vless://${uuid}@${DOMAIN}:${XRAY_TLS_PORT}?type=ws&security=tls&path=${uri_path}&host=${DOMAIN}&encryption=none#${user}"
      ntls_link="vless://${uuid}@${DOMAIN}:${XRAY_NTLS_PORT}?type=ws&security=none&path=${uri_path}&host=${DOMAIN}&encryption=none#${user}"
      grpc_link="vless://${uuid}@${DOMAIN}:${XRAY_GRPC_PORT}?type=grpc&security=tls&serviceName=${gservice}&mode=gun&encryption=none&sni=${DOMAIN}#${user}"
      ;;
    trojan)
      tls_link="trojan://${uuid}@${DOMAIN}:${XRAY_TLS_PORT}?type=ws&security=tls&host=${DOMAIN}&path=${uri_path}&sni=${DOMAIN}#${user}"
      ntls_link="trojan://${uuid}@${DOMAIN}:${XRAY_NTLS_PORT}?type=ws&security=none&host=${DOMAIN}&path=${uri_path}#${user}"
      grpc_link="trojan://${uuid}@${DOMAIN}:${XRAY_GRPC_PORT}?type=grpc&security=tls&serviceName=${gservice}&sni=${DOMAIN}#${user}"
      ;;
  esac
  printf '%s\n%s\n%s\n' "$tls_link" "$ntls_link" "$grpc_link"
}

write_openclash_file(){
  local proto="$1" user="$2" uuid="$3" tls_link="$4" ntls_link="$5" grpc_link="$6"
  local path grpc file type_key cred_key
  path="$(protocol_path "$proto")"
  grpc="$(grpc_service "$proto")"
  file="$WEB_ROOT/$proto-$user.txt"
  mkdir -p "$WEB_ROOT"
  case "$proto" in
    vmess) type_key="uuid"; cred_key="$uuid" ;;
    vless) type_key="uuid"; cred_key="$uuid" ;;
    trojan) type_key="password"; cred_key="$uuid" ;;
  esac
  cat > "$file" <<EOM
# ${proto^^} ACCOUNT
# USER     : ${user}
# HOST     : ${DOMAIN}
# EXPIRED  : $(date +%F)

- name: ${proto^^}-${user}-TLS
  type: ${proto}
  server: ${DOMAIN}
  port: ${XRAY_TLS_PORT}
  ${type_key}: ${cred_key}
  network: ws
  tls: true
  servername: ${DOMAIN}
  ws-opts:
    path: ${path}
    headers:
      Host: ${DOMAIN}

- name: ${proto^^}-${user}-NTLS
  type: ${proto}
  server: ${DOMAIN}
  port: ${XRAY_NTLS_PORT}
  ${type_key}: ${cred_key}
  network: ws
  tls: false
  ws-opts:
    path: ${path}
    headers:
      Host: ${DOMAIN}

- name: ${proto^^}-${user}-gRPC
  type: ${proto}
  server: ${DOMAIN}
  port: ${XRAY_GRPC_PORT}
  ${type_key}: ${cred_key}
  network: grpc
  tls: true
  servername: ${DOMAIN}
  grpc-opts:
    grpc-service-name: ${grpc}

TLS  : ${tls_link}
NTLS : ${ntls_link}
gRPC : ${grpc_link}
EOM
}

render_account_box(){
  local proto="$1" user="$2" uuid="$3" exp="$4" iplimit="$5" quota="$6" tls_link="$7" ntls_link="$8" grpc_link="$9"
  local ocurl path grpc
  path="$(protocol_path "$proto")"
  grpc="$(grpc_service "$proto")"
  ocurl="$(openclash_url "$proto" "$user")"
  ui_top
  ui_row "${proto^^} ACCOUNT DETAIL"
  ui_mid
  ui_kv "Username" "$user"
  ui_kv "UUID/Password" "$uuid"
  ui_kv "Host" "$DOMAIN"
  ui_kv "IP" "$(server_ip)"
  ui_kv "Location" "$(country_name)"
  ui_kv "ISP" "$(isp_name)"
  ui_kv "Port TLS" "$XRAY_TLS_PORT"
  ui_kv "Port NTLS" "$XRAY_NTLS_PORT"
  ui_kv "Port gRPC" "$XRAY_GRPC_PORT"
  ui_kv "WS Path" "$path"
  ui_kv "gRPC Service" "$grpc"
  ui_kv "Limit IP" "$iplimit IP"
  ui_kv "Quota" "$quota GB"
  ui_kv "Expired" "$exp"
  ui_mid
  ui_row "TLS LINK"
  ui_wrap "$tls_link"
  ui_mid
  ui_row "NTLS LINK"
  ui_wrap "$ntls_link"
  ui_mid
  ui_row "gRPC LINK"
  ui_wrap "$grpc_link"
  ui_mid
  ui_row "OPENCLASH"
  ui_wrap "$ocurl"
  ui_bottom
}
