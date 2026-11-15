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
