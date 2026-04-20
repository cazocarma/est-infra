-- =============================================================================
-- 202604160001__init_schema.sql
-- Convenciones:
--   - Schema `est`  -> dominio propio del sistema (auth, maestros,
--                      estimaciones, carga, vistas BI, etc.).
--   - Schema `sap`  -> espejo de maestros SAP (externo al sistema).
--   - Schema `meta` -> tracking de migraciones aplicadas.
--   - `dbo` NO se usa para objetos propios del sistema.
--   - Tablas en PascalCase singular; columnas PascalCase; PK `<Tabla>Id`;
--     FK `<TablaReferida>Id`.
-- Idempotente.
-- =============================================================================
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
SET NOCOUNT ON;
SET XACT_ABORT ON;

-- meta: tracking de migraciones
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'meta')
    EXEC(N'CREATE SCHEMA [meta] AUTHORIZATION [dbo]');
GO

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE object_id = OBJECT_ID(N'meta.Migracion'))
BEGIN
    CREATE TABLE meta.Migracion (
        MigracionId   BIGINT        IDENTITY(1,1) NOT NULL CONSTRAINT PK_meta_Migracion PRIMARY KEY,
        NombreArchivo NVARCHAR(200) NOT NULL CONSTRAINT UQ_meta_Migracion_Archivo UNIQUE,
        AplicadaEn    DATETIME2(0)  NOT NULL CONSTRAINT DF_meta_Migracion_AplicadaEn DEFAULT SYSUTCDATETIME(),
        HashSha256    NVARCHAR(64)  NULL
    );
END
GO

-- est: dominio del sistema (todas las tablas propias de EST)
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'est')
    EXEC(N'CREATE SCHEMA [est] AUTHORIZATION [dbo]');
GO

-- sap: espejo externo (se puebla en Fase 3 con ProductorSap, VariedadSap, ...)
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'sap')
    EXEC(N'CREATE SCHEMA [sap] AUTHORIZATION [dbo]');
GO

INSERT INTO meta.Migracion (NombreArchivo)
SELECT N'202604160001__init_schema.sql'
WHERE NOT EXISTS (SELECT 1 FROM meta.Migracion WHERE NombreArchivo = N'202604160001__init_schema.sql');
GO

PRINT '202604160001__init_schema aplicada.';
GO
