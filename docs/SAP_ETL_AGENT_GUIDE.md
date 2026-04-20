# Greenvic SAP ETL - Agent / LLM Quick Reference

> Guia operativa concisa para que un agente automatizado consuma los endpoints
> y dispare extracciones SAP. Asume el host corriendo en `http://192.168.8.24:5090`
> con el bearer token configurado en `ETL_API_TOKEN` del `.env` del host.

Si eres un LLM que nunca toco este sistema, leer este documento completo te
basta para operarlo via HTTP. Cualquier otra consulta debe ir a
`docs/api.md`, `docs/job-config-schema.md` o `docs/runbook.md`.

## Convenciones

- **Auth**: header `Authorization: Bearer <token>` en todos los endpoints excepto `/health`.
- **Content-Type**: `application/json` en todos los POST.
- **Envelope estandar de respuesta**:

  ```json
  { "data": { /* payload */ }, "error": null, "meta": { "requestId": "...", "timestampUtc": "2026-04-08T12:00:00Z" } }
  ```

- **Envelope estandar de error**:

  ```json
  { "data": null, "error": { "code": "destination_not_found", "message": "..." }, "meta": { } }
  ```

- Los IDs de run son `long` (BIGINT), no GUID.
- Fechas siempre en UTC, formato ISO 8601.

## Modos de uso

### Modo A - On-demand (sin persistencia)

Usa cuando quieras EJECUTAR una query SAP/OData ahora mismo y recibir el
resultado inline. Sin BD, sin Quartz, sin runs, sin particiones. Timeout corto
(`ETL_ONDEMAND_TIMEOUT_SECS`, default 60s).

Endpoints:
- `POST /api/v1/sap/rfc/query` - `RFC_READ_TABLE2` contra una tabla SAP.
- `POST /api/v1/sap/odata/query` - EntitySet OData via SAP Gateway.

### Modo B - Dispatch (job persistido)

Usa cuando quieras correr un job configurado en `etl.ETL_JOB_DEFINITION` que
carga a un SQL target de forma persistente, reintentable y observable.

Endpoints:
- `POST /api/v1/jobs/{key}/run` - dispara una vez con parametros.
- `POST /api/v1/jobs/{key}/backfill` - dispara con un rango de fechas.
- `GET  /api/v1/runs/{runId}` - consulta progreso/resultado.
- `POST /api/v1/runs/{runId}/cancel` - cancela un run activo.
- `POST /api/v1/runs/{runId}/retry` - re-ejecuta un run fallido con sus mismos parametros.

## Decision rapida

| Necesitas... | Usa |
|---|---|
| Exploracion interactiva, ad-hoc, < 100k filas | Modo A |
| Carga programada, persistente, idempotente | Modo B |
| Multiples particiones, segmentacion por fecha/sociedad | Modo B |
| Resultado XML para integraciones legacy | Modo A con `?format=xml` |
| Validar que un campo SAP existe antes de crear un job | Modo A con `rowCount: 5` |
| Backfill historico con rango de fechas | Modo B (`/backfill`) |

## Ejemplos completos (copiar / pegar)

Se asume `TOKEN` exportado: `export TOKEN=$(grep ETL_API_TOKEN .env | cut -d= -f2)`.

### A0. Health (sin auth)

```bash
curl http://192.168.8.24:5090/health
```

### A1. Listar destinos disponibles

```bash
curl -H "Authorization: Bearer $TOKEN" http://192.168.8.24:5090/api/v1/destinations/sap
curl -H "Authorization: Bearer $TOKEN" http://192.168.8.24:5090/api/v1/destinations/odata
curl -H "Authorization: Bearer $TOKEN" http://192.168.8.24:5090/api/v1/destinations/sql
```

Respuesta tipica SAP:

```json
{ "data": [ { "alias": "PRD", "host": "192.168.20.73", "systemNumber": "02", "systemId": "SGP", "client": "400", "language": "ES", "poolSize": 5, "hasPassword": true } ] }
```

### A2. Query RFC simple (T000)

```bash
curl -X POST http://192.168.8.24:5090/api/v1/sap/rfc/query \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{
    "destination": "PRD",
    "table": "T000",
    "fields": ["MANDT","MTEXT","ORT01"],
    "where": "",
    "rowCount": 10
  }'
```

### A3. Query RFC con WHERE (EKKO por sociedad)

```bash
curl -X POST http://192.168.8.24:5090/api/v1/sap/rfc/query \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{
    "destination": "PRD",
    "table": "EKKO",
    "fields": ["EBELN","BUKRS","BSART","LIFNR","AEDAT"],
    "where": "BUKRS = '\''1000'\'' AND AEDAT >= '\''20260101'\''",
    "rowCount": 100
  }'
```

Tip: las comillas simples SAP dentro del bash se escapan como `'\''`.

### A4. Query RFC en XML (para integraciones legacy)

```bash
curl -X POST "http://192.168.8.24:5090/api/v1/sap/rfc/query?format=xml" \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{ "destination":"PRD", "table":"LFA1", "fields":["LIFNR","NAME1","LAND1"], "rowCount": 5 }'
```

Devuelve `application/xml` con estructura `<result><records><record>...`.

### A5. Query OData JSON

```bash
curl -X POST http://192.168.8.24:5090/api/v1/sap/odata/query \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{
    "destination": "PRD_GW",
    "entitySet": "YWTGW_GET_REPORT_INVEN_SRV/ywtgw_get_inventarioSet",
    "filter": "Werks eq '\''2001'\''",
    "top": 20
  }'
```

### A6. Query OData XML

```bash
curl -X POST "http://192.168.8.24:5090/api/v1/sap/odata/query?format=xml" \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{ "destination":"PRD_GW", "entitySet":"YWTGW_GET_REPORT_INVEN_SRV/ywtgw_get_inventarioSet" }'
```

### A7. Listar jobs y detalle

```bash
curl -H "Authorization: Bearer $TOKEN" http://192.168.8.24:5090/api/v1/jobs
curl -H "Authorization: Bearer $TOKEN" http://192.168.8.24:5090/api/v1/jobs/lcc.acdoca.daily
```

### A8. Disparar un job del catalogo

```bash
curl -X POST http://192.168.8.24:5090/api/v1/jobs/lcc.acdoca.daily/run \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{
    "parameters": {
      "companyCodes": ["1000"],
      "ledger": "0L",
      "fromDate": "2026-04-01",
      "toDate": "2026-04-07"
    }
  }'
```

Respuesta: `{ "data": { "runId": 42 }, ... }`.

### A9. Consultar progreso de un run

```bash
curl -H "Authorization: Bearer $TOKEN" http://192.168.8.24:5090/api/v1/runs/42
```

Devuelve cabecera + lista de particiones + `events[]` (array de `JobEventDto`:
`eventId`, `runId`, `eventAt`, `level`, `eventType`, `message`, `dataJson`).
Entre los eventos, `merge.stats` contiene `{inserted, updated, deleted}` con
las filas afectadas por el MERGE final. Pollear cada 2-5 segundos hasta que
`status` sea terminal (`succeeded`, `failed`, `cancelled`, `stalled`,
`interrupted`).

### A10. Listar runs con filtros

```bash
curl -H "Authorization: Bearer $TOKEN" "http://192.168.8.24:5090/api/v1/runs?status=failed&limit=20"
curl -H "Authorization: Bearer $TOKEN" "http://192.168.8.24:5090/api/v1/runs?jobKey=lcc.acdoca.daily&limit=10"
```

### A11. Cancelar un run activo

```bash
curl -X POST -H "Authorization: Bearer $TOKEN" http://192.168.8.24:5090/api/v1/runs/42/cancel
```

### A12. Reintentar un run fallido

```bash
curl -X POST -H "Authorization: Bearer $TOKEN" http://192.168.8.24:5090/api/v1/runs/42/retry
```

Devuelve un nuevo `runId` que ejecuta el job con los mismos parametros del run
original.

### A13. Backfill historico

```bash
curl -X POST http://192.168.8.24:5090/api/v1/jobs/lcc.acdoca.daily/backfill \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{
    "fromDate": "2025-01-01",
    "toDate": "2025-12-31",
    "parameters": { "companyCodes": ["1000","2000"], "ledger": "0L" }
  }'
```

### A14. Listar tablas de un SQL target

```bash
curl -H "Authorization: Bearer $TOKEN" http://192.168.8.24:5090/api/v1/sql/targets/APOLO2/tables
```

Devuelve tablas y vistas del target SQL con su schema.

### A15. Consultar columnas de una tabla del target

```bash
curl -H "Authorization: Bearer $TOKEN" \
  "http://192.168.8.24:5090/api/v1/sql/targets/APOLO2/columns?schema=dbo&table=Sap_Fundo"
```

Devuelve columnas con tipo, nullable, si es PK y default value. Util para
construir un `columnMap` cuando la tabla destino es legacy y tiene nombres de
columna distintos a los campos SAP.

## Checklist antes de disparar un nuevo job

1. El destino SAP existe? -> `GET /api/v1/destinations/sap` (o `/odata`).
2. El SQL target existe? -> `GET /api/v1/destinations/sql`.
3. Los campos que pides existen en la tabla SAP? -> prueba primero con
   `POST /api/v1/sap/rfc/query` y `rowCount: 5`. Si un campo es invalido el
   RFC devuelve `FIELD_NOT_VALID` y el response trae el nombre ofensor.
4. La tabla destino ya existe en el SQL target? -> No importa. El
   `StagingMergeSink` la crea sola en el primer `FinalizeAsync` del primer run
   (todos los campos como `NVARCHAR(MAX)`, excepto las `matchColumns` que se
   crean como `NVARCHAR(450)` por el PK).
5. Inserta el job con un `INSERT` en `etl.ETL_JOB_DEFINITION` y **reinicia
   el host** para que `JobRegistryBootstrap` lo registre en Quartz.

## Errores comunes y diagnostico

| Sintoma | Causa probable | Fix |
|---|---|---|
| `404 destination_not_found` | Alias no existe en `.env` o no se cargo (se agrego despues del reinicio) | Verifica con `GET /destinations/sap\|odata\|sql` y reinicia el host si hace falta |
| Run `failed` con `FIELD_NOT_VALID` | Un nombre en `fields[]` no existe en la tabla SAP | Quita campos de a uno en una query on-demand hasta encontrar el malo |
| `500 internal_error` con `Invalid column name` | Tabla destino existe con shape antiguo de una version previa | Drop manual de la tabla + relanzar (el sink la recrea con el shape nuevo) |
| Run `succeeded` pero `rowsWritten = 0` con `WHERE` valido | Placeholders `{param}` no resueltos (parametros faltan en el body) | Mira la linea `RFC ... where=...` en los logs JSONL: veras el WHERE literal con placeholders sin sustituir |
| `413 partition_too_large` | Una particion estima > `ETL_SAP_HARD_ROW_LIMIT` (default 1M) y no hay mas dimensiones para subdividir | Agrega otra dimension al `segmentation[]` o reduce el `step` del `dateRange` |
| Run `failed` con `FIELD_NOT_VALID` | Un campo en `fields[]` no existe en la tabla SAP | Verifica los nombres con una query on-demand (`POST /api/v1/sap/rfc/query` con `rowCount: 5`). Quita campos de a uno hasta aislar el invalido |
| Run `failed` con `Cannot insert NULL` | La tabla destino legacy tiene columnas NOT NULL sin default que no estan cubiertas por `columnMap` | Agrega la columna faltante al `columnMap`, o deja que la introspeccion automatica genere zero-values (ver `columnMap` en `docs/job-config-schema.md`) |
| `502 sap_communication_error` | Circuit breaker abierto o NCo no alcanza al AS | Verifica `SAP_DESTINATIONS__<ALIAS>__*` y conectividad al SAProuter. El breaker cierra solo despues de `ETL_RFC_CIRCUIT_BREAKER_DURATION_SECS` |
| `409 concurrency_group_busy` | Otro job del mismo `CONCURRENCY_GROUP` esta corriendo | Espera, o revisa `GET /api/v1/runs?status=running` |
| `401 unauthorized` | Token incorrecto o header ausente | Verifica el `ETL_API_TOKEN` del host |

## Schemas JSON de `DEFAULT_PARAMETERS`

Contrato canonico: `src/Greenvic.SapEtl.Core/Jobs/JobConfiguration.cs`.

### RFC

```json
{
  "transport": "rfc",
  "destinationAlias": "PRD",
  "table": "ACDOCA",
  "rfcFunction": "/BODS/RFC_READ_TABLE2",
  "fields": ["RBUKRS","GJAHR","BELNR","DOCLN","BUDAT","HSL"],
  "whereTemplate": "RBUKRS = '{companyCode}' AND BUDAT BETWEEN '{partitionFrom:yyyyMMdd}' AND '{partitionTo:yyyyMMdd}'",
  "delimiter": "|",
  "maxRowsPerCall": 0,
  "defaultParams": { "companyCodes": ["1000"], "ledger": "0L" },
  "segmentation": [
    { "kind":"dateRange", "param":"BUDAT", "format":"yyyyMMdd", "step":"1.00:00:00", "fromParam":"fromDate", "toParam":"toDate" },
    { "kind":"values", "param":"companyCode", "fromParamList":"companyCodes" }
  ],
  "target": {
    "alias": "APOLO2",
    "schema": "lcc",
    "table": "ACDOCA",
    "mode": "stagingMerge",
    "matchColumns": ["RBUKRS","GJAHR","BELNR","DOCLN","RLDNR"]
  }
}
```

`defaultParams` es un dict opcional de parametros fallback. Se usan cuando el run no pasa parametros explicitos (caso tipico: disparo por cron scheduled). Los parametros del run siempre ganan sobre los `defaultParams`.

### OData

```json
{
  "transport": "odata",
  "destinationAlias": "PRD_GW",
  "entitySet": "YWTGW_GET_REPORT_INVEN_SRV/ywtgw_get_inventarioSet",
  "filterTemplate": "Werks eq '{plant}' and Lgort eq '{storage}'",
  "select": ["Matnr","Werks","Lgort","Maktx","Labst"],
  "orderBy": "Matnr",
  "pageSize": 1000,
  "defaultParams": { "plants": ["2001"], "storages": ["1001"] },
  "segmentation": [
    { "kind":"values", "param":"plant",   "fromParamList":"plants" },
    { "kind":"values", "param":"storage", "fromParamList":"storages" }
  ],
  "target": {
    "alias": "ATENEA",
    "schema": "wms",
    "table": "INVENTARIO",
    "mode": "stagingMerge",
    "matchColumns": ["Matnr","Werks","Lgort","Charg"],
    "columnMap": {
      "Matnr": "MATERIAL",
      "Werks": "PLANTA",
      "Lgort": "ALMACEN"
    }
  }
}
```

`columnMap` es un dict opcional `sourceField -> targetColumn` para mapear campos SAP a columnas de tablas legacy existentes. Si esta presente, el sink no crea ni altera la tabla destino. Si esta ausente, el match es 1:1 por nombre.

## Como construir el JSON de un job RFC (end-to-end)

```sql
INSERT INTO etl.ETL_JOB_DEFINITION
  (JOB_KEY, DISPLAY_NAME, JOB_TYPE, DESTINATION_ALIAS, CRON_EXPRESSION, ENABLED, DEFAULT_PARAMETERS, CONCURRENCY_GROUP)
VALUES (
  'mi.job.diario',
  'Mi descripcion',
  'rfc',
  'PRD',                       -- alias del SAP destination, o NULL para usar el default global
  '0 0 4 * * ?',               -- cron Quartz (Seg Min Hora DOM Mes DOW), o NULL si solo manual
  1,
  N'{
    "transport": "rfc",
    "table": "MARA",
    "fields": ["MATNR","MAKTX","ERSDA","MTART"],
    "whereTemplate": "MTART = ''{type}'' AND ERSDA >= ''{partitionFrom:yyyyMMdd}''",
    "defaultParams": { "materialTypes": ["FERT","HALB"] },
    "segmentation": [
      {"kind":"dateRange","param":"ERSDA","format":"yyyyMMdd","step":"30.00:00:00","fromParam":"fromDate","toParam":"toDate"},
      {"kind":"values","param":"type","fromParamList":"materialTypes"}
    ],
    "target": {
      "alias": "APOLO2",
      "schema": "mm",
      "table": "MARA",
      "mode": "stagingMerge",
      "matchColumns": ["MATNR"]
    },
    "delimiter": "|",
    "maxRowsPerCall": 0
  }',
  'sap.mm'
);
```

Comillas simples dentro del JSON SQL se duplican (`''{type}''` en SQL = `'{type}'` en el JSON real).

## Como dispararlo

```bash
curl -X POST http://192.168.8.24:5090/api/v1/jobs/mi.job.diario/run \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{
    "parameters": {
      "fromDate": "2026-01-01",
      "toDate": "2026-04-01",
      "materialTypes": ["FERT","HALB","ROH"]
    }
  }'
```

Resultado: `{ "data": { "runId": 42 }, ... }`. El job genera 3 dimensiones
temporales (Q1 en steps de 30 dias) x 3 tipos = **9 particiones**. Cada
particion hace un RFC independiente y carga a `[mm].[STG_MARA_42]` en el
target `APOLO2`. Al terminar todas las particiones, el sink hace
`MERGE INTO [mm].[MARA]` atomico y `DROP TABLE [mm].[STG_MARA_42]`.

## Glosario

- **Job key** - Identificador unico del job en `ETL_JOB_DEFINITION.JOB_KEY`. Convencion: `<sistema>.<entidad>.<frecuencia>` (ej. `lcc.acdoca.daily`, `inv.ywt.hourly`).
- **Destination** - Alias de un sistema SAP (NCo o OData) configurado en `.env` via `SAP_DESTINATIONS__<ALIAS>__*` o `SAP_ODATA_DESTINATIONS__<ALIAS>__*`.
- **SQL target** - Alias de un SQL Server destino donde el sink carga datos. Configurado en `.env` via `SQL_TARGETS__<ALIAS>__*`. Un mismo host SQL puede tener N aliases con distintas BDs.
- **Partition** - Unidad atomica de extraccion + carga. Una por combinacion cartesiana de dimensiones en `segmentation[]`.
- **Staging merge** - Patron: `SqlBulkCopy` a tabla temporal `STG_<table>_<runId>` por particion -> `MERGE` atomico contra el destino -> `DROP` del staging. El `DROP` va en un `try/finally` para que el staging se limpie incluso si el MERGE falla.
- **Concurrency group** - Campo `ETL_JOB_DEFINITION.CONCURRENCY_GROUP`. Dos jobs con el mismo grupo nunca corren simultaneamente en el mismo host (semaforo in-process).
- **Trigger kind** - `Manual` (via `/run`), `Scheduled` (via cron Quartz), `Retry` (via `/retry`), `Backfill` (via `/backfill`).
