# est-infra

Infraestructura compartida del sistema **EST** (Estimaciones). Todo el stack
se levanta con Docker Compose desde esta carpeta.

## Archivos clave

- `DEVELOPMENT_PLAN.md` - plan maestro por fases.
- `docs/` - specs transversales (auth, diseno, ETL SAP).
- `docker-compose.yml` - servicios base (prod-like).
- `docker-compose.override.yml` - modo dev (hot-reload, Redis local, puertos expuestos).
- `.env` - UNICA fuente de verdad de variables (back + front + infra).
- `Makefile` - atajos de operacion.
- `sql/` - migraciones, seeds, vistas, stored procs contra DBEST.

## Base de datos

EST consume **DBEST** en el SQL Server corporativo `192.168.8.24`.
**No hay contenedor de BD** - DBEST la aprovisiona el DBA. Las migraciones se
aplican con `sqlcmd` instalado en el host contra esa BD.

## Quickstart

```bash
cp .env.example .env
# editar .env: rellenar DB_USER/DB_PASSWORD, secretos.
# Para dev sin Keycloak, dejar AUTH_DEV_BYPASS=true (es el default del override).

make db-ping       # valida conectividad con DBEST
make db-full       # migraciones + views + procs + seeds

make up-build      # primera vez: construye imagenes dev y levanta todo
make logs          # follow logs
```

Front dev: <http://localhost:4200>
Back API: <http://localhost:3000/api/v1/>

Al navegar a `http://localhost:4200` y hacer login, con `AUTH_DEV_BYPASS` el
backend crea un usuario `dev@greenvic.cl` con rol `est-admin` en DBEST y lo
deja logueado. No se llama a Keycloak.

## Estructura

```
est-infra/
├── DEVELOPMENT_PLAN.md
├── docker-compose.yml            # base (prod-like)
├── docker-compose.override.yml   # dev (aplicado por defecto)
├── Makefile
├── .env                          # fuente unica de verdad (NO comitear)
├── .env.example                  # plantilla
├── docs/
│   ├── AUTH_STANDARD.md
│   ├── DESIGN_STANDARD.md
│   ├── PROMPT_PLAN_EST.md
│   ├── SAP_ETL_AGENT_GUIDE.md
│   └── UP LEGACY.sql
└── sql/
    ├── 00_drop_all.sql
    ├── migrations/               # 0001..0007
    ├── seeds/
    ├── views/
    └── procs/
```

## Modo dev vs. prod

| | Dev (`make up`) | Prod (`make up-prod`) |
|---|---|---|
| Archivos compose | base + override | solo base |
| Dockerfile target | `dev` (hot-reload) | `runtime` (bundled) |
| Codigo fuente | bind mount de src/ | copiado a la imagen |
| Redis | `est-redis` local | `platform_cache` externo |
| Keycloak | bypass opcional | obligatorio |
| Puertos al host | 3000, 4200 expuestos | sin exponer (via router) |
| Cookie `Secure` | `false` | `true` |

## Targets de Make

| Target | Que hace |
|---|---|
| `make up` | Levanta en dev (hot-reload) |
| `make up-build` | `up` + reconstruye imagenes |
| `make up-prod` | Levanta en prod (requiere `platform_*`) |
| `make down` | Detiene el stack |
| `make reset` | Detiene + borra volumenes |
| `make restart-back` / `restart-front` | Reinicia un servicio |
| `make logs` / `logs-back` / `logs-front` | Follow logs |
| `make sh-back` / `sh-front` | Shell dentro del contenedor |
| `make db-ping` | Valida DBEST |
| `make db-migrate` | Aplica migraciones pendientes |
| `make db-full` | migrate + views + procs + seeds |
| `make db-reset-hard` | DESTRUCTIVO: drop + migrate + seed |
| `make db-shell` | `sqlcmd` interactivo |

## Auth en desarrollo

El backend soporta dos modos:

1. **Produccion/QA** - OIDC contra Keycloak (BFF segun `docs/AUTH_STANDARD.md`).
2. **Dev bypass** - `AUTH_DEV_BYPASS=true`. `GET /api/v1/auth/login` crea
   inmediatamente una sesion con el usuario de `AUTH_DEV_USER_*` y le asigna
   rol `est-admin`. **Nunca** se habilita con `NODE_ENV=production`
   (el back falla al arrancar si alguien lo intenta).

El override de dev activa el bypass por defecto para facilitar el desarrollo.

## Dependencias de red

- Dev: solo `est_default` (interna). Redis se levanta como `est-redis` local.
- Prod: ademas `platform_identity` (Keycloak) y `platform_cache` (Redis).
  Ambas deben existir antes de `make up-prod` (las levanta el proyecto
  `platform`).

La BD `DBEST@192.168.8.24` se alcanza por la red del host, fuera de Docker.
