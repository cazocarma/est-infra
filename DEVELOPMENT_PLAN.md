# EST — Plan de Desarrollo Completo

**Sistema:** Estimaciones (EST) — plataforma de estimacion de cosecha agricola para Greenvic.
**Stack:** `est-front-ng` (Angular 21) + `est-back` (Node.js + Express) + `est-infra` (Docker Compose, SQL Server, migraciones).
**Ultima revision:** 2026-04-16.

Este documento es la fuente de verdad del roadmap de EST. Se actualiza a medida que se completan fases. Cada fase entrega una **rebanada vertical funcional** (BD + API + UI) que puede probarse y usarse en produccion parcial.

---

## 0. Indice

1. Resumen ejecutivo y grafo de dependencias
2. Convenciones transversales
3. Modelo de datos objetivo (resumen)
4. Fases de desarrollo (0 → 11)
5. Hitos de entrega y complejidad
6. Tabla consolidada de endpoints
7. Decisiones arquitectonicas
8. Pendientes / riesgos

---

## 1. Resumen ejecutivo y grafo de dependencias

| # | Fase | Alcance | Complejidad | Depende de |
|---|---|---|---|---|
| 0 | Infraestructura + scaffolding | Docker, BD, proyectos vacios compilables, CI minima | M | — |
| 1 | Autenticacion BFF (OIDC + Keycloak) | Login/logout/me/callback, sesion Redis, CSRF, auditoria | L | 0 |
| 2 | Maestros internos (temporadas, plantas, unidades, catalogos) | CRUD de datos que NO vienen de SAP | M | 1 |
| 3 | Sincronizacion SAP (productor, especie, variedad, grupo, manejo, envase, calibres…) | Jobs ETL + tablas *EstadoSap*, UI de monitoreo | L | 1, 2 |
| 4 | Agronomos y asignaciones (Usuario ↔ Agronomo ↔ Productor-Variedad) | UI de asignacion y roles | M | 1, 3 |
| 5 | Calendario de estimacion general (ventanas por especie) | `FechaEstimacionGeneral` + UI | S | 2, 3 |
| 6 | Estimacion **General** con control de version | Versionado snapshot, cierre/reapertura, volumen/semana/calibre/tipificacion | XL | 3, 4, 5 |
| 7 | Estimacion **Bisemanal** con control de version | Desglose diario, cierre por periodo, control fechas bisemanal | XL | 3, 4, 6 (reutiliza patron) |
| 8 | Reportes + vistas BI | VW_ESTIMACION_BISEMANAL_HISTORICO + NORTE/SUR + DICCIONARIO_DATOS, reportes PDF/XLSX | L | 6, 7 |
| 9 | Visitas de terreno (GPS + fotos) | Carga de visitas desde movil/web, almacenamiento de imagenes | L | 4 |
| 10 | Carga masiva (Excel/CSV) | Import de estimaciones y maestros, logs de carga | L | 6, 7 |
| 11 | Dashboard + monitoreo operacional | KPIs, health, alertas de cierres pendientes | M | 6, 7, 8 |

```
0 ── 1 ── 2 ── 3 ── 4 ── 5 ── 6 ── 7 ── 8 ── 10 ── 11
                        │              │              └─ 9 (paralelo tras 4)
```

**Camino critico:** 0 → 1 → 2 → 3 → 4 → 5 → 6 → 7 → 8.
**Paralelizables:** 9 (desde 4), 10 (desde 6-7), 11 (desde 8).

---

## 2. Convenciones transversales

### 2.1 Stack confirmado

| Area | Tecnologia | Version | Notas |
|---|---|---|---|
| Frontend | Angular standalone + Tailwind 3.4 | 21.x | Signals, OnPush, lazy routes. Paleta **Forest Green** (`DESIGN_STANDARD.md`). |
| Backend | Node.js + Express | 22 LTS + Express 4.x | Solo JS/TS — **TypeScript** obligatorio. Arquitectura por capas (controller → service → repo). |
| BD aplicacion | SQL Server (BD **DBEST** en `192.168.8.24`, aprovisionada por DBA) | — | **Externa al stack**. Migraciones aplicadas con `sqlcmd` via `make db-migrate`. Scripts versionados por timestamp en `sql/migrations/`. |
| BD legacy (solo lectura para SAP sync) | SQL Server legacy | — | Acceso via `greenvic-sap-adapter` o jobs ETL existentes. |
| Cache / sesion | Redis | 7.x | Red externa `platform_cache`, DB asignada a EST → **DB 5** (siguiente libre despues de CFL=0, CDC=3). |
| IdP | Keycloak (cluster `platform_identity`) | 26.x | Realm `Greenvic`. Cliente `est-back`. Rol `est-user`. |
| Orquestacion | Docker Compose | — | Router NGINX `greenvic-router` expone los puertos. EST no publica puertos. |
| Observabilidad | `pino` (back) + `ngx-logger` (front) + HTTP access log en NGINX | — | JSONL estructurado. |

### 2.2 Principios de codigo (obligatorios)

- **Clean Architecture por rebanadas** (`feature-based`, no `layer-based` en el front/back).
- **SOLID** — especialmente SRP y DIP. Cada controller recibe sus services por inyeccion.
- **Sin legacy**: nada de `nvarchar(max)` por defecto, nada de GUIDs en la capa de aplicacion (ver 2.4).
- **Sin patches**: cualquier cruft legacy (`temp_*`, `OLD*`, `acofre01`, `asoex_condicionfruta`) queda fuera. Se migra solo lo necesario, con tipos fuertes.
- **Ninguna app abre puertos al host** — todo pasa por el router.
- **TypeScript strict** en back y front (`strict: true` + `noUncheckedIndexedAccess`).
- **Sin comentarios triviales**. Comentarios solo donde el *por que* no es evidente.

### 2.3 Convenciones de naming

| Elemento | Convencion | Ejemplo |
|---|---|---|
| Schema de BD | `est` (dominio propio), `sap` (externo), `meta` (tracking). No `dbo`. | `est.Temporada` |
| Tabla BD | `PascalCase` singular | `Temporada`, `ProductorVariedadSap` |
| Columna BD | `PascalCase` | `FechaCreacion`, `KilosLunes` |
| PK | `<Tabla>Id` (sin `Id` generico) | `TemporadaId`, `UsuarioId` |
| FK | `<TablaReferida>Id` | `ProductorId`, `UsuarioId` (CreatedBy/UpdatedBy) |
| Constraint PK | `PK_<schema>_<Tabla>` | `PK_est_Temporada` |
| Constraint FK | `FK_<schema>_<Tabla>_<Referida>` | `FK_est_Temporada_Created` |
| Constraint UNIQUE | `UQ_<schema>_<Tabla>_<Cols>` | `UQ_est_Temporada_Anio_Prefijo` |
| Constraint CHECK | `CK_<schema>_<Tabla>_<Regla>` | `CK_est_Planta_Zona` |
| Default | `DF_<schema>_<Tabla>_<Col>` | `DF_est_Temporada_Activa` |
| Indice | `IX_<schema>_<Tabla>_<Cols>` (unico filtrado: `UX_`) | `UX_est_Temporada_Activa` |
| Trigger | `TR_<Tabla>_<Evento>` bajo su schema | `est.TR_Temporada_UpdatedAt` |
| Endpoint | `/api/v1/<recurso-kebab>` | `/api/v1/estimaciones-generales` |
| DTO | `<Recurso><Operacion>Dto` | `EstimacionCrearDto`, `EstimacionVolumenDto` |
| Ruta Angular | `/<recurso-kebab>` | `/estimaciones-generales`, `/productores` |

### 2.4 Estrategia de IDs

- **Dominio nuevo:** `BIGINT IDENTITY(1,1)` en BD, `number` en TS.
- **Tablas espejo de SAP** (`*Sap`): conservan su **codigo SAP** como `CodigoSap NVARCHAR(32) UNIQUE`, pero la PK interna es `BIGINT IDENTITY`. Esto permite reindexar sin tocar las referencias cruzadas.
- **Sub del IdP:** `NVARCHAR(64) UNIQUE` en `Usuario.Sub` (ver `AUTH_STANDARD.md §8.bis`).
- **GUIDs**: se eliminan. Solo se conservan si una integracion externa (BI) los consume por nombre — en cuyo caso se dejan como `UNIQUEIDENTIFIER` con `NEWSEQUENTIALID()` y nunca se expone al front.

### 2.5 Contrato HTTP transversal

- Envelope de paginacion (ver `DESIGN_STANDARD.md §13.2`):

```json
{
  "data": [ /* ... */ ],
  "pagination": { "page": 1, "page_size": 25, "total": 123, "total_pages": 5 }
}
```

- Envelope de error:

```json
{ "error": { "code": "validation_failed", "message": "...", "details": [ /* ... */ ] } }
```

- Timestamps UTC ISO 8601 en toda la API.
- Todos los mutating endpoints exigen `X-CSRF-Token` (§5 de `AUTH_STANDARD.md`).
- Paginacion via `?page=1&page_size=25&sort=campo:asc&q=...`.

### 2.6 Workflow de migraciones

Cada migracion vive en `est-infra/sql/migrations/` con el formato `YYYYMMDDHHMM__descripcion.sql`. Ejemplo:

```
est-infra/sql/
├── migrations/
│   ├── 202604160001__init_schema.sql
│   ├── 202604160002__temporada.sql
│   └── ...
├── seeds/
│   ├── 01_roles.sql
│   └── 02_temporadas.sql
├── views/
│   └── vw_estimacion_bisemanal_historico.sql
└── procs/
    └── sp_cierre_estimacion_control_version.sql
```

- `Makefile` expone: `make db-up`, `make db-migrate`, `make db-seed`, `make db-reset`.
- Cada migracion es idempotente (usa `IF NOT EXISTS` o patron `SCHEMA BINDING`).
- No se permiten migraciones destructivas sin aprobacion explicita + backup.

---

## 3. Modelo de datos objetivo (resumen)

### 3.0 Convencion de schemas

Solo **tres** schemas se usan en DBEST para EST:

| Schema | Rol | Observacion |
|---|---|---|
| `est`  | Dominio propio del sistema — **todo lo que pertenece a EST** (identidad, maestros, estimaciones, carga, vistas BI, etc.) | Unico schema de dominio. |
| `sap`  | Espejo de maestros SAP (**externo al sistema**) | Se puebla por sync desde el adapter SAP en Fase 3. |
| `meta` | Tracking de migraciones aplicadas | Solo la tabla `meta.Migracion`. |

**`dbo` NO se usa para objetos del sistema.** Queda reservado para lo que mantenga el DBA fuera de EST.

### 3.1 Convenciones de nombres

- **Tablas:** `PascalCase` singular (`Temporada`, `EstimacionBisemanal`).
- **Columnas:** `PascalCase` (`FechaInicio`, `KilosLunes`).
- **Primary key:** `<Tabla>Id` (`TemporadaId`, `UsuarioId`). Nada de `Id` generico.
- **Foreign key:** `<TablaReferida>Id`, excepto el caso donde la misma tabla referencia dos veces a `Usuario` (usamos `CreatedBy` / `UpdatedBy` con FK a `UsuarioId`).
- **Constraints nombrados:** `PK_est_<Tabla>`, `FK_est_<Tabla>_<Referida>`, `UQ_est_<Tabla>_<Cols>`, `CK_est_<Tabla>_<Regla>`, `DF_est_<Tabla>_<Col>`, `IX_est_<Tabla>_<Cols>`, `UX_est_<Tabla>_<Cols>` para indices filtrados unicos.
- **Triggers:** `TR_<Tabla>_UpdatedAt` (siempre bajo el schema correspondiente).

### 3.2 Dominios y tablas (agrupados logicamente dentro del schema `est`)

| Grupo logico | Tablas (prefijo `est.`) |
|---|---|
| Identidad y auditoria | `Usuario`, `Rol`, `UsuarioRol`, `Auditoria` |
| Maestros internos | `Temporada`, `Planta`, `Unidad`, `UnidadKilos`, `PesoPromedio`, `GrupoProductor`, `EspecieTipificacion`, `Condicion`, `Destino`, `TipoCalidad`, `TipoColor`, `TipoEnvase`, `FechaEstimacionGeneral` |
| Agronomos y asignaciones | `Agronomo`, `AgronomoProductorVariedad`, `AgronomoVisita`, `AgronomoVisitaDocumento` |
| Estimacion general (vigente) | `EstimacionControlVersion`, `Estimacion`, `EstimacionVolumen`, `EstimacionVolumenSemana`, `EstimacionCalibre`, `EstimacionTipificacion` |
| Snapshots de version general | `EstimacionVersion`, `EstimacionVolumenVersion`, `EstimacionVolumenSemanaVersion`, `EstimacionCalibreVersion`, `EstimacionTipificacionVersion` |
| Bisemanal | `EstimacionBisemanal`, `EstimacionBisemanalVersion`, `EstimacionBisemanalControlVersion`, `ControlEstimacionBisemanal`, `ControlDetalleEstimacionBisemanal` |
| Carga masiva | `CargaEstimacion`, `CargaEstimacionFiltro`, `CargaEstimacionVersion` |
| Vistas BI | Vistas `VW_EstimacionBisemanalHistorico`, `VW_EstimacionBisemanalNorte`, `VW_EstimacionBisemanalSur`, `VW_DiccionarioDatos` + tabla denormalizada `EstimacionBisemanalBI` |

Bajo `sap.*` (espejo externo, Fase 3): `ProductorSap`, `VariedadSap`, `EspecieSap`, `GrupoVariedadSap`, `CalibreSap`, `EnvaseSap`, `ManejoSap`, `CentroSap`, `TipoFrioSap`, `ProgramaSap`, `ProductorVariedadSap`, `ProductorVariedadSemanaSap`, `SyncLog`.

### 3.3 Reset / limpieza de BD

- **`make db-drop-all`** ejecuta `sql/00_drop_all.sql` y borra **todos** los objetos (FKs, checks, triggers, views, procs, funcs, tablas, types, sequences) de `est`, `sap` y `meta`, incluyendo los schemas mismos. No toca `dbo`.
- **`make db-reset-hard`** encadena drop + migraciones + views + procs + seeds para reconstruir desde cero. Ambos targets piden confirmacion (`yes`).

Eliminaciones explicitas vs. legacy (no se migran):

- `__EFMigrationsHistory`, `acofre01`, `asoex_condicionfruta`, `TMP_v1_Monitor`.
- `temp_carga_*` — reemplazadas por `est.CargaEstimacion*`.
- `UsuarioImpersonar` — reemplazado por auditoria de Keycloak.
- `Z_SEMANAS` — reemplazada por funcion deterministica `est.fn_SemanaIso(fecha)` o tabla regenerable.

### 3.1 Constraints y tipos clave

- Fechas: `DATE` o `DATETIME2(0)`, nunca `DATETIME`.
- Porcentajes: `DECIMAL(9, 4)` — 4 decimales cubren los casos reales.
- Kilos: `DECIMAL(14, 2)`.
- Textos cortos (codigo, RUT, nombres): `NVARCHAR(N)` con N acotado (ver `UP LEGACY.sql` como referencia de longitud real).
- Flags: `BIT NOT NULL DEFAULT 0`.
- Todas las tablas llevan `CreatedAt DATETIME2(0) NOT NULL DEFAULT SYSUTCDATETIME()`, `UpdatedAt`, `CreatedBy`, `UpdatedBy` (FK a `auth.Usuario`).

### 3.2 Regla de versionado (estimaciones)

Tanto la estimacion general como la bisemanal implementan el **patron snapshot**:

1. Una tabla `*ControlVersion` con `VersionId`, `NumeroVersion`, `FechaApertura`, `FechaCierre`, `Estado` (`Abierta` / `Cerrada` / `Anulada`).
2. Las tablas vivas (`Estimacion*`) tienen FK a la version activa de cada temporada.
3. Al cerrar una version:
   - Se copian todos los registros vivos a las tablas `*Version` como snapshot inmutable (`EstimacionVersion`, `EstimacionVolumenVersion`, etc.).
   - Se crea una nueva version con `NumeroVersion + 1` y `Estado = Abierta`.
4. Las modificaciones solo se permiten si `GETUTCDATE() < FechaCorte` de la version y si el periodo que se esta modificando **aun no ha ocurrido** (regla de negocio):
   - General: semana `n` solo se puede editar si la semana actual < `n`.
   - Bisemanal: solo se puede editar la semana actual + siguiente.

---

## 4. Fases de desarrollo

### Fase 0 — Infraestructura y scaffolding · **Complejidad: M** · **Estado: Completada — 2026-04-16**

**Alcance de negocio:** ninguno todavia — prepara la base para que las fases siguientes tengan un entorno reproducible.

**Entregado:**
- `est-infra/docker-compose.yml` + `Makefile` + `.env.example` (conectado a BD externa **DBEST@192.168.8.24**, sin contenedor de BD).
- Migraciones `202604160001__init_schema.sql` (8 schemas + permisos) y `202604160002__auth.sql` (Usuario/Rol/UsuarioRol/Auditoria + trigger UpdatedAt).
- Seed `01_roles.sql` con `est-admin`, `est-user`, `est-bi`.
- `est-back/` scaffold: Express + TS strict + pino + mssql + ioredis + health endpoints (`/health`, `/health/ready`).
- `est-front-ng/` scaffold: Angular 21 standalone + Tailwind (paleta Forest exacta), `WorkspaceShell`, `DashboardComponent` placeholder.

**BD**

- `docker-compose.yml` en `est-infra/` con servicios:
  - `est-back` (node:22-alpine, build del back; se conecta a BD externa DBEST y a Redis/Keycloak por redes `platform_*`).
  - `est-front` (build Angular servido por NGINX embebido, NO expone puerto).
- Redes externas: `platform_identity`, `platform_cache`, mas la red interna `est_default`.
- **BD externa**: `DBEST` en `192.168.8.24` (SQL Server corporativo), aprovisionada fuera de banda por DBA. No hay contenedor de BD en el stack.
- Migracion `202604160001__init_schema.sql` crea los schemas `auth`, `sap`, `maestro`, `agro`, `est`, `bise`, `carga`, `bi`.

**Backend (`est-back/`)**

```
est-back/
├── src/
│   ├── app.ts                  # Express bootstrap
│   ├── server.ts               # entry point
│   ├── config/
│   │   ├── env.ts              # zod-validated env
│   │   └── logger.ts           # pino
│   ├── infra/
│   │   ├── db.ts               # mssql pool
│   │   └── redis.ts            # ioredis
│   ├── middleware/
│   │   ├── error.ts
│   │   ├── notFound.ts
│   │   └── requestId.ts
│   └── features/               # una carpeta por bounded context
│       └── health/
│           └── health.controller.ts  # GET /health
├── tsconfig.json               # strict
├── package.json
├── Dockerfile
└── .env.example
```

- Scripts: `dev` (tsx watch), `build` (tsc), `start` (node dist), `lint` (eslint), `test` (vitest).
- Git hook `pre-commit`: `lint` + `typecheck`.

**Frontend (`est-front-ng/`)**

```
est-front-ng/
├── src/
│   ├── app/
│   │   ├── core/               # services, guards, interceptors
│   │   ├── features/
│   │   │   └── login/          # placeholder
│   │   ├── shared/
│   │   ├── app.routes.ts
│   │   ├── app.config.ts
│   │   └── app.component.ts
│   ├── styles.css              # Tailwind + tokens Forest
│   └── index.html              # fonts Inter
├── tailwind.config.js          # palette forest, shadow nature, animations
├── angular.json
└── package.json
```

- Tailwind configurado con la paleta **forest-50 → forest-950** exacta de `DESIGN_STANDARD.md §2.1`.
- Variables CSS en `:root` segun `§3` del estandar.
- Estructura de carpetas segun `§19`.

**Infraestructura (`est-infra/`)**

```
est-infra/
├── DEVELOPMENT_PLAN.md         # este documento
├── docs/                       # specs (ya existe)
├── docker-compose.yml
├── Makefile
├── .env.example
└── sql/
    ├── migrations/
    ├── seeds/
    ├── views/
    └── procs/
```

**Aceptacion Fase 0:**

- `make db-ping` responde `GETDATE()` desde DBEST con las credenciales del `.env`, y `make up` levanta `est-back` + `est-front` con `docker compose ps` reportandolos `running`.
- `curl http://router/api/v1/health` → `200 OK`.
- `curl http://router/` sirve el shell Angular vacio (pantalla de login placeholder).
- La BD tiene todos los schemas creados y un usuario seed en `auth.Usuario` (para desarrollo sin Keycloak).
- `npm run lint && npm run typecheck` pasan en ambos proyectos.

---

### Fase 1 — Autenticacion BFF (OIDC + Keycloak) · **Complejidad: L** · **Estado: Completada (pendiente prueba e2e contra Keycloak) — 2026-04-16**

**Alcance de negocio:** el usuario se loguea con su cuenta corporativa via Keycloak; solo accede con rol `est-user`; la sesion dura 8 h con refresh silencioso.

**Entregado (back):**
- `src/features/auth/` — `auth.controller.ts` (login/callback/me/logout), `auth.service.ts` (openid-client + PKCE S256 + refresh + end_session), `auth.repository.ts` (MERGE por `Sub`), `auth.audit.ts` (LOGIN/LOGOUT/CSRF_FAIL/UNAUTHORIZED/FORBIDDEN_ROLE/REFRESH_FAIL).
- Middleware: `session` (Redis DB 5, cookie `est.sid` HttpOnly/Secure/SameSite=Strict), `authn` (valida rol y refresca proactivamente), `csrf` (timingSafeEqual), `requestId`, `error`.
- Rate limiting en `/auth/login` y `/auth/callback`.

**Entregado (front):**
- `core/services/auth.store.ts` — signals (`user`, `csrfToken`, `initials`, `isAuthenticated`).
- `core/guards/authn.guard.ts`, `core/interceptors/csrf.interceptor.ts`, `core/interceptors/network-error.interceptor.ts`.
- `features/login/login.component.ts` — sin formulario, redirige a `/api/v1/auth/login`.
- `shared/workspace-shell/workspace-shell.component.ts` — sidebar forest, menu, logout.
- `shared/toast/toast-host.component.ts`.

**Pendiente para activacion productiva:**
- Crear `platform/keycloak/import/est-realm.json` y aplicarlo con `keycloak-config-cli`.
- Configurar vhost `greenvic-router` para que `*.est` enrute a `est-front:80` y `/api/v1/*` a `est-back:3000`.

Sigue **`AUTH_STANDARD.md` al pie de la letra**.

**BD**

- Migracion: `auth.Usuario(Id, Sub UNIQUE, Usuario, Nombre, Email, PrimaryRole, Activo, CreatedAt, UpdatedAt)`.
- `auth.Auditoria(Id, UsuarioId NULL, Operacion, Origen, Detalle NVARCHAR(MAX), FechaUtc, RequestId, IpOrigen)`.
- Seed: `INSERT Rol` con `est-admin`, `est-user`, `est-bi`.

**Backend**

- Nueva carpeta `src/features/auth/`:
  - `auth.routes.ts` — `GET /auth/login`, `GET /auth/callback`, `GET /auth/me`, `POST /auth/logout`.
  - `auth.service.ts` — wraps `openid-client` (panva). PKCE S256. Valida `state`, `nonce`, `id_token` (iss+aud+signature+nonce).
  - `auth.repository.ts` — upsert en `auth.Usuario` por `Sub`.
  - `auth.audit.ts` — persistencia de eventos `LOGIN`/`LOGOUT`/`REFRESH_FAIL`/`CSRF_FAIL`/`UNAUTHORIZED`/`FORBIDDEN_ROLE`.
- Middleware:
  - `sessionMiddleware` — `express-session` + `connect-redis` (DB 5), cookie `est.sid` HttpOnly/Secure/SameSite=Strict.
  - `authnMiddleware` — valida `req.session.userId` y refresca `accessToken` si faltan <30s. Responde `401 sesion_expirada` si falla refresh.
  - `csrfMiddleware` — compara `X-CSRF-Token` con `req.session.csrfToken` usando `timingSafeEqual`.
  - `rateLimit` en `/auth/login` y `/auth/callback`.
- Variables de entorno nuevas (ver `AUTH_STANDARD.md §12`).
- Keycloak: crear `est-realm.json` en `platform/keycloak/import/` con cliente `est-back`, rol `est-user`, audience mapper, PKCE S256, redirect URI unico.

**Frontend**

- Guard `authnGuard` — hace `GET /auth/me` al resolver la ruta; si `401` → redirige a `/login`.
- Interceptor `csrf.interceptor.ts` — lee `csrfToken` de un `AuthStore` (signal) y lo inyecta en `X-CSRF-Token` para metodos mutantes.
- Interceptor `network-error.interceptor.ts` — en `401` destruye estado y redirige a `/login`; en `5xx` muestra toast.
- Pagina `LoginComponent` — hace `window.location.href = '/api/v1/auth/login?returnTo=/'`. No hay formulario de credenciales. Diseno segun `DESIGN_STANDARD.md §8.2`.
- `WorkspaceShellComponent` — sidebar gradient forest, header, `<router-outlet>`. Muestra iniciales del usuario (circulo forest-500).
- `AuthStore` (signals) — `user`, `csrfToken`, `isLoading`. Se hidrata al cargar la app llamando `GET /auth/me`.

**Aceptacion Fase 1:**

- Login completo contra Keycloak: usuario con rol `est-user` → entra; sin el rol → `403` y se registra `FORBIDDEN_ROLE` en auditoria.
- Storage del browser vacio de tokens (devtools → Application → Storage).
- Cookie `est.sid` con `HttpOnly; Secure; SameSite=Strict`.
- Logout invoca `end_session_endpoint` en Keycloak (logout federado).
- Refresh silencioso: manipulando el reloj del browser, al expirar `accessToken` (5 min), la siguiente llamada se refresca sin que el usuario note nada.
- CSRF: un `POST` sin `X-CSRF-Token` responde `403`.
- Auditoria: `SELECT * FROM auth.Auditoria` muestra eventos `LOGIN`/`LOGOUT` con `sub` truncado.

---

### Fase 2 — Maestros internos · **Complejidad: M** · **Estado: Completada — 2026-04-16**

**Alcance de negocio:** administrar temporadas, plantas, unidades de empaque, pesos promedio, catalogos (`Condicion`, `Destino`, `TipoCalidad`, `TipoColor`, `TipoEnvase`), grupos de productor y tipificacion por especie.

**Entregado:**

- **BD:** migracion `202604160003__maestros.sql` con `Temporada` (indice unico filtrado sobre `Activa = 1`), `Planta`, `Unidad`, `GrupoProductor`, `UnidadKilos`, `PesoPromedio`, y los 5 catalogos simples. Triggers de `UpdatedAt`. Seed `02_catalogos.sql` con MERGE idempotente.
- **Back:** helpers `shared/pagination.ts`, `shared/validate.ts`, `middleware/requireRole.ts` (cache admin 60s). Feature `temporadas` con activacion transaccional SERIALIZABLE. Routers dedicados para `plantas`, `unidades`, `grupos-productor`. Factory `catalogo-simple.factory.ts` instanciado 5 veces.
- **Front:** `CrudApiService<T>` generico, `DataTableComponent` (sort, paginacion, actions, toolbar projection), `ModalComponent`, `FormModalComponent` (schema declarativo de campos). `mantenedores-home` con grid de 9 tarjetas, pages especificas para temporadas/plantas/unidades/grupos-productor, y `catalogo-page` generica reutilizada por los 5 catalogos (lookup por `:catalogo` param).
- **Pendiente en esta fase:** `PesoPromedio`, `EspecieTipificacion` y `UnidadKilos↔Variedad` — se completan cuando este `sap.*` (Fase 3), ya que dependen de `EspecieSap`/`VariedadSap`.

Detalle historico (antes de la implementacion) se conserva abajo.

**BD**

- `maestro.Temporada(Id, Anio, Prefijo, Activa, FechaInicio, FechaFin, …)`.
- `maestro.Planta(Id, Codigo UNIQUE, Nombre, Direccion, EsExterna BIT, Activa BIT, …)`.
- `maestro.Unidad(Id, Codigo UNIQUE, Nombre, …)`.
- `maestro.UnidadKilos(Id, VariedadSapId FK NULL, UnidadId FK, Kilos DECIMAL(10,4), KilosCajaEquivalente DECIMAL(10,4), …)` (la FK a variedad se agrega en Fase 3).
- `maestro.PesoPromedio(Id, EspecieSapId FK NULL, TipoEnvaseId FK, Peso DECIMAL(10,4), …)`.
- `maestro.GrupoProductor(Id, Nombre, …)`.
- `maestro.EspecieTipificacion(Id, EspecieSapId FK NULL, Categoria NVARCHAR(50), Orden INT, …)`.
- Tablas de catalogo: `Condicion`, `Destino`, `TipoCalidad`, `TipoColor`, `TipoEnvase` — todas con `(Id, Codigo UNIQUE, Nombre, Activo BIT)`.
- Seeds iniciales con los valores existentes en el legacy (extraidos de `UP LEGACY.sql`).

**Backend**

Un CRUD generico reutilizable, pero con un controller por recurso para respetar SRP. Cada recurso expone:

| Metodo | Ruta | Descripcion |
|---|---|---|
| `GET` | `/api/v1/temporadas` | Paginado, filtros `?anio`, `?activa`, `?q` |
| `GET` | `/api/v1/temporadas/:id` | Detalle |
| `POST` | `/api/v1/temporadas` | Crear |
| `PUT` | `/api/v1/temporadas/:id` | Actualizar |
| `PATCH` | `/api/v1/temporadas/:id/activar` | Marcar como activa (desactiva las demas) |
| `DELETE` | `/api/v1/temporadas/:id` | Soft delete (`Activa = 0`) |

Mismo contrato para: `/plantas`, `/unidades`, `/catalogos/condicion`, `/catalogos/destino`, `/catalogos/tipo-calidad`, `/catalogos/tipo-color`, `/catalogos/tipo-envase`, `/grupos-productor`, `/tipificaciones-especie`.

Validacion con `zod`. Autorizacion: solo rol `est-admin` puede mutar; cualquier usuario autenticado puede leer.

**Frontend**

- Ruta `/mantenedores` con submenu en el sidebar.
- `features/mantenedores/temporadas/temporadas.component.ts` — tabla segun `DESIGN_STANDARD.md §7.3`, paginacion, filtros, boton **Nueva Temporada** (modal mediano `max-w-2xl`).
- `TemporadaFormModalComponent` — formulario reactivo con validacion, header con gradiente forest, footer con `btn-secondary` + `btn-primary`.
- Mismo patron para cada mantenedor.
- Servicio comun `CrudApiService<T>` que encapsula el envelope de paginacion.

**Aceptacion Fase 2:**

- Puedo crear/editar/eliminar temporadas y marcar una como activa — solo una activa a la vez.
- Lo mismo para los 8 mantenedores restantes.
- Los seeds dejan los catalogos listos para que las fases siguientes los usen.
- `AUDIT`: cualquier mutacion queda en `auth.Auditoria` con `Operacion='maestro.temporada.crear'` (o similar).
- Usuario sin rol `est-admin` ve los mantenedores en modo lectura y los botones de mutacion aparecen deshabilitados con tooltip.

---

### Fase 3 — Sincronizacion SAP · **Complejidad: L** · **Estado: Completada — 2026-04-16 (sujeto a ajuste de mapping con SAP real)**

**Alcance de negocio:** traer y mantener sincronizados los maestros que nacen en SAP: especies, variedades, grupos de variedad, productores, calibres por variedad, semanas validas por productor-variedad, envases, manejos, centros, tipos de frio, programas.

**Entregado:**

- **BD:** migracion `202604160004__sap.sql` con `sap.EspecieSap`, `GrupoVariedadSap`, `VariedadSap`, `CalibreSap`, `ProductorSap`, `ProductorVariedadSap`, `ProductorVariedadSemanaSap` y los 5 lookups (`EnvaseSap`, `ManejoSap`, `CentroSap`, `TipoFrioSap`, `ProgramaSap`) + `sap.SyncLog`. Tambien cierra las FKs pendientes `est.UnidadKilos.VariedadSapId -> sap.VariedadSap` y `est.PesoPromedio.EspecieSapId -> sap.EspecieSap`.
- **Back:**
  - `infra/sap-etl.client.ts` - cliente HTTP del adapter ETL (Modo A: `POST /api/v1/sap/rfc/query`). Timeouts, envelope estandar, manejo de errores 502/504.
  - `features/sap-sync/` - orquestador con 3 estrategias de MERGE (simple lookup, grupo-variedad con JOIN a EspecieSap, variedad con JOIN a Especie+Grupo). Bulk copy a tabla temporal en transaccion.
  - Mapping declarativo en `sap-sync.mapping.ts` - los nombres `ZEST_*` y los campos SAP son **placeholders** que el DBA/SAP analyst debe validar contra el destino PRD real antes del primer sync productivo.
  - Endpoints: `GET /api/v1/sap-sync/estado`, `GET /api/v1/sap-sync/logs`, `POST /api/v1/sap-sync/run` (admin + CSRF).
  - `features/sap/sap-read.controller.ts` - routers de lectura para `especies`, `grupos-variedad`, `variedades`, `productores`, `envases`, `manejos`, `centros`, `tipos-frio`, `programas` bajo `/api/v1/sap/...`.
- **Front:**
  - `/sap-sync` - pagina con 9 cards (una por entidad) + tabla historica de `SyncLog`. Boton "Sincronizar todo" y por entidad. Warning visible si el adapter no esta configurado.
  - `SapSyncService` (HttpClient) + `SapSyncPageComponent`.
  - **Sub-fase 3.2 (2026-04-17):** tarjetas de maestros SAP integradas en `/mantenedores` (`features/mantenedores/sap/`). Cada entidad tiene su propia pagina `/mantenedores/sap/<entidad>` con `DataTable` read-only sobre `/api/v1/sap/<entidad>` y boton **"Sincronizar con SAP"** que invoca `POST /api/v1/sap-sync/run` con `{ entidades: [<entidad>] }`. Config declarativa en `sap-maestro.config.ts`; un unico componente generico `SapMaestroPageComponent` sirve a las 9 entidades. `/sap-sync` se mantiene como vista consolidada (historial + sync masivo).

**Endpoints expuestos:**

| Metodo | Path | Rol |
|---|---|---|
| GET | `/api/v1/sap-sync/estado` | est-user |
| GET | `/api/v1/sap-sync/logs?limit=50` | est-user |
| POST | `/api/v1/sap-sync/run` | est-admin (body: `{entidades?, rowCount?}`) |
| GET | `/api/v1/sap/{especies,grupos-variedad,variedades,productores,envases,manejos,centros,tipos-frio,programas}` | est-user (paginado, solo lectura) |

**Pendientes para activacion productiva:**

- [ ] Confirmar con SAP analyst los nombres reales de las tablas `ZEST_*` y el set de campos. Ajustar `sap-sync.mapping.ts` en consecuencia.
- [ ] `sap.CalibreSap`, `sap.ProductorVariedadSap` y `sap.ProductorVariedadSemanaSap` estan modeladas pero los handlers de sync no se implementaron aun (requieren mas joins). Sub-fase 3.1.
- [ ] Cron automatico de sync diario (03:00 AM) - hoy solo manual via endpoint/UI.

**BD**

Schema `sap`, una tabla por entidad reflejando SAP 1:1 pero con tipos fuertes:

- `sap.EspecieSap(Id, CodigoSap UNIQUE, Nombre, Activo, SyncedAt)`.
- `sap.GrupoVariedadSap(Id, CodigoSap, EspecieSapId FK, Nombre, SyncedAt)`.
- `sap.VariedadSap(Id, CodigoSap UNIQUE, EspecieSapId FK, GrupoVariedadSapId FK, Nombre, SyncedAt)`.
- `sap.CalibreSap(Id, VariedadSapId FK, Codigo, Tipo CHECK IN ('Grande','Mediano','Pequeno','Otro'), Orden INT, SyncedAt)`.
- `sap.ProductorSap(Id, CodigoSap UNIQUE, Rut, Dv, Nombre, Email, GrupoProductorId FK, CodigoSag, Activo, SyncedAt)`.
- `sap.ProductorVariedadSap(Id, ProductorSapId FK, VariedadSapId FK, EsOgl BIT, EsWalmart BIT, EsSystemApproach BIT, Sdp, CuartelCodigo, Activo, SyncedAt, UNIQUE(ProductorSapId, VariedadSapId, TemporadaId))`.
- `sap.ProductorVariedadSemanaSap(Id, ProductorVariedadSapId FK, TemporadaId FK, SemanaInicio INT, SemanaFin INT, SyncedAt)`.
- Lookups: `sap.EnvaseSap`, `sap.ManejoSap`, `sap.CentroSap`, `sap.TipoFrioSap`, `sap.ProgramaSap` — misma estructura minimal.

**Backend**

- `src/features/sap-sync/` — cada entidad tiene su `<entidad>.sync.ts` que:
  1. Llama al endpoint ETL correspondiente (`SAP_ETL_AGENT_GUIDE.md §Modo A` o `Modo B`).
  2. Hace un `MERGE` contra la tabla `sap.*` por `CodigoSap`.
  3. Actualiza `SyncedAt`.
- Orquestador `sap-sync.scheduler.ts` — ejecuta los sync en orden (especies → variedades → calibres → productores → productor-variedad → productor-variedad-semana). Corre via cron interno (`node-cron`) diariamente a las 03:00 AM.
- Endpoints:

| Metodo | Ruta | Descripcion |
|---|---|---|
| `POST` | `/api/v1/sap-sync/run` | Dispara sync manual (solo `est-admin`). Body `{ entidades?: string[] }` |
| `GET` | `/api/v1/sap-sync/estado` | Ultima ejecucion por entidad |
| `GET` | `/api/v1/sap-sync/logs?limit=50` | Historico de sync |

- Tabla `sap.SyncLog(Id, Entidad, FechaInicio, FechaFin, FilasLeidas, FilasInsertadas, FilasActualizadas, Estado, Error)`.

**Frontend**

- Pagina `/sap-sync` (visible solo para `est-admin`) — tarjetas por entidad con:
  - Ultima sincronizacion (timestamp).
  - Total de filas.
  - Boton **Sincronizar ahora** (icono Heroicons arrows-path).
  - Estado (chip: `ok` emerald / `fallo` red / `corriendo` amber).
- Tabla de historial con paginacion y logs expandibles.

**Aceptacion Fase 3:**

- `POST /sap-sync/run` con body `{ entidades: ["variedad"] }` trae variedades desde SAP y las deja en `sap.VariedadSap` con los IDs internos preservados entre sync sucesivos.
- `ProductorVariedadSap` queda correctamente ligada a variedad y productor.
- El scheduler corre a las 03:00 AM y el log queda guardado.
- Si SAP esta caido, el sync falla con `Estado='fallo'` y `Error` explicativo, sin dejar datos parciales.

---

### Fase 4 — Agronomos y asignaciones · **Complejidad: M** · **Estado: Completada — 2026-04-16**

**Alcance de negocio:** un agronomo (usuario con rol `est-user` + atributo `agronomo`) queda ligado a una o varias combinaciones productor-variedad. Esa asignacion determina que estimaciones puede editar.

**Entregado:**

- **BD:** migracion `202604160005__agronomos.sql` con `est.Agronomo` (1-a-1 con Usuario, FK opcional a Planta) y `est.AgronomoProductorVariedad` (pivot con UNIQUE por `(AgronomoId, ProductorVariedadSapId, TemporadaId)`). Trigger de `UpdatedAt`.
- **Back:**
  - Feature `agronomos/`: DTO zod, repository (list/get/insert/update/deactivate con `UpdatedBy`), service con validaciones (usuario existe y activo, unicidad agronomo-por-usuario), controller con endpoints `GET/POST/PUT/DELETE /api/v1/agronomos`.
  - Asignaciones en el mismo controller: `GET/POST/DELETE /api/v1/agronomos/:id/asignaciones` con bulk-upsert por tabla temporal + insert WHERE NOT EXISTS.
  - Endpoint helper `GET /api/v1/agronomos/usuarios-disponibles` (admin only) para alimentar el modal de promocion.
  - Endpoint `GET /api/v1/mi-perfil/asignaciones` que lee las asignaciones del usuario logueado.
  - Endpoint de lectura `GET /api/v1/sap/productor-variedades` con joins a productor+variedad para el UI de asignacion.
- **Front:**
  - `AgronomosService` con los 9 metodos HTTP.
  - `AgronomoFormModalComponent` — modal de promocion: busca usuarios disponibles (typeahead 300ms), selector de planta opcional.
  - `AsignacionesModalComponent` — modal grande (`max-w-4xl`) con tabla de productor-variedad, selector de temporada (por defecto la activa), busqueda client-side, checkboxes con bulk "marcar/limpiar visibles", boton "Aplicar N asignaciones", accion "Quitar" por fila asignada.
  - `AgronomosPageComponent` — listado con `DataTable`, filtros (search + activo), 2 acciones por fila (Asignaciones / Desactivar).
  - `MisAsignacionesPageComponent` en `/mi-perfil/asignaciones` — vista read-only del agronomo logueado con selector de temporada. Mensaje amigable si el usuario aun no es agronomo.
  - Sidebar: links a `/agronomos` (admin) y `/mi-perfil/asignaciones` (todos).

**Endpoints expuestos:**

| Metodo | Path | Rol |
|---|---|---|
| GET | `/api/v1/agronomos` | est-user |
| GET | `/api/v1/agronomos/usuarios-disponibles` | est-admin |
| GET | `/api/v1/agronomos/:id` | est-user |
| POST | `/api/v1/agronomos` | est-admin |
| PUT | `/api/v1/agronomos/:id` | est-admin |
| DELETE | `/api/v1/agronomos/:id` | est-admin (soft — `Activo = 0`) |
| GET | `/api/v1/agronomos/:id/asignaciones?temporadaId=` | est-user |
| POST | `/api/v1/agronomos/:id/asignaciones` | est-admin (bulk) |
| DELETE | `/api/v1/agronomos/:id/asignaciones/:asignacionId` | est-admin |
| GET | `/api/v1/mi-perfil/asignaciones?temporadaId=` | est-user |
| GET | `/api/v1/sap/productor-variedades` | est-user |

**Dependencia pendiente:** el bulk-assign requiere que `sap.ProductorVariedadSap` este poblada. Como la Fase 3 (SAP sync) queda en espera del mapping real, las asignaciones por ahora solo funcionan end-to-end cuando haya datos en esa tabla. El front muestra "Sin resultados" correctamente si la tabla esta vacia.

**BD**

- `agro.Agronomo(Id, UsuarioId FK UNIQUE, PlantaId FK NULL, Activo, CreatedAt, UpdatedAt)`.
- `agro.AgronomoProductorVariedad(Id, AgronomoId FK, ProductorVariedadSapId FK, TemporadaId FK, CreatedAt, CreatedBy, UNIQUE(AgronomoId, ProductorVariedadSapId, TemporadaId))`.

**Backend**

| Metodo | Ruta | Descripcion |
|---|---|---|
| `GET` | `/api/v1/agronomos` | Listado con filtros `?planta`, `?activo`, `?q` |
| `POST` | `/api/v1/agronomos` | Promueve un `Usuario` a agronomo (lo liga a una planta) |
| `DELETE` | `/api/v1/agronomos/:id` | Desactivar |
| `GET` | `/api/v1/agronomos/:id/asignaciones?temporadaId=` | Listar productor-variedad asignados |
| `POST` | `/api/v1/agronomos/:id/asignaciones` | Bulk assign `{ temporadaId, productorVariedadIds: [] }` |
| `DELETE` | `/api/v1/agronomos/:id/asignaciones/:asignacionId` | Quitar asignacion |

Regla: solo `est-admin` muta. El agronomo mismo solo **lee** sus asignaciones.

**Frontend**

- `/agronomos` — tabla de agronomos (filtro por planta).
- Modal `AgronomoAsignacionModal` — tabla de productor-variedad con seleccion multiple y chips de "asignado" vs "disponible".
- `/mi-perfil/asignaciones` — vista para que el agronomo logueado vea sus asignaciones.

**Aceptacion Fase 4:**

- Un admin puede asignar/desasignar productor-variedad a un agronomo en bulk (100+ asignaciones en una sola accion).
- El agronomo logueado ve solo sus asignaciones.
- La asignacion queda scoped a la temporada activa.

---

### Fase 5 — Calendario de estimacion general · **Complejidad: S** · **Estado: Completada — 2026-04-16**

**Alcance de negocio:** definir ventanas de tiempo (fecha apertura → fecha cierre) en las que se puede hacer estimacion general por especie/temporada.

**Entregado:**

- **BD:** migracion `202604160006__calendario_general.sql` con `est.FechaEstimacionGeneral` (UNIQUE por `(TemporadaId, EspecieSapId)`, CHECK `FechaCierre >= FechaApertura`). Funcion `est.fn_VentanaGeneralAbierta(@TemporadaId, @EspecieSapId, @Fecha)` — helper que la Fase 6 usara para validar ediciones.
- **Back:** CRUD completo en `/api/v1/calendario-general` con validaciones (unicidad, coherencia de fechas) y endpoint de lectura con `ventanaAbierta` computada (JOIN a `sap.EspecieSap` + comparacion vs `SYSUTCDATETIME()`).
- **Front:** pagina `/calendario-general` con `DataTable`, filtro por temporada, modal (`VentanaFormModalComponent`) con selectores de temporada y especie cargados desde `/api/v1/temporadas` y `/api/v1/sap/especies`. En edicion, los selectores quedan disabled (no se mueve la clave). Estado visible: Abierta / Fuera de rango / Inactiva.

**Endpoints:** `/api/v1/calendario-general` (GET paginado, GET id, POST, PUT, DELETE — mutaciones requieren admin).

**BD**

- `maestro.FechaEstimacionGeneral(Id, TemporadaId FK, EspecieSapId FK, FechaApertura DATE, FechaCierre DATE, UNIQUE(TemporadaId, EspecieSapId))`.

**Backend**

- CRUD estandar bajo `/api/v1/calendario-general`.
- Helper `calendario.service.esVentanaAbierta(temporadaId, especieId): boolean` — consumido por Fase 6 para bloquear ediciones fuera de ventana.

**Frontend**

- `/calendario-estimacion` — tabla simple con temporada/especie/fechas, modal de edicion.
- Indicador de estado (abierta/cerrada) con badge segun `DESIGN_STANDARD.md §2.4`.

**Aceptacion Fase 5:**

- Admin define ventanas por especie.
- Al intentar crear/editar una estimacion general fuera de ventana → `422 ventana_cerrada`.

---

### Fase 6 — Estimacion General con control de version · **Complejidad: XL** · **Estado: MVP entregado — 2026-04-16 (wizard de creacion pendiente en sub-fase 6.1)**

**Alcance de negocio:** al inicio de la temporada de cada variedad, el agronomo declara la estimacion completa: volumen total por productor-variedad, distribucion de kilos por semana (calendario especifico de la variedad), % por calibre y valores de tipificacion. Esta estimacion se versiona — las modificaciones solo proceden sobre semanas que aun no ocurrieron.

**Entregado:**

- **BD:** migracion `202604160007__estimacion_general.sql` con:
  - Tablas vivas: `est.EstimacionControlVersion` (indice filtrado unico por "Abierta"), `est.Estimacion`, `est.EstimacionVolumen`, `est.EstimacionVolumenSemana`, `est.EstimacionCalibre`, `est.EstimacionTipificacion`, `est.EspecieTipificacion`.
  - Tablas *Version* (snapshots inmutables): `EstimacionVersion`, `EstimacionVolumenVersion`, `EstimacionVolumenSemanaVersion`, `EstimacionCalibreVersion`, `EstimacionTipificacionVersion`.
  - SP `est.sp_CerrarControlVersion` — transaccional, copia todo lo vivo a las *Version*, marca la version como `Cerrada`, abre `NumeroVersion + 1` como `Abierta`, y re-apunta las estimaciones vivas a la nueva version.
- **Back (feature `estimaciones-generales/`):**
  - Repo con `insertEstimacionCompleta` / `updateEstimacionCompleta` transaccional (volumen + semanas + calibres + tipificaciones en un solo POST), `getEstimacionContext` para validaciones, helpers `ventanaAbierta` (llama a `est.fn_VentanaGeneralAbierta`) y `agronomoAsignadoAPV`.
  - Service con reglas: control-version en `Abierta`, ventana del calendario abierta, agronomo asignado al PV en la temporada, suma de calibres = 100 (±0.5), semanas >= semana ISO actual, admin o agronomo duenho para editar/eliminar.
  - Endpoints: `GET/POST /control-versiones`, `GET /control-versiones/:id`, `POST /control-versiones/:id/cerrar`, `GET/POST/PUT/DELETE /estimaciones-generales`, `GET /estimaciones-generales/:id` (con volumen+semanas+calibres+tipificaciones agregados).
- **Front:**
  - `/estimaciones-generales` — listado paginado + panel superior de **Versiones** con tabla por (temporada, especie, version, estado) y botones "+ Nueva version" y "Cerrar y versionar".
  - `/estimaciones-generales/:id` — detalle con cabecera (kilos totales, agronomo, PV, folio, manejo) + tabs (Volumen, Semanas, Calibres, Tipificacion) con totalizadores y % del total.

**Endpoints expuestos:**

| Metodo | Path | Rol |
|---|---|---|
| GET | `/api/v1/estimaciones-generales/control-versiones?temporadaId=&especieId=` | est-user |
| GET | `/api/v1/estimaciones-generales/control-versiones/:id` | est-user |
| POST | `/api/v1/estimaciones-generales/control-versiones` | est-admin |
| POST | `/api/v1/estimaciones-generales/control-versiones/:id/cerrar` | est-admin (SP transaccional) |
| GET | `/api/v1/estimaciones-generales` | est-user |
| GET | `/api/v1/estimaciones-generales/:id` | est-user |
| POST | `/api/v1/estimaciones-generales` | est-user (valida asignacion) |
| PUT | `/api/v1/estimaciones-generales/:id` | est-user duenho o admin (semanas futuras) |
| DELETE | `/api/v1/estimaciones-generales/:id` | est-user duenho o admin |

**Pendientes sub-fase 6.1:**

- [ ] Wizard de creacion en el frontend (4 pasos: PV+manejo → volumen → distribucion semanal → calibres+tipificacion). Hoy solo hay GET/listado/detalle/delete y el usuario crearia via API directamente.
- [ ] Edicion inline de semanas en el tab "Semanas" (con bloqueo visual de semanas pasadas).
- [ ] Historial de versiones (vista diff) en el detalle — la BD ya guarda snapshots.
- [ ] Funciones `est.fn_KilosPorCalibre(@EstimacionId, @CalibreId)` y `est.fn_KilosPorTipificacion` (reemplazos de `FN_KILOS_CALIBRE_GENERAL` del legacy) para el proximo reporte.

**BD**

- `est.EstimacionControlVersion(Id, TemporadaId FK, EspecieSapId FK, NumeroVersion INT, Estado CHECK IN ('Abierta','Cerrada','Anulada'), FechaApertura, FechaCierre NULL, CreatedBy, UNIQUE(TemporadaId, EspecieSapId, NumeroVersion))`.
- `est.Estimacion(Id, ControlVersionId FK, AgronomoId FK, ProductorVariedadSapId FK, ManejoSapId FK NULL, Folio NVARCHAR(32), UNIQUE(ControlVersionId, ProductorVariedadSapId, ManejoSapId))`.
- `est.EstimacionVolumen(Id, EstimacionId FK, UnidadId FK, Kilos DECIMAL(14,2), PorcentajeExportacion DECIMAL(9,4), CajasEquivalentes DECIMAL(14,4))`.
- `est.EstimacionVolumenSemana(Id, EstimacionId FK, Semana INT CHECK (Semana BETWEEN 1 AND 53), Kilos DECIMAL(14,2))`.
- `est.EstimacionCalibre(Id, EstimacionId FK, CalibreSapId FK, Porcentaje DECIMAL(9,4))`.
- `est.EstimacionTipificacion(Id, EstimacionId FK, EspecieTipificacionId FK, Valor DECIMAL(14,4))`.
- Tablas *Version* (snapshot) con la misma forma pero anadiendo `VersionNumeroOrigen` y `FechaSnapshot`.
- Stored proc `est.sp_CerrarControlVersion(@ControlVersionId)`:
  1. Copia Estimacion + Volumen + Semana + Calibre + Tipificacion a las tablas *Version*.
  2. Marca la version como `Cerrada`.
  3. Crea una nueva version `Abierta` con `NumeroVersion + 1`.
- Stored proc `est.sp_ReabrirControlVersion(@ControlVersionId)` — para corregir un cierre (solo admin).
- Funcion `est.fn_KilosPorCalibre(@EstimacionId, @CalibreId)` y `est.fn_KilosPorTipificacion(@EstimacionId, @TipificacionId)` — reemplazan `FN_KILOS_CALIBRE_GENERAL` y `FN_KILOS_TIPIFICACION_GENERAL` legacy.

**Backend**

Carpeta `src/features/estimaciones-generales/`:

| Metodo | Ruta | Descripcion |
|---|---|---|
| `GET` | `/api/v1/estimaciones-generales?temporadaId=&especieId=&productorId=&agronomoId=` | Lista filtrada |
| `GET` | `/api/v1/estimaciones-generales/:id` | Detalle completo con volumen, semanas, calibres, tipificacion |
| `POST` | `/api/v1/estimaciones-generales` | Crear |
| `PUT` | `/api/v1/estimaciones-generales/:id` | Editar (valida ventana + regla `semana > semanaActual`) |
| `DELETE` | `/api/v1/estimaciones-generales/:id` | Solo si version abierta y ventana abierta |
| `POST` | `/api/v1/estimaciones-generales/control-version/:id/cerrar` | Cierra la version (solo admin) |
| `POST` | `/api/v1/estimaciones-generales/control-version/:id/reabrir` | Reabre (solo admin, audita motivo) |
| `GET` | `/api/v1/estimaciones-generales/:id/historial` | Lista snapshots de version |
| `GET` | `/api/v1/estimaciones-generales/:id/historial/:versionNumero` | Snapshot especifico |

Servicio `EstimacionGeneralService` aplica la regla de negocio **completa** (validacion de ventana, validacion de semana actual, transaccion atomica por submit). Los calculos de kilos-por-calibre se hacen en la BD via la funcion y se exponen en el DTO de detalle.

**Frontend**

- `/estimaciones-generales` — listado (agronomo, especie, productor, folio, version, kilos totales, ultima modificacion). Filtros laterales. Badge de estado: `Abierta` emerald, `Cerrada` slate, `En Edicion` amber.
- `/estimaciones-generales/nueva` — wizard de 4 pasos (`DESIGN_STANDARD.md §14.3`):
  1. Seleccion de productor-variedad + manejo.
  2. Volumen y % exportacion.
  3. Distribucion por semana (tabla editable 1..53 con validacion: la suma debe ser 100 ±0.5%).
  4. Calibres + tipificacion (las filas se cargan automaticamente desde `sap.CalibreSap` y `maestro.EspecieTipificacion`).
- `/estimaciones-generales/:id` — detalle con tabs: `Volumen`, `Semanas`, `Calibres`, `Tipificacion`, `Historial` (lista de versiones con diff visual).
- Componente `SemanaEditorComponent` — grilla editable que bloquea visualmente las semanas ya transcurridas (gris + tooltip).

**Aceptacion Fase 6:**

- Un agronomo asignado puede crear una estimacion general en ventana abierta.
- Un agronomo NO asignado al productor-variedad → `403`.
- Solo se puede editar una semana futura. Intento de editar una semana pasada → `422 semana_cerrada` y la UI no permite foco.
- El cierre de version genera snapshots identicos a las tablas vivas.
- El historial muestra diffs columna a columna entre versiones sucesivas.
- Las reglas de auditoria quedan en `auth.Auditoria` con operacion y estimacionId.

---

### Fase 7 — Estimacion Bisemanal con control de version · **Complejidad: XL**

**Alcance de negocio:** cada semana, el agronomo declara kilos esperados dia-a-dia (Lun-Dom) para la semana actual y la siguiente, junto con destino, envase, tipo frio y % exportacion. Se usa para programar dotacion de planta.

**BD**

- `bise.ControlEstimacionBisemanal(Id, TemporadaId FK, SemanaInicio INT, SemanaFin INT, FechaApertura, FechaCierre, Estado)`.
- `bise.ControlDetalleEstimacionBisemanal(Id, ControlId FK, Semana INT, FechaDesde DATE, FechaHasta DATE)` — 2 filas por control.
- `bise.EstimacionBisemanalControlVersion(Id, ControlId FK, NumeroVersion, Estado, FechaApertura, FechaCierre)`.
- `bise.EstimacionBisemanal(Id, ControlVersionId FK, AgronomoId FK, ProductorVariedadSapId FK, CentroSapId FK, TipoFrioSapId FK, EnvaseSapId FK, Semana INT, KilosLunes, KilosMartes, KilosMiercoles, KilosJueves, KilosViernes, KilosSabado, KilosDomingo — todos DECIMAL(14,2), PorcentajeExportacion DECIMAL(9,4))`.
- Tabla de snapshot `bise.EstimacionBisemanalVersion` con misma forma + `VersionNumeroOrigen`.
- Stored procs simetricos a Fase 6 (`sp_CerrarControlVersion`, `sp_ReabrirControlVersion`).

**Backend**

- Endpoints analogos a Fase 6 bajo `/api/v1/estimaciones-bisemanales/*`.
- Regla clave: al abrir un **control** nuevo, el servicio clona la ultima version como base para la siguiente bisemanal (ahorra data entry).
- Endpoint `POST /control-estimacion-bisemanal` (solo admin) para abrir un nuevo control con fechas.

**Frontend**

- `/estimaciones-bisemanales` — listado con filtro por semana activa.
- Editor bisemanal `/estimaciones-bisemanales/:id/editar` — tabla 7 columnas (L-M-M-J-V-S-D) × N filas (una por productor-variedad asignada). Foot totalizador por dia.
- Vista `/estimaciones-bisemanales/control` — panel admin con controles abiertos/cerrados.

**Aceptacion Fase 7:**

- Agronomo abre "su bandeja bisemanal" y ve solo sus productor-variedad asignados con filas preexistentes cuando hay version previa.
- Inputs de dias pasados aparecen readonly (no editables).
- El cierre de control versiona todo el dataset del periodo.
- Totales diarios y semanales calculados en el front (`computed()` signals).

---

### Fase 8 — Reportes y vistas BI · **Complejidad: L**

**Alcance de negocio:** dar a BI acceso confiable a la data denormalizada; exportar reportes oficiales a XLSX/PDF.

**BD**

- Vistas bajo schema `bi`:
  - `bi.VW_EstimacionBisemanalHistorico` — toda la data bisemanal + version + catalogos + productor/variedad/agronomo en un row flat.
  - `bi.VW_EstimacionBisemanalNorte` / `bi.VW_EstimacionBisemanalSur` — filtrado por `Planta.Zona`.
  - `bi.VW_EstimacionGeneralHistorico` — equivalente para general.
  - `bi.VW_DiccionarioDatos` — explica cada columna de las vistas (nombre, tipo, origen, descripcion).
- Tabla `bi.EstimacionBisemanalBI` denormalizada, refrescada cada 15 min por job (`MERGE` desde las vivas + snapshots).
- Usuario de BD con `SELECT` solo en schema `bi` (a solicitar al DBA para DBEST).

**Backend**

- `/api/v1/reportes/estimacion-general?temporadaId=&especieId=&formato=xlsx|pdf` — streaming de archivo.
- `/api/v1/reportes/estimacion-bisemanal?temporadaId=&semanaDesde=&semanaHasta=&formato=xlsx|pdf`.
- `/api/v1/reportes/recepcion-real?...` — si se integra con recepcion real en Fase 11+.
- Implementacion: `exceljs` para XLSX, `pdfkit` para PDF. Template definido por diseno.

**Frontend**

- `/reportes` — selector de reporte, parametros dinamicos, boton "Descargar".
- Loading overlay mientras se genera.

**Aceptacion Fase 8:**

- BI se conecta con el login read-only provisto por el DBA sobre DBEST y puede hacer `SELECT *` sobre las vistas del schema `bi`; el diccionario de datos esta documentado.
- La tabla denormalizada `bi.EstimacionBisemanalBI` tiene lag maximo de 15 min.
- Descarga XLSX funciona end-to-end con nombres de columna en castellano.

---

### Fase 9 — Visitas de terreno · **Complejidad: L**

**Alcance de negocio:** un agronomo en terreno registra una visita a un cuartel con foto(s), GPS y observaciones. El admin revisa el historial.

**BD**

- `agro.AgronomoVisita(Id, AgronomoId FK, ProductorVariedadSapId FK, CuartelCodigo NVARCHAR(64), FechaVisita DATETIME2, Latitud DECIMAL(9,6), Longitud DECIMAL(9,6), Observaciones NVARCHAR(MAX), CreatedAt)`.
- `agro.AgronomoVisitaDocumento(Id, VisitaId FK, NombreArchivo, RutaStorage, TipoMime, Tamano, CreatedAt)`.

**Backend**

- Storage: volumen Docker montado en `/var/lib/est/uploads/` (NO subdir bajo el proyecto). Ruta devuelta como URL firmada corta (`/api/v1/archivos/:token`).
- `multer` para multipart. Limite 10 MB por foto, maximo 6 fotos por visita.
- Endpoints:

| Metodo | Ruta |
|---|---|
| `POST` | `/api/v1/visitas` (multipart) |
| `GET` | `/api/v1/visitas?agronomoId=&productorVariedadId=&desde=&hasta=` |
| `GET` | `/api/v1/visitas/:id` |
| `GET` | `/api/v1/archivos/:token` (sirve el binario con short-lived JWT token) |

**Frontend**

- `/visitas/nueva` — formulario con `<input type="file" capture="environment">` para movil, navegador Geolocation API para GPS.
- `/visitas` — listado con mapa opcional (Leaflet + tiles OSM).
- Galeria de fotos con lightbox.

**Aceptacion Fase 9:**

- Agronomo puede cargar una visita con 3 fotos desde su movil (Safari iOS / Chrome Android).
- GPS se guarda con precision decimales.
- Admin ve todas las visitas filtradas.

---

### Fase 10 — Carga masiva · **Complejidad: L**

**Alcance de negocio:** permitir importar estimaciones generales o bisemanales desde XLSX/CSV para casos masivos (p. ej. primera carga del ano).

**BD**

- `carga.CargaEstimacion(Id, Tipo CHECK IN ('GENERAL','BISEMANAL'), TemporadaId FK, ArchivoNombre, UsuarioId FK, Estado CHECK IN ('RECIBIDA','VALIDADA','APLICADA','ERROR'), FilasTotales, FilasExitosas, FilasFallidas, CreatedAt)`.
- `carga.CargaEstimacionFiltro(Id, CargaId FK, Clave, Valor)`.
- `carga.CargaEstimacionDetalle(Id, CargaId FK, Fila INT, ProductorCodigoSap, VariedadCodigoSap, …, EstadoFila CHECK IN ('OK','WARN','ERROR'), Mensaje)`.

**Backend**

- `POST /api/v1/cargas` (multipart, XLSX/CSV) — parsea con `exceljs`, valida en `RECIBIDA → VALIDADA`.
- `POST /api/v1/cargas/:id/aplicar` — ejecuta en transaccion. Si falla algo, `ROLLBACK` y estado `ERROR`.
- `GET /api/v1/cargas/:id/reporte` — exporta el detalle como XLSX con columna `Mensaje`.

**Frontend**

- Wizard 3 pasos: upload → preview de validacion (tabla con filas OK/WARN/ERROR) → aplicar.
- Descarga del reporte post-ejecucion.

**Aceptacion Fase 10:**

- XLSX con 1000 filas se valida en <5s y aplica en <10s.
- Si hay una fila con error, se aborta la aplicacion completa y el usuario puede corregir y re-subir.

---

### Fase 11 — Dashboard + monitoreo · **Complejidad: M**

**Alcance de negocio:** vista ejecutiva — cuantas estimaciones pendientes, % completado por especie, cierres de version pendientes, ultimas cargas SAP.

**BD**

- Vistas agregadas `bi.VW_Dashboard_*`.

**Backend**

- `GET /api/v1/dashboard` — responde en un solo JSON los KPIs principales.
- `GET /api/v1/dashboard/alerta-cierres` — versiones abiertas con cutoff proximo (<3 dias).

**Frontend**

- `/` (home) — grid de `stat-card-*` segun `DESIGN_STANDARD.md §7.5`:
  - Stat primary: `% completado por especie` (donut Chart.js).
  - Stat emerald: total estimaciones abiertas.
  - Stat amber: alertas (cierres proximos, sync SAP fallido).
  - Stat teal: visitas ultimo mes.
- Lista inferior con "actividad reciente".

**Aceptacion Fase 11:**

- La home carga en <800ms con cache Redis de 60s.
- Alertas click-through a la pantalla correspondiente.

---

## 5. Hitos de entrega y complejidad

| Hito | Fases incluidas | Duracion estimada (dev-semanas) |
|---|---|---|
| **MVP1 — Datos base navegable** | 0 + 1 + 2 | 3 |
| **MVP2 — SAP + Asignaciones** | 3 + 4 | 3 |
| **MVP3 — Estimacion General operativa** | 5 + 6 | 5 |
| **MVP4 — Ciclo bisemanal completo** | 7 | 4 |
| **MVP5 — BI + reportes oficiales** | 8 | 2 |
| **Extensiones** | 9 + 10 + 11 | 5 |
| **Total** | 0-11 | ~22 dev-semanas |

## 6. Tabla consolidada de endpoints

Resumen maestro de paths (Fase 1-11, sin contar health y auth):

```
/api/v1/auth/{login,callback,me,logout}                              [F1]
/api/v1/temporadas                                                    [F2]
/api/v1/plantas                                                       [F2]
/api/v1/unidades                                                      [F2]
/api/v1/grupos-productor                                              [F2]
/api/v1/tipificaciones-especie                                        [F2]
/api/v1/catalogos/{condicion,destino,tipo-calidad,tipo-color,tipo-envase}  [F2]
/api/v1/sap-sync/{run,estado,logs}                                    [F3]
/api/v1/sap/{especies,variedades,productores,productor-variedades,...} [F3]
/api/v1/agronomos                                                     [F4]
/api/v1/agronomos/:id/asignaciones                                    [F4]
/api/v1/calendario-general                                            [F5]
/api/v1/estimaciones-generales                                        [F6]
/api/v1/estimaciones-generales/:id/{historial,detalle}                [F6]
/api/v1/estimaciones-generales/control-version/:id/{cerrar,reabrir}   [F6]
/api/v1/estimaciones-bisemanales                                      [F7]
/api/v1/estimaciones-bisemanales/control                              [F7]
/api/v1/reportes/{estimacion-general,estimacion-bisemanal}            [F8]
/api/v1/visitas, /api/v1/archivos/:token                              [F9]
/api/v1/cargas                                                        [F10]
/api/v1/dashboard                                                     [F11]
```

## 7. Decisiones arquitectonicas

1. **BFF + Keycloak** — decidido en `AUTH_STANDARD.md`. No se evalua otra opcion.
2. **SQL Server** — obligatorio por compatibilidad con legacy/BI. No se considera Postgres aunque seria atractivo por costo.
3. **Typescript estricto en back** — para reducir bugs de runtime y estandarizar con el resto del stack Greenvic.
4. **Patron snapshot** (copia completa al cerrar version) — aporta auditabilidad perfecta a costo de storage. Aceptable para el volumen esperado (<50k rows/version).
5. **ETL SAP externalizado** — el adapter ya existe (`greenvic-sap-adapter`). EST solo lo **consume**, no re-implementa conectividad RFC.
6. **Sin GraphQL** — REST cumple y evita complejidad adicional.
7. **Angular Signals > NgRx** — alineado con `DESIGN_STANDARD.md §12.2`.
8. **Modal Keycloak para usuarios** — ningun provisioning en BD propia (ver `AUTH_STANDARD.md §8.bis`).

## 8. Pendientes / riesgos

- [ ] **Aprobacion del DBA** para el corte con el schema viejo (si la data legacy se va a migrar 1:1 o no).
- [ ] **Confirmacion de zonas Norte/Sur** — `Planta.Zona` necesita catalogo.
- [ ] **Fechas de corte reales** de la estimacion general — `maestro.FechaEstimacionGeneral` hoy no tiene datos reales.
- [ ] **Politica de retencion** de snapshots — ¿se conservan indefinidamente o se archivan tras N temporadas?
- [ ] **Integracion con recepcion real** — mencionada en legacy (`ListaResumenRecepcionReal*`) pero no modelada en este plan. Se evalua en Fase 11+.
- [ ] **Validacion anti-DoS** en endpoints de BI (vistas lentas potencialmente). Pool SQL separado para reportes.

---

## 9. Como mantener este documento

- Al iniciar una fase, cambiar su estado al tope de la seccion: `**Estado: En progreso**`.
- Al terminar, marcar: `**Estado: Completada — YYYY-MM-DD**` y listar los PRs/commits.
- Si una fase cambia de alcance, **editar aqui primero** y abrir PR separado para ese cambio antes de implementar.
- Este archivo es la fuente de verdad — Jira/Linear son sincronizables, pero este plan manda.
