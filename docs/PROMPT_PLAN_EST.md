🔵 [PROMPT OPTIMIZADO]

# Task: Create Full Development Plan for "Estimaciones" (EST) System

You are a senior full-stack developer. Produce a complete, phased development plan for the EST system. Save it as `DEVELOPMENT_PLAN.md` inside `est-infra/`.

---

## System Overview

**EST (Estimaciones)** is an agricultural harvest estimation platform. Agronomists manage predictions for crops across assigned farms/fields. The system tracks:

- **Temporadas** (seasons) with year-based lifecycle
- **Especies** (species), **Variedades** (varieties), **Grupos de Variedad**
- **Productores** (producers/farms), **Cuarteles** (field blocks/plots)
- **Agrónomos** assigned to Producer-Variety combinations
- **Two prediction types**, both with version control:
  1. **Estimación General**: Done once at the start of a variety's season. Each variety has its own harvest calendar (some harvested week 30, others week 40, etc.). Includes volume distribution per week, caliber percentages, and typification values.
  2. **Estimación Bisemanal**: Biweekly (current week + next week). Daily breakdown (Mon-Sun) of kilos harvested/received. Purpose: workforce planning to prevent overwork and ensure labor conditions during peak periods. Includes plant destination, cold type, export percentage, packaging unit.
- **Version control**: Both prediction types allow modifications only if the prediction period hasn't occurred yet (based on current date). Each version is a complete snapshot with open/close lifecycle.
- **BI Views**: Critical views consumed by BI team for reporting (historical, regional splits norte/sur, data dictionary).

---

## Tech Stack — Three Repositories

| Repo | Stack | Purpose |
|---|---|---|
| `est-front-ng` | Angular 21 | SPA frontend |
| `est-back` | Node.js + Express | REST API backend |
| `est-infra` | SQL scripts, Makefile, Docker Compose | Infrastructure, DB migrations, orchestration |

---

## Reference Database Schema (Legacy — Use as Reference Only)

The attached `EST.sql` is the legacy SQL Server database. Use it as reference to design a **clean, normalized, complete** data model. The new model must:

- Cover all fields and relationships from the legacy schema
- Include proper constraints, indexes, and foreign keys (the legacy uses `nvarchar(max)` everywhere — fix this)
- Replace GUIDs with appropriate ID strategy for the new stack
- Include views for BI consumption (equivalent to `VW_ESTIMACION_BISEMANAL_HISTORICO`, `VW_ESTIMACION_BISEMANAL_USER_NORTE`, `VW_ESTIMACION_BISEMANAL_USER_SUR`, `VW_DICCIONARIO_DE_DATOS`)
- Include stored procedures or equivalent for complex operations (version creation, version closure, report generation)
- Eliminate legacy cruft: `temp_*` tables, `OLD*` views, `__EFMigrationsHistory`, `acofre01`, `asoex_condicionfruta`, `TMP_*` tables

### Key Legacy Tables (for reference mapping):

**Core Domain:**
- `TemporadaConfiguracion` — Season config (year, prefix, active)
- `Estimacion` — General estimation header (agronomist, season, species, management type, folio, version ref)
- `EstimacionVolumen` — Volume per producer-variety (kilos, packaging, export %, equivalent boxes)
- `EstimacionVolumenSemana` — Weekly volume distribution
- `EstimacionCalibre` — Caliber percentage distribution per estimation
- `EstimacionTipificacion` — Typification values per estimation

**Biweekly:**
- `EstimacionBisemanal` — Daily kg breakdown (Mon-Sun), week number, cold type, plant destination, export %
- `EstimacionBisemanalControlVersion` — Version control for biweekly (version number, open/close dates, state)
- `ControlEstimacionBisemanal` / `ControlDetalleEstimacionBisemanal` — Biweekly period control with date ranges per week

**Version History (snapshot pattern):**
- `EstimacionControlVersion` — Version control for general estimation
- `EstimacionVersion`, `EstimacionVolumenVersion`, `EstimacionVolumenSemanaVersion` — General snapshots
- `EstimacionBisemanalVersion`, `EstimacionCalibreVersion`, `EstimacionTipificacionVersion` — Biweekly snapshots

**Master Data (synced from SAP):**
- `ProductorEstadoSap`, `ProductorVariedadEstadoSap` — Producer and their variety assignments (includes OGL, Walmart, SystemApproach flags, SDP, Cuartel)
- `ProductorVariedadEstadoSemanaSap` — Week ranges per variety per season
- `EspecieEstadoSap`, `GrupoVariedadEstadoSap`, `VariedadEstadoSap` — Species hierarchy
- `VariedadEstadoCalibreSap` — Caliber definitions per variety (caliber code, type: Grande/Mediano/Pequeño/Otro, order)
- `ManejoEstadoSap`, `EnvaseEstadoSap`, `TipoFrioEstadoSap`, `CentroEstadoSap`, `ProgramaEstadoSap` — Lookup tables from SAP

**Users & Assignments:**
- `Usuario` — User (name, RUT, DV)
- `Agronomo` — Agronomist (linked to user and plant)
- `AgronomoProductorVariedadEstadoSap` — Assignment pivot: agronomist ↔ producer-variety
- `Rol`, `UsuarioRol`, `UsuarioCuenta` — Auth/roles
- `AgronomoVisita`, `AgronomoVisitaDocumento` — Field visits with GPS and photos

**Supporting:**
- `Planta` — Processing plants (code, address, external flag)
- `Productor` — Producer master (name, RUT, SAP code, SAG code, email, group)
- `GrupoProductor` — Producer groups
- `Unidad` — Packaging units
- `UnidadKilos` — Kilos per unit per variety (includes equivalent box weight)
- `EspecieTipificacion` — Typification categories per variety
- `PesoPromedio` — Average weight per species/packaging
- `FechaEstimacionGeneral` — Date windows for general estimation by species
- `Condicion`, `Destino`, `TipoCalidad`, `TipoColor`, `TipoEnvase` — Catalog tables
- `CargaEstimacionInformacion`, `CargaEstimacionVersion`, `CargaEstimacionFiltro` — Bulk load tracking

**BI-specific:**
- `EstimacionBisemanalBI` (schema `dba`) — Denormalized table for BI consumption with all joined fields

**Key Functions:**
- `FN_KILOS_CALIBRE_BISEMANAL` / `FN_KILOS_CALIBRE_GENERAL` — Calculate kilos by caliber
- `FN_KILOS_TIPIFICACION_BISEMANAL` / `FN_KILOS_TIPIFICACION_GENERAL` — Calculate kilos by typification

**Key Stored Procedures (50+):**
- Version lifecycle: `CrearEstimacionControlVersion`, `CierreEstimacionControlVersion`, `CrearEstimacionBisemanalControlVersion`, `CierreEstimacionBisemanalControlVersion`
- Data retrieval: `ListEstimacionVolumen`, `ListEstimacionCalibre`, `ListEstimacionTipificacion`, `ListEstimacionVolumenSemana` (each has v2 variants)
- Reports: `SP_REPORTE_ESTIMACION_ANUAL`, `SP_REPORTE_ESTIMACION_BISEMANAL`, `Informe_EstimacionBisemanal`, `Informe_EstimacionGeneral`, `Informe_RecepcionReal`
- SAP integration: `ListProductoresSAP`, `ListProductoresWithDataSAP`, `ListProductorVariedadSap`, `ListProductorVariedadSemanaSap` (v1-v3)
- Mobile-specific: `ListEspecieMobile`, `ListProductorMobile`, `ListVariedadMobile`
- Aggregation: `ListaTemporadaRecepcionActualAgrupadoSemana`, `ListaResumenRecepcionRealPorDia`, `ListaResumenRecepcionRealPorSemana`

---

## Development Approach

**Incremental by COMPLETE FEATURES** — not incremental by layer. Each phase delivers a fully functional vertical slice (DB + API + UI) that can be tested and used. No mockups-first approach.

---

## Plan Requirements

### Structure the plan in phases. Each phase must include:

1. **Feature scope**: What business capability is delivered
2. **Database**: Tables, migrations, seeds, views, SPs needed
3. **Backend**: Endpoints (method, route, request/response), middleware, services
4. **Frontend**: Pages, components, services, routing
5. **Acceptance criteria**: What "done" means for this phase
6. **Dependencies**: What must exist before this phase starts

### Mandatory phases to cover (order them logically):

- Infrastructure setup (Docker, DB, project scaffolding, CI)
- Authentication & authorization (read specs from `est-infra/` docs)
- Master data management (seasons, species, varieties, producers, plants, agronomists, assignments)
- SAP data synchronization
- General estimation CRUD with version control
- Biweekly estimation CRUD with version control
- Estimation calendar and date control per species
- Reports and BI views
- Field visits (agronomist visits with GPS + photo upload)
- Bulk data load (Excel/CSV import for estimations)
- Dashboard / monitoring

### Additional specs:

- Read authentication, design, and DB connection docs from `est-infra/` when they exist — treat them as authoritative specs
- The DB connection strategy must support SQL Server (legacy data source for SAP reads) and the new application database
- All code must follow SOLID principles, clean architecture, no legacy patterns or patch solutions
- The plan itself must be maintainable — it will be updated as development progresses

---

## Output Format

- Single Markdown file: `DEVELOPMENT_PLAN.md`
- Use clear phase headers with numbering (Phase 0, Phase 1, etc.)
- Each phase: narrative description + tables for endpoints + component trees
- Include a dependency graph or order summary at the top
- Include estimated complexity per phase (S/M/L/XL)
- Total number of phases should reflect real-world incremental delivery, not artificial granularity

## Language

Respond in Spanish for all explanations, descriptions, and comments. Technical terms (endpoint names, table names, code identifiers) remain in their original language.

// Nota: Este prompt fue generado para máxima eficiencia de tokens.
