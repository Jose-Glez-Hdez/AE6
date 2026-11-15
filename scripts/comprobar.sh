#!/usr/bin/env bash
# comprobar.sh — comprobación de DNS y directorio (AE6).
# Uso: IP_DPL_LAB=172.18.0.2 ./scripts/comprobar.sh
# Basado en la plantilla del enunciado, ampliado con puertos, NS, /etc/hosts,
# ou=usuarios, maria, app.dpl.local y el login incorrecto (401).
set -u

IP_DPL_LAB="${IP_DPL_LAB:?Define IP_DPL_LAB con la IP de dpl-lab en dpl-net}"
BASE_DN="dc=dpl,dc=local"
USER_DN="${USER_DN:-uid=alumno,ou=usuarios,${BASE_DN}}"
USER_PASSWORD="${USER_PASSWORD:-CAMBIAR_ESTO}"
ZONE_FILE="/etc/bind/db.dpl.local"
FALLOS=0

ok()   { echo "[OK]   $1"; }
fallo(){ echo "[FALLO] $1"; FALLOS=$((FALLOS + 1)); }

echo "== DNS =="
docker exec dpl-lab named-checkconf && ok "named-checkconf" || fallo "named-checkconf"
docker exec dpl-lab named-checkzone dpl.local "$ZONE_FILE" | grep -q OK \
  && ok "named-checkzone" || fallo "named-checkzone"
docker exec dpl-lab pgrep -a named >/dev/null && ok "named activo" || fallo "named no activo"
docker exec dpl-lab ss -lunp | grep -q ':53 ' && ok "puerto 53/udp escuchando" || fallo "puerto 53/udp"

for nombre in www.dpl.local app.dpl.local; do
  ip="$(docker exec dpl-cliente dig +short "@${IP_DPL_LAB}" "$nombre" A)"
  [ -n "$ip" ] && ok "$nombre -> $ip" || fallo "$nombre no resuelve"
done
docker exec dpl-cliente dig +short "@${IP_DPL_LAB}" dpl.local NS | grep -q 'ns1.dpl.local.' \
  && ok "registro NS ns1.dpl.local" || fallo "registro NS"
docker exec dpl-cliente grep -q dpl.local /etc/hosts \
  && fallo "dpl-cliente tiene dpl.local en /etc/hosts" || ok "sin dpl.local en /etc/hosts del cliente"

echo "== Directorio =="
docker exec dpl-lab pgrep -a slapd >/dev/null && ok "slapd activo" || fallo "slapd no activo"
docker exec dpl-lab ss -lntp | grep -q ':389 ' && ok "puerto 389/tcp escuchando" || fallo "puerto 389/tcp"
docker exec dpl-lab ldapsearch -x -LLL -b "$BASE_DN" "(ou=usuarios)" dn | grep -q "dn:" \
  && ok "ou=usuarios en el directorio" || fallo "ou=usuarios ausente"
for usuario in alumno maria; do
  docker exec dpl-lab ldapsearch -x -LLL -b "$BASE_DN" "(uid=${usuario})" dn | grep -q "dn:" \
    && ok "usuario ${usuario} en el directorio" || fallo "usuario ${usuario} ausente"
done
docker exec dpl-cliente ldapwhoami -x -H "ldap://$IP_DPL_LAB" -D "$USER_DN" -w "$USER_PASSWORD" \
  | grep -q "dn:" && ok "bind correcto" || fallo "bind correcto rechazado"
docker exec dpl-cliente ldapwhoami -x -H "ldap://$IP_DPL_LAB" -D "$USER_DN" -w "incorrecta" >/dev/null 2>&1 \
  && fallo "un bind incorrecto no debería funcionar" || ok "bind incorrecto rechazado"

echo "== Integración =="
docker exec dpl-cliente curl -s -o /dev/null -w '%{http_code}' http://www.dpl.local \
  | grep -q '^200$' && ok "Web por nombre (200)" || fallo "Web por nombre"
docker exec dpl-cliente curl -s -o /dev/null -w '%{http_code}' http://app.dpl.local:8000/api/mensaje \
  | grep -q '^200$' && ok "aplicación por nombre (200)" || fallo "aplicación por nombre"
docker exec dpl-cliente curl -s -o /dev/null -w '%{http_code}' -X POST \
  -d "usuario=alumno&password=${USER_PASSWORD}" http://www.dpl.local/api/login \
  | grep -q '^200$' && ok "login LDAP (200)" || fallo "login LDAP"
docker exec dpl-cliente curl -s -o /dev/null -w '%{http_code}' -X POST \
  -d "usuario=alumno&password=incorrecta" http://www.dpl.local/api/login \
  | grep -q '^401$' && ok "login incorrecto rechazado (401)" || fallo "login incorrecto no devuelve 401"

echo
if [ "$FALLOS" -eq 0 ]; then
  echo "Resultado: todas las comprobaciones han pasado."
else
  echo "Resultado: $FALLOS comprobación(es) fallida(s)."
  exit 1
fi
