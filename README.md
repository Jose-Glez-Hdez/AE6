# AE6 — DNS y servicio de directorio para el despliegue

Microproyecto de la UT6: BIND9 (zona `dpl.local`) y OpenLDAP (`dc=dpl,dc=local`)
en el contenedor `dpl-lab`, integrados con la aplicación de la UT4.

Repositorio remoto: [GitHub](https://github.com/Jose-Glez-Hdez/AE6)

Autoría: imagen oficial de Ubuntu — https://hub.docker.com/_/ubuntu

## 1. Instalación de BIND9 en dpl-lab

La instalación se hace dentro del contenedor `dpl-lab`:

```bash
docker exec dpl-lab bash -c "apt-get update && apt-get install -y bind9"
docker exec dpl-lab named -v
```

Salida:

```bash
docker exec dpl-lab named -v
BIND 9.18.39-0ubuntu0.24.04.9-Ubuntu (Extended Support Version) <id:>
docker exec dpl-lab ls /etc/bind
bind.keys
db.0
db.127
db.255
db.empty
db.local
named.conf
named.conf.default-zones
named.conf.local
named.conf.options
rndc.key
zones.rfc1918
```

## 2. Fichero de zona dpl.local

IPs del entorno (obtenidas con `docker inspect`):

| Contenedor | Red | IP | Nombre DNS |
|---|---|---|---|
| dpl-lab | dpl-net | 172.18.0.2 | ns1.dpl.local |
| ae4-nginx-1 | ae4_default | 172.20.0.5 | www.dpl.local |
| ae4-app-1 | ae4_default | 172.20.0.3 | app.dpl.local |

```bash
docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' dpl-lab
docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}} {{end}}' ae4-nginx-1 ae4-app-1
```

El fichero `dns/dpl.local.db` se copia a `/etc/bind/db.dpl.local` en dpl-lab:

```bash
docker exec -i dpl-lab bash -c 'cat > /etc/bind/db.dpl.local' < dns/dpl.local.db
```

Significado de los registros:

- **SOA** (Start of Authority): identifica el servidor principal de la zona
  (`ns1.dpl.local.`), el contacto del administrador (`admin.dpl.local.`, es decir,
  admin@dpl.local), el **serial** (versión de la zona, formato AAAAMMDDnn, que se
  incrementa en cada cambio) y los temporizadores refresh, retry, expire y TTL mínimo.
- **NS**: indica qué servidor es autoritativo para `dpl.local` (`ns1.dpl.local.`).
  Como ese nombre pertenece a la propia zona, necesita su registro A (`ns1`).
- **A**: asocia un nombre con una IPv4. `www` apunta al contenedor nginx (servidor
  Web) y `app` al contenedor Django/Gunicorn (servidor de aplicaciones).
  `app.dpl.local` necesita su propio registro A porque es un servicio distinto, con
  otra IP: sin él, el nombre no resuelve (NXDOMAIN) y no se puede acceder por
  nombre al servidor de aplicaciones.
- `$ORIGIN dpl.local.` completa los nombres relativos, y los nombres absolutos llevan
  punto final.

Validación del fichero de zona:

```bash
docker exec dpl-lab named-checkzone dpl.local /etc/bind/db.dpl.local
zone dpl.local/IN: loaded serial 2026111501
OK
```