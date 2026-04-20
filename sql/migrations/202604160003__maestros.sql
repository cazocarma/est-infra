-- =============================================================================
-- 202604160003__maestros.sql
-- Maestros internos del sistema EST. Todo bajo schema `est`.
-- Catalogos pequenos (Condicion, Destino, TipoCalidad, TipoColor, TipoEnvase)
-- y maestros de negocio (Temporada, Planta, Unidad, UnidadKilos, PesoPromedio,
-- GrupoProductor).
-- Las FKs a sap.VariedadSap / sap.EspecieSap quedan declaradas como columnas
-- nullable y se agregan como constraints en la migracion de Fase 3 cuando
-- existan las tablas espejo.
-- Idempotente.
-- =============================================================================
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
SET NOCOUNT ON;
SET XACT_ABORT ON;

------------------------------------------------------------
-- Catalogos pequenos (Id, Codigo, Nombre, Orden, Activo)
------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE object_id = OBJECT_ID(N'est.Condicion'))
BEGIN
    CREATE TABLE est.Condicion (
        CondicionId SMALLINT     IDENTITY(1,1) NOT NULL CONSTRAINT PK_est_Condicion PRIMARY KEY,
        Codigo      NVARCHAR(32) NOT NULL CONSTRAINT UQ_est_Condicion_Codigo UNIQUE,
        Nombre      NVARCHAR(120) NOT NULL,
        Orden       INT          NOT NULL CONSTRAINT DF_est_Condicion_Orden DEFAULT 0,
        Activo      BIT          NOT NULL CONSTRAINT DF_est_Condicion_Activo DEFAULT 1,
        CreatedAt   DATETIME2(0) NOT NULL CONSTRAINT DF_est_Condicion_CreatedAt DEFAULT SYSUTCDATETIME(),
        UpdatedAt   DATETIME2(0) NOT NULL CONSTRAINT DF_est_Condicion_UpdatedAt DEFAULT SYSUTCDATETIME()
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE object_id = OBJECT_ID(N'est.Destino'))
BEGIN
    CREATE TABLE est.Destino (
        DestinoId   SMALLINT     IDENTITY(1,1) NOT NULL CONSTRAINT PK_est_Destino PRIMARY KEY,
        Codigo      NVARCHAR(32) NOT NULL CONSTRAINT UQ_est_Destino_Codigo UNIQUE,
        Nombre      NVARCHAR(120) NOT NULL,
        Orden       INT          NOT NULL CONSTRAINT DF_est_Destino_Orden DEFAULT 0,
        Activo      BIT          NOT NULL CONSTRAINT DF_est_Destino_Activo DEFAULT 1,
        CreatedAt   DATETIME2(0) NOT NULL CONSTRAINT DF_est_Destino_CreatedAt DEFAULT SYSUTCDATETIME(),
        UpdatedAt   DATETIME2(0) NOT NULL CONSTRAINT DF_est_Destino_UpdatedAt DEFAULT SYSUTCDATETIME()
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE object_id = OBJECT_ID(N'est.TipoCalidad'))
BEGIN
    CREATE TABLE est.TipoCalidad (
        TipoCalidadId SMALLINT     IDENTITY(1,1) NOT NULL CONSTRAINT PK_est_TipoCalidad PRIMARY KEY,
        Codigo        NVARCHAR(32) NOT NULL CONSTRAINT UQ_est_TipoCalidad_Codigo UNIQUE,
        Nombre        NVARCHAR(120) NOT NULL,
        Orden         INT          NOT NULL CONSTRAINT DF_est_TipoCalidad_Orden DEFAULT 0,
        Activo        BIT          NOT NULL CONSTRAINT DF_est_TipoCalidad_Activo DEFAULT 1,
        CreatedAt     DATETIME2(0) NOT NULL CONSTRAINT DF_est_TipoCalidad_CreatedAt DEFAULT SYSUTCDATETIME(),
        UpdatedAt     DATETIME2(0) NOT NULL CONSTRAINT DF_est_TipoCalidad_UpdatedAt DEFAULT SYSUTCDATETIME()
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE object_id = OBJECT_ID(N'est.TipoColor'))
BEGIN
    CREATE TABLE est.TipoColor (
        TipoColorId SMALLINT     IDENTITY(1,1) NOT NULL CONSTRAINT PK_est_TipoColor PRIMARY KEY,
        Codigo      NVARCHAR(32) NOT NULL CONSTRAINT UQ_est_TipoColor_Codigo UNIQUE,
        Nombre      NVARCHAR(120) NOT NULL,
        Orden       INT          NOT NULL CONSTRAINT DF_est_TipoColor_Orden DEFAULT 0,
        Activo      BIT          NOT NULL CONSTRAINT DF_est_TipoColor_Activo DEFAULT 1,
        CreatedAt   DATETIME2(0) NOT NULL CONSTRAINT DF_est_TipoColor_CreatedAt DEFAULT SYSUTCDATETIME(),
        UpdatedAt   DATETIME2(0) NOT NULL CONSTRAINT DF_est_TipoColor_UpdatedAt DEFAULT SYSUTCDATETIME()
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE object_id = OBJECT_ID(N'est.TipoEnvase'))
BEGIN
    CREATE TABLE est.TipoEnvase (
        TipoEnvaseId SMALLINT     IDENTITY(1,1) NOT NULL CONSTRAINT PK_est_TipoEnvase PRIMARY KEY,
        Codigo       NVARCHAR(32) NOT NULL CONSTRAINT UQ_est_TipoEnvase_Codigo UNIQUE,
        Nombre       NVARCHAR(120) NOT NULL,
        Orden        INT          NOT NULL CONSTRAINT DF_est_TipoEnvase_Orden DEFAULT 0,
        Activo       BIT          NOT NULL CONSTRAINT DF_est_TipoEnvase_Activo DEFAULT 1,
        CreatedAt    DATETIME2(0) NOT NULL CONSTRAINT DF_est_TipoEnvase_CreatedAt DEFAULT SYSUTCDATETIME(),
        UpdatedAt    DATETIME2(0) NOT NULL CONSTRAINT DF_est_TipoEnvase_UpdatedAt DEFAULT SYSUTCDATETIME()
    );
END
GO

------------------------------------------------------------
-- Temporada
------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE object_id = OBJECT_ID(N'est.Temporada'))
BEGIN
    CREATE TABLE est.Temporada (
        TemporadaId INT          IDENTITY(1,1) NOT NULL CONSTRAINT PK_est_Temporada PRIMARY KEY,
        Anio        SMALLINT     NOT NULL,
        Prefijo     NVARCHAR(10) NOT NULL,
        Descripcion NVARCHAR(200) NULL,
        FechaInicio DATE         NULL,
        FechaFin    DATE         NULL,
        Activa      BIT          NOT NULL CONSTRAINT DF_est_Temporada_Activa    DEFAULT 0,
        CreatedAt   DATETIME2(0) NOT NULL CONSTRAINT DF_est_Temporada_CreatedAt DEFAULT SYSUTCDATETIME(),
        UpdatedAt   DATETIME2(0) NOT NULL CONSTRAINT DF_est_Temporada_UpdatedAt DEFAULT SYSUTCDATETIME(),
        CreatedBy   BIGINT       NULL,
        UpdatedBy   BIGINT       NULL,
        CONSTRAINT UQ_est_Temporada_Anio_Prefijo UNIQUE (Anio, Prefijo),
        CONSTRAINT FK_est_Temporada_Created FOREIGN KEY (CreatedBy) REFERENCES est.Usuario(UsuarioId),
        CONSTRAINT FK_est_Temporada_Updated FOREIGN KEY (UpdatedBy) REFERENCES est.Usuario(UsuarioId),
        CONSTRAINT CK_est_Temporada_Fechas  CHECK (FechaFin IS NULL OR FechaInicio IS NULL OR FechaFin >= FechaInicio)
    );
    CREATE UNIQUE INDEX UX_est_Temporada_Activa ON est.Temporada(Activa) WHERE Activa = 1;
END
GO

------------------------------------------------------------
-- Planta
------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE object_id = OBJECT_ID(N'est.Planta'))
BEGIN
    CREATE TABLE est.Planta (
        PlantaId   INT           IDENTITY(1,1) NOT NULL CONSTRAINT PK_est_Planta PRIMARY KEY,
        Codigo     NVARCHAR(32)  NOT NULL CONSTRAINT UQ_est_Planta_Codigo UNIQUE,
        Nombre     NVARCHAR(200) NOT NULL,
        Direccion  NVARCHAR(300) NULL,
        Zona       NVARCHAR(20)  NULL,
        EsExterna  BIT           NOT NULL CONSTRAINT DF_est_Planta_EsExterna DEFAULT 0,
        Activa     BIT           NOT NULL CONSTRAINT DF_est_Planta_Activa    DEFAULT 1,
        CreatedAt  DATETIME2(0)  NOT NULL CONSTRAINT DF_est_Planta_CreatedAt DEFAULT SYSUTCDATETIME(),
        UpdatedAt  DATETIME2(0)  NOT NULL CONSTRAINT DF_est_Planta_UpdatedAt DEFAULT SYSUTCDATETIME(),
        CreatedBy  BIGINT        NULL,
        UpdatedBy  BIGINT        NULL,
        CONSTRAINT FK_est_Planta_Created FOREIGN KEY (CreatedBy) REFERENCES est.Usuario(UsuarioId),
        CONSTRAINT FK_est_Planta_Updated FOREIGN KEY (UpdatedBy) REFERENCES est.Usuario(UsuarioId),
        CONSTRAINT CK_est_Planta_Zona    CHECK (Zona IS NULL OR Zona IN (N'NORTE', N'SUR'))
    );
END
GO

------------------------------------------------------------
-- Unidad
------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE object_id = OBJECT_ID(N'est.Unidad'))
BEGIN
    CREATE TABLE est.Unidad (
        UnidadId    INT           IDENTITY(1,1) NOT NULL CONSTRAINT PK_est_Unidad PRIMARY KEY,
        Codigo      NVARCHAR(32)  NOT NULL CONSTRAINT UQ_est_Unidad_Codigo UNIQUE,
        Nombre      NVARCHAR(200) NOT NULL,
        Descripcion NVARCHAR(300) NULL,
        Activa      BIT           NOT NULL CONSTRAINT DF_est_Unidad_Activa    DEFAULT 1,
        CreatedAt   DATETIME2(0)  NOT NULL CONSTRAINT DF_est_Unidad_CreatedAt DEFAULT SYSUTCDATETIME(),
        UpdatedAt   DATETIME2(0)  NOT NULL CONSTRAINT DF_est_Unidad_UpdatedAt DEFAULT SYSUTCDATETIME(),
        CreatedBy   BIGINT        NULL,
        UpdatedBy   BIGINT        NULL,
        CONSTRAINT FK_est_Unidad_Created FOREIGN KEY (CreatedBy) REFERENCES est.Usuario(UsuarioId),
        CONSTRAINT FK_est_Unidad_Updated FOREIGN KEY (UpdatedBy) REFERENCES est.Usuario(UsuarioId)
    );
END
GO

------------------------------------------------------------
-- GrupoProductor
------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE object_id = OBJECT_ID(N'est.GrupoProductor'))
BEGIN
    CREATE TABLE est.GrupoProductor (
        GrupoProductorId INT           IDENTITY(1,1) NOT NULL CONSTRAINT PK_est_GrupoProductor PRIMARY KEY,
        Codigo           NVARCHAR(32)  NOT NULL CONSTRAINT UQ_est_GrupoProductor_Codigo UNIQUE,
        Nombre           NVARCHAR(200) NOT NULL,
        Activo           BIT           NOT NULL CONSTRAINT DF_est_GrupoProductor_Activo    DEFAULT 1,
        CreatedAt        DATETIME2(0)  NOT NULL CONSTRAINT DF_est_GrupoProductor_CreatedAt DEFAULT SYSUTCDATETIME(),
        UpdatedAt        DATETIME2(0)  NOT NULL CONSTRAINT DF_est_GrupoProductor_UpdatedAt DEFAULT SYSUTCDATETIME(),
        CreatedBy        BIGINT        NULL,
        UpdatedBy        BIGINT        NULL,
        CONSTRAINT FK_est_GrupoProductor_Created FOREIGN KEY (CreatedBy) REFERENCES est.Usuario(UsuarioId),
        CONSTRAINT FK_est_GrupoProductor_Updated FOREIGN KEY (UpdatedBy) REFERENCES est.Usuario(UsuarioId)
    );
END
GO

------------------------------------------------------------
-- UnidadKilos
------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE object_id = OBJECT_ID(N'est.UnidadKilos'))
BEGIN
    CREATE TABLE est.UnidadKilos (
        UnidadKilosId        INT           IDENTITY(1,1) NOT NULL CONSTRAINT PK_est_UnidadKilos PRIMARY KEY,
        UnidadId             INT           NOT NULL,
        VariedadSapId        BIGINT        NULL, -- FK aplicada en Fase 3
        Kilos                DECIMAL(10,4) NOT NULL,
        KilosCajaEquivalente DECIMAL(10,4) NOT NULL,
        Activo               BIT           NOT NULL CONSTRAINT DF_est_UnidadKilos_Activo    DEFAULT 1,
        CreatedAt            DATETIME2(0)  NOT NULL CONSTRAINT DF_est_UnidadKilos_CreatedAt DEFAULT SYSUTCDATETIME(),
        UpdatedAt            DATETIME2(0)  NOT NULL CONSTRAINT DF_est_UnidadKilos_UpdatedAt DEFAULT SYSUTCDATETIME(),
        CreatedBy            BIGINT        NULL,
        UpdatedBy            BIGINT        NULL,
        CONSTRAINT FK_est_UnidadKilos_Unidad  FOREIGN KEY (UnidadId)  REFERENCES est.Unidad(UnidadId),
        CONSTRAINT FK_est_UnidadKilos_Created FOREIGN KEY (CreatedBy) REFERENCES est.Usuario(UsuarioId),
        CONSTRAINT FK_est_UnidadKilos_Updated FOREIGN KEY (UpdatedBy) REFERENCES est.Usuario(UsuarioId),
        CONSTRAINT CK_est_UnidadKilos_Kilos   CHECK (Kilos > 0 AND KilosCajaEquivalente > 0)
    );
    CREATE INDEX IX_est_UnidadKilos_Unidad   ON est.UnidadKilos(UnidadId);
    CREATE INDEX IX_est_UnidadKilos_Variedad ON est.UnidadKilos(VariedadSapId);
END
GO

------------------------------------------------------------
-- PesoPromedio
------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE object_id = OBJECT_ID(N'est.PesoPromedio'))
BEGIN
    CREATE TABLE est.PesoPromedio (
        PesoPromedioId INT           IDENTITY(1,1) NOT NULL CONSTRAINT PK_est_PesoPromedio PRIMARY KEY,
        TipoEnvaseId   SMALLINT      NOT NULL,
        EspecieSapId   BIGINT        NULL, -- FK aplicada en Fase 3
        Peso           DECIMAL(10,4) NOT NULL,
        Activo         BIT           NOT NULL CONSTRAINT DF_est_PesoPromedio_Activo    DEFAULT 1,
        CreatedAt      DATETIME2(0)  NOT NULL CONSTRAINT DF_est_PesoPromedio_CreatedAt DEFAULT SYSUTCDATETIME(),
        UpdatedAt      DATETIME2(0)  NOT NULL CONSTRAINT DF_est_PesoPromedio_UpdatedAt DEFAULT SYSUTCDATETIME(),
        CreatedBy      BIGINT        NULL,
        UpdatedBy      BIGINT        NULL,
        CONSTRAINT FK_est_PesoPromedio_TipoEnvase FOREIGN KEY (TipoEnvaseId) REFERENCES est.TipoEnvase(TipoEnvaseId),
        CONSTRAINT FK_est_PesoPromedio_Created   FOREIGN KEY (CreatedBy)    REFERENCES est.Usuario(UsuarioId),
        CONSTRAINT FK_est_PesoPromedio_Updated   FOREIGN KEY (UpdatedBy)    REFERENCES est.Usuario(UsuarioId),
        CONSTRAINT CK_est_PesoPromedio_Peso      CHECK (Peso > 0)
    );
END
GO

-- Nota: NO se crean triggers TR_<Tabla>_UpdatedAt - romperian OUTPUT en
-- MERGE/INSERT statements (error 334). Convencion: cada UPDATE del backend
-- incluye `UpdatedAt = SYSUTCDATETIME()` explicitamente en el SET.

INSERT INTO meta.Migracion (NombreArchivo)
SELECT N'202604160003__maestros.sql'
WHERE NOT EXISTS (SELECT 1 FROM meta.Migracion WHERE NombreArchivo = N'202604160003__maestros.sql');
GO

PRINT '202604160003__maestros aplicada.';
GO
