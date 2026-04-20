-- =============================================================================
-- 202604160004__sap.sql
-- Schema `sap` - espejo de maestros de SAP (externo al sistema EST).
-- Se puebla por sync desde el adapter ETL (ver docs/SAP_ETL_AGENT_GUIDE.md).
-- Idempotente.
-- =============================================================================
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
SET NOCOUNT ON;
SET XACT_ABORT ON;

------------------------------------------------------------
-- sap.EspecieSap
------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE object_id = OBJECT_ID(N'sap.EspecieSap'))
BEGIN
    CREATE TABLE sap.EspecieSap (
        EspecieSapId BIGINT       IDENTITY(1,1) NOT NULL CONSTRAINT PK_sap_EspecieSap PRIMARY KEY,
        CodigoSap    NVARCHAR(32) NOT NULL CONSTRAINT UQ_sap_EspecieSap_Codigo UNIQUE,
        Nombre       NVARCHAR(200) NOT NULL,
        Activo       BIT          NOT NULL CONSTRAINT DF_sap_EspecieSap_Activo DEFAULT 1,
        SyncedAt     DATETIME2(0) NOT NULL CONSTRAINT DF_sap_EspecieSap_SyncedAt DEFAULT SYSUTCDATETIME()
    );
END
GO

------------------------------------------------------------
-- sap.GrupoVariedadSap
------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE object_id = OBJECT_ID(N'sap.GrupoVariedadSap'))
BEGIN
    CREATE TABLE sap.GrupoVariedadSap (
        GrupoVariedadSapId BIGINT        IDENTITY(1,1) NOT NULL CONSTRAINT PK_sap_GrupoVariedadSap PRIMARY KEY,
        CodigoSap          NVARCHAR(32)  NOT NULL CONSTRAINT UQ_sap_GrupoVariedadSap_Codigo UNIQUE,
        EspecieSapId       BIGINT        NULL,
        Nombre             NVARCHAR(200) NOT NULL,
        Activo             BIT           NOT NULL CONSTRAINT DF_sap_GrupoVariedadSap_Activo DEFAULT 1,
        SyncedAt           DATETIME2(0)  NOT NULL CONSTRAINT DF_sap_GrupoVariedadSap_SyncedAt DEFAULT SYSUTCDATETIME(),
        CONSTRAINT FK_sap_GrupoVariedadSap_Especie FOREIGN KEY (EspecieSapId) REFERENCES sap.EspecieSap(EspecieSapId)
    );
    CREATE INDEX IX_sap_GrupoVariedadSap_Especie ON sap.GrupoVariedadSap(EspecieSapId);
END
GO

------------------------------------------------------------
-- sap.VariedadSap
------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE object_id = OBJECT_ID(N'sap.VariedadSap'))
BEGIN
    CREATE TABLE sap.VariedadSap (
        VariedadSapId      BIGINT        IDENTITY(1,1) NOT NULL CONSTRAINT PK_sap_VariedadSap PRIMARY KEY,
        CodigoSap          NVARCHAR(32)  NOT NULL CONSTRAINT UQ_sap_VariedadSap_Codigo UNIQUE,
        EspecieSapId       BIGINT        NULL,
        GrupoVariedadSapId BIGINT        NULL,
        Nombre             NVARCHAR(200) NOT NULL,
        Activo             BIT           NOT NULL CONSTRAINT DF_sap_VariedadSap_Activo DEFAULT 1,
        SyncedAt           DATETIME2(0)  NOT NULL CONSTRAINT DF_sap_VariedadSap_SyncedAt DEFAULT SYSUTCDATETIME(),
        CONSTRAINT FK_sap_VariedadSap_Especie FOREIGN KEY (EspecieSapId)       REFERENCES sap.EspecieSap(EspecieSapId),
        CONSTRAINT FK_sap_VariedadSap_Grupo   FOREIGN KEY (GrupoVariedadSapId) REFERENCES sap.GrupoVariedadSap(GrupoVariedadSapId)
    );
    CREATE INDEX IX_sap_VariedadSap_Especie ON sap.VariedadSap(EspecieSapId);
    CREATE INDEX IX_sap_VariedadSap_Grupo   ON sap.VariedadSap(GrupoVariedadSapId);
END
GO

------------------------------------------------------------
-- sap.CalibreSap
------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE object_id = OBJECT_ID(N'sap.CalibreSap'))
BEGIN
    CREATE TABLE sap.CalibreSap (
        CalibreSapId  BIGINT        IDENTITY(1,1) NOT NULL CONSTRAINT PK_sap_CalibreSap PRIMARY KEY,
        VariedadSapId BIGINT        NOT NULL,
        Codigo        NVARCHAR(32)  NOT NULL,
        Tipo          NVARCHAR(20)  NOT NULL,
        Orden         INT           NOT NULL CONSTRAINT DF_sap_CalibreSap_Orden DEFAULT 0,
        Activo        BIT           NOT NULL CONSTRAINT DF_sap_CalibreSap_Activo DEFAULT 1,
        SyncedAt      DATETIME2(0)  NOT NULL CONSTRAINT DF_sap_CalibreSap_SyncedAt DEFAULT SYSUTCDATETIME(),
        CONSTRAINT FK_sap_CalibreSap_Variedad FOREIGN KEY (VariedadSapId) REFERENCES sap.VariedadSap(VariedadSapId),
        CONSTRAINT UQ_sap_CalibreSap_Variedad_Codigo UNIQUE (VariedadSapId, Codigo),
        CONSTRAINT CK_sap_CalibreSap_Tipo CHECK (Tipo IN (N'Grande', N'Mediano', N'Pequeno', N'Otro'))
    );
    CREATE INDEX IX_sap_CalibreSap_Variedad ON sap.CalibreSap(VariedadSapId, Orden);
END
GO

------------------------------------------------------------
-- sap.ProductorSap
------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE object_id = OBJECT_ID(N'sap.ProductorSap'))
BEGIN
    CREATE TABLE sap.ProductorSap (
        ProductorSapId   BIGINT        IDENTITY(1,1) NOT NULL CONSTRAINT PK_sap_ProductorSap PRIMARY KEY,
        CodigoSap        NVARCHAR(32)  NOT NULL CONSTRAINT UQ_sap_ProductorSap_Codigo UNIQUE,
        Rut              NVARCHAR(12)  NULL,
        Dv               NCHAR(1)      NULL,
        Nombre           NVARCHAR(300) NOT NULL,
        Email            NVARCHAR(256) NULL,
        GrupoProductorId INT           NULL,
        CodigoSag        NVARCHAR(32)  NULL,
        Activo           BIT           NOT NULL CONSTRAINT DF_sap_ProductorSap_Activo DEFAULT 1,
        SyncedAt         DATETIME2(0)  NOT NULL CONSTRAINT DF_sap_ProductorSap_SyncedAt DEFAULT SYSUTCDATETIME(),
        CONSTRAINT FK_sap_ProductorSap_Grupo FOREIGN KEY (GrupoProductorId) REFERENCES est.GrupoProductor(GrupoProductorId)
    );
    CREATE INDEX IX_sap_ProductorSap_Grupo ON sap.ProductorSap(GrupoProductorId);
    CREATE INDEX IX_sap_ProductorSap_Rut   ON sap.ProductorSap(Rut);
END
GO

------------------------------------------------------------
-- sap.ProductorVariedadSap
------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE object_id = OBJECT_ID(N'sap.ProductorVariedadSap'))
BEGIN
    CREATE TABLE sap.ProductorVariedadSap (
        ProductorVariedadSapId BIGINT       IDENTITY(1,1) NOT NULL CONSTRAINT PK_sap_ProductorVariedadSap PRIMARY KEY,
        ProductorSapId         BIGINT       NOT NULL,
        VariedadSapId          BIGINT       NOT NULL,
        TemporadaId            INT          NULL,
        EsOgl                  BIT          NOT NULL CONSTRAINT DF_sap_ProductorVariedadSap_EsOgl DEFAULT 0,
        EsWalmart              BIT          NOT NULL CONSTRAINT DF_sap_ProductorVariedadSap_EsWalmart DEFAULT 0,
        EsSystemApproach       BIT          NOT NULL CONSTRAINT DF_sap_ProductorVariedadSap_EsSystemApproach DEFAULT 0,
        Sdp                    NVARCHAR(32) NULL,
        CuartelCodigo          NVARCHAR(64) NULL,
        Activo                 BIT          NOT NULL CONSTRAINT DF_sap_ProductorVariedadSap_Activo DEFAULT 1,
        SyncedAt               DATETIME2(0) NOT NULL CONSTRAINT DF_sap_ProductorVariedadSap_SyncedAt DEFAULT SYSUTCDATETIME(),
        CONSTRAINT FK_sap_ProductorVariedadSap_Productor FOREIGN KEY (ProductorSapId) REFERENCES sap.ProductorSap(ProductorSapId),
        CONSTRAINT FK_sap_ProductorVariedadSap_Variedad  FOREIGN KEY (VariedadSapId)  REFERENCES sap.VariedadSap(VariedadSapId),
        CONSTRAINT FK_sap_ProductorVariedadSap_Temporada FOREIGN KEY (TemporadaId)    REFERENCES est.Temporada(TemporadaId),
        CONSTRAINT UQ_sap_ProductorVariedadSap UNIQUE (ProductorSapId, VariedadSapId, TemporadaId, CuartelCodigo)
    );
    CREATE INDEX IX_sap_ProductorVariedadSap_Productor ON sap.ProductorVariedadSap(ProductorSapId);
    CREATE INDEX IX_sap_ProductorVariedadSap_Variedad  ON sap.ProductorVariedadSap(VariedadSapId);
    CREATE INDEX IX_sap_ProductorVariedadSap_Temporada ON sap.ProductorVariedadSap(TemporadaId);
END
GO

------------------------------------------------------------
-- sap.ProductorVariedadSemanaSap
------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE object_id = OBJECT_ID(N'sap.ProductorVariedadSemanaSap'))
BEGIN
    CREATE TABLE sap.ProductorVariedadSemanaSap (
        ProductorVariedadSemanaSapId BIGINT       IDENTITY(1,1) NOT NULL CONSTRAINT PK_sap_ProductorVariedadSemanaSap PRIMARY KEY,
        ProductorVariedadSapId       BIGINT       NOT NULL,
        TemporadaId                  INT          NOT NULL,
        SemanaInicio                 INT          NOT NULL,
        SemanaFin                    INT          NOT NULL,
        SyncedAt                     DATETIME2(0) NOT NULL CONSTRAINT DF_sap_ProductorVariedadSemanaSap_SyncedAt DEFAULT SYSUTCDATETIME(),
        CONSTRAINT FK_sap_ProductorVariedadSemanaSap_PV        FOREIGN KEY (ProductorVariedadSapId) REFERENCES sap.ProductorVariedadSap(ProductorVariedadSapId),
        CONSTRAINT FK_sap_ProductorVariedadSemanaSap_Temporada FOREIGN KEY (TemporadaId)            REFERENCES est.Temporada(TemporadaId),
        CONSTRAINT CK_sap_ProductorVariedadSemanaSap_Semanas   CHECK (SemanaInicio BETWEEN 1 AND 53 AND SemanaFin BETWEEN 1 AND 53)
    );
    CREATE INDEX IX_sap_ProductorVariedadSemanaSap_PV ON sap.ProductorVariedadSemanaSap(ProductorVariedadSapId, TemporadaId);
END
GO

------------------------------------------------------------
-- Lookups SAP (mismo shape: Codigo + Nombre + Activo + SyncedAt)
------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE object_id = OBJECT_ID(N'sap.EnvaseSap'))
BEGIN
    CREATE TABLE sap.EnvaseSap (
        EnvaseSapId BIGINT        IDENTITY(1,1) NOT NULL CONSTRAINT PK_sap_EnvaseSap PRIMARY KEY,
        CodigoSap   NVARCHAR(32)  NOT NULL CONSTRAINT UQ_sap_EnvaseSap_Codigo UNIQUE,
        Nombre      NVARCHAR(200) NOT NULL,
        Activo      BIT           NOT NULL CONSTRAINT DF_sap_EnvaseSap_Activo DEFAULT 1,
        SyncedAt    DATETIME2(0)  NOT NULL CONSTRAINT DF_sap_EnvaseSap_SyncedAt DEFAULT SYSUTCDATETIME()
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE object_id = OBJECT_ID(N'sap.ManejoSap'))
BEGIN
    CREATE TABLE sap.ManejoSap (
        ManejoSapId BIGINT        IDENTITY(1,1) NOT NULL CONSTRAINT PK_sap_ManejoSap PRIMARY KEY,
        CodigoSap   NVARCHAR(32)  NOT NULL CONSTRAINT UQ_sap_ManejoSap_Codigo UNIQUE,
        Nombre      NVARCHAR(200) NOT NULL,
        Activo      BIT           NOT NULL CONSTRAINT DF_sap_ManejoSap_Activo DEFAULT 1,
        SyncedAt    DATETIME2(0)  NOT NULL CONSTRAINT DF_sap_ManejoSap_SyncedAt DEFAULT SYSUTCDATETIME()
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE object_id = OBJECT_ID(N'sap.CentroSap'))
BEGIN
    CREATE TABLE sap.CentroSap (
        CentroSapId BIGINT        IDENTITY(1,1) NOT NULL CONSTRAINT PK_sap_CentroSap PRIMARY KEY,
        CodigoSap   NVARCHAR(32)  NOT NULL CONSTRAINT UQ_sap_CentroSap_Codigo UNIQUE,
        Nombre      NVARCHAR(200) NOT NULL,
        Activo      BIT           NOT NULL CONSTRAINT DF_sap_CentroSap_Activo DEFAULT 1,
        SyncedAt    DATETIME2(0)  NOT NULL CONSTRAINT DF_sap_CentroSap_SyncedAt DEFAULT SYSUTCDATETIME()
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE object_id = OBJECT_ID(N'sap.TipoFrioSap'))
BEGIN
    CREATE TABLE sap.TipoFrioSap (
        TipoFrioSapId BIGINT        IDENTITY(1,1) NOT NULL CONSTRAINT PK_sap_TipoFrioSap PRIMARY KEY,
        CodigoSap     NVARCHAR(32)  NOT NULL CONSTRAINT UQ_sap_TipoFrioSap_Codigo UNIQUE,
        Nombre        NVARCHAR(200) NOT NULL,
        Activo        BIT           NOT NULL CONSTRAINT DF_sap_TipoFrioSap_Activo DEFAULT 1,
        SyncedAt      DATETIME2(0)  NOT NULL CONSTRAINT DF_sap_TipoFrioSap_SyncedAt DEFAULT SYSUTCDATETIME()
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE object_id = OBJECT_ID(N'sap.ProgramaSap'))
BEGIN
    CREATE TABLE sap.ProgramaSap (
        ProgramaSapId BIGINT        IDENTITY(1,1) NOT NULL CONSTRAINT PK_sap_ProgramaSap PRIMARY KEY,
        CodigoSap     NVARCHAR(32)  NOT NULL CONSTRAINT UQ_sap_ProgramaSap_Codigo UNIQUE,
        Nombre        NVARCHAR(200) NOT NULL,
        Activo        BIT           NOT NULL CONSTRAINT DF_sap_ProgramaSap_Activo DEFAULT 1,
        SyncedAt      DATETIME2(0)  NOT NULL CONSTRAINT DF_sap_ProgramaSap_SyncedAt DEFAULT SYSUTCDATETIME()
    );
END
GO

------------------------------------------------------------
-- sap.SyncLog - historial de ejecuciones de sync
------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE object_id = OBJECT_ID(N'sap.SyncLog'))
BEGIN
    CREATE TABLE sap.SyncLog (
        SyncLogId         BIGINT        IDENTITY(1,1) NOT NULL CONSTRAINT PK_sap_SyncLog PRIMARY KEY,
        Entidad           NVARCHAR(64)  NOT NULL,
        FechaInicio       DATETIME2(0)  NOT NULL CONSTRAINT DF_sap_SyncLog_FechaInicio DEFAULT SYSUTCDATETIME(),
        FechaFin          DATETIME2(0)  NULL,
        Estado            NVARCHAR(16)  NOT NULL CONSTRAINT DF_sap_SyncLog_Estado DEFAULT N'corriendo',
        FilasLeidas       INT           NOT NULL CONSTRAINT DF_sap_SyncLog_FilasLeidas DEFAULT 0,
        FilasInsertadas   INT           NOT NULL CONSTRAINT DF_sap_SyncLog_FilasInsertadas DEFAULT 0,
        FilasActualizadas INT           NOT NULL CONSTRAINT DF_sap_SyncLog_FilasActualizadas DEFAULT 0,
        Error             NVARCHAR(MAX) NULL,
        DisparadoPorUsuarioId BIGINT    NULL,
        Origen            NVARCHAR(16)  NOT NULL CONSTRAINT DF_sap_SyncLog_Origen DEFAULT N'manual',
        CONSTRAINT FK_sap_SyncLog_Usuario FOREIGN KEY (DisparadoPorUsuarioId) REFERENCES est.Usuario(UsuarioId),
        CONSTRAINT CK_sap_SyncLog_Estado CHECK (Estado IN (N'corriendo', N'ok', N'fallo', N'cancelado')),
        CONSTRAINT CK_sap_SyncLog_Origen CHECK (Origen IN (N'manual', N'cron'))
    );
    CREATE INDEX IX_sap_SyncLog_Entidad_Fecha ON sap.SyncLog(Entidad, FechaInicio DESC);
    CREATE INDEX IX_sap_SyncLog_Estado        ON sap.SyncLog(Estado, FechaInicio DESC);
END
GO

------------------------------------------------------------
-- Cerrar FKs pendientes de Fase 2 hacia sap.*
------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_est_UnidadKilos_Variedad')
    ALTER TABLE est.UnidadKilos WITH CHECK
        ADD CONSTRAINT FK_est_UnidadKilos_Variedad
            FOREIGN KEY (VariedadSapId) REFERENCES sap.VariedadSap(VariedadSapId);
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_est_PesoPromedio_Especie')
    ALTER TABLE est.PesoPromedio WITH CHECK
        ADD CONSTRAINT FK_est_PesoPromedio_Especie
            FOREIGN KEY (EspecieSapId) REFERENCES sap.EspecieSap(EspecieSapId);
GO

INSERT INTO meta.Migracion (NombreArchivo)
SELECT N'202604160004__sap.sql'
WHERE NOT EXISTS (SELECT 1 FROM meta.Migracion WHERE NombreArchivo = N'202604160004__sap.sql');
GO

PRINT '202604160004__sap aplicada.';
GO
