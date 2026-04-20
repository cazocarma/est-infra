-- =============================================================================
-- 202604160007__estimacion_general.sql
-- Estimacion General con control de version (snapshots).
-- Tablas vivas bajo schema `est` + tablas *Version para snapshots inmutables.
-- Idempotente.
-- =============================================================================
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
SET NOCOUNT ON;
SET XACT_ABORT ON;

------------------------------------------------------------
-- est.EstimacionControlVersion
-- Ciclo de vida de las versiones por temporada+especie.
------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE object_id = OBJECT_ID(N'est.EstimacionControlVersion'))
BEGIN
    CREATE TABLE est.EstimacionControlVersion (
        EstimacionControlVersionId INT          IDENTITY(1,1) NOT NULL CONSTRAINT PK_est_EstimacionControlVersion PRIMARY KEY,
        TemporadaId                INT          NOT NULL,
        EspecieSapId               BIGINT       NOT NULL,
        NumeroVersion              INT          NOT NULL,
        Estado                     NVARCHAR(16) NOT NULL CONSTRAINT DF_est_ECV_Estado DEFAULT N'Abierta',
        FechaApertura              DATETIME2(0) NOT NULL CONSTRAINT DF_est_ECV_FechaApertura DEFAULT SYSUTCDATETIME(),
        FechaCierre                DATETIME2(0) NULL,
        Comentario                 NVARCHAR(500) NULL,
        CreatedBy                  BIGINT       NULL,
        UpdatedBy                  BIGINT       NULL,
        CreatedAt                  DATETIME2(0) NOT NULL CONSTRAINT DF_est_ECV_CreatedAt DEFAULT SYSUTCDATETIME(),
        UpdatedAt                  DATETIME2(0) NOT NULL CONSTRAINT DF_est_ECV_UpdatedAt DEFAULT SYSUTCDATETIME(),
        CONSTRAINT FK_est_ECV_Temporada FOREIGN KEY (TemporadaId)  REFERENCES est.Temporada(TemporadaId),
        CONSTRAINT FK_est_ECV_Especie   FOREIGN KEY (EspecieSapId) REFERENCES sap.EspecieSap(EspecieSapId),
        CONSTRAINT FK_est_ECV_Created   FOREIGN KEY (CreatedBy)    REFERENCES est.Usuario(UsuarioId),
        CONSTRAINT FK_est_ECV_Updated   FOREIGN KEY (UpdatedBy)    REFERENCES est.Usuario(UsuarioId),
        CONSTRAINT UQ_est_ECV_Temporada_Especie_Version UNIQUE (TemporadaId, EspecieSapId, NumeroVersion),
        CONSTRAINT CK_est_ECV_Estado CHECK (Estado IN (N'Abierta', N'Cerrada', N'Anulada'))
    );
    -- Solo una version 'Abierta' por (temporada, especie)
    CREATE UNIQUE INDEX UX_est_ECV_Abierta
        ON est.EstimacionControlVersion(TemporadaId, EspecieSapId)
        WHERE Estado = N'Abierta';
END
GO

------------------------------------------------------------
-- est.Estimacion (tabla viva)
-- Una por combinacion (ControlVersion, ProductorVariedadSap, Manejo).
------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE object_id = OBJECT_ID(N'est.Estimacion'))
BEGIN
    CREATE TABLE est.Estimacion (
        EstimacionId               BIGINT       IDENTITY(1,1) NOT NULL CONSTRAINT PK_est_Estimacion PRIMARY KEY,
        EstimacionControlVersionId INT          NOT NULL,
        AgronomoId                 INT          NOT NULL,
        ProductorVariedadSapId     BIGINT       NOT NULL,
        ManejoSapId                BIGINT       NULL,
        Folio                      NVARCHAR(32) NULL,
        CreatedAt                  DATETIME2(0) NOT NULL CONSTRAINT DF_est_Estimacion_CreatedAt DEFAULT SYSUTCDATETIME(),
        UpdatedAt                  DATETIME2(0) NOT NULL CONSTRAINT DF_est_Estimacion_UpdatedAt DEFAULT SYSUTCDATETIME(),
        CreatedBy                  BIGINT       NULL,
        UpdatedBy                  BIGINT       NULL,
        CONSTRAINT FK_est_Estimacion_ControlVersion FOREIGN KEY (EstimacionControlVersionId) REFERENCES est.EstimacionControlVersion(EstimacionControlVersionId),
        CONSTRAINT FK_est_Estimacion_Agronomo       FOREIGN KEY (AgronomoId)                 REFERENCES est.Agronomo(AgronomoId),
        CONSTRAINT FK_est_Estimacion_PV             FOREIGN KEY (ProductorVariedadSapId)     REFERENCES sap.ProductorVariedadSap(ProductorVariedadSapId),
        CONSTRAINT FK_est_Estimacion_Manejo         FOREIGN KEY (ManejoSapId)                REFERENCES sap.ManejoSap(ManejoSapId),
        CONSTRAINT FK_est_Estimacion_Created        FOREIGN KEY (CreatedBy)                  REFERENCES est.Usuario(UsuarioId),
        CONSTRAINT FK_est_Estimacion_Updated        FOREIGN KEY (UpdatedBy)                  REFERENCES est.Usuario(UsuarioId),
        CONSTRAINT UQ_est_Estimacion UNIQUE (EstimacionControlVersionId, ProductorVariedadSapId, ManejoSapId)
    );
    CREATE INDEX IX_est_Estimacion_Agronomo ON est.Estimacion(AgronomoId);
    CREATE INDEX IX_est_Estimacion_PV       ON est.Estimacion(ProductorVariedadSapId);
END
GO

------------------------------------------------------------
-- est.EstimacionVolumen (volumen total por estimacion)
------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE object_id = OBJECT_ID(N'est.EstimacionVolumen'))
BEGIN
    CREATE TABLE est.EstimacionVolumen (
        EstimacionVolumenId    BIGINT        IDENTITY(1,1) NOT NULL CONSTRAINT PK_est_EstimacionVolumen PRIMARY KEY,
        EstimacionId           BIGINT        NOT NULL,
        UnidadId               INT           NOT NULL,
        Kilos                  DECIMAL(14,2) NOT NULL,
        PorcentajeExportacion  DECIMAL(9,4)  NOT NULL CONSTRAINT DF_est_EstimacionVolumen_PctExp DEFAULT 0,
        CajasEquivalentes      DECIMAL(14,4) NOT NULL CONSTRAINT DF_est_EstimacionVolumen_Cajas  DEFAULT 0,
        CreatedAt              DATETIME2(0)  NOT NULL CONSTRAINT DF_est_EstimacionVolumen_CreatedAt DEFAULT SYSUTCDATETIME(),
        UpdatedAt              DATETIME2(0)  NOT NULL CONSTRAINT DF_est_EstimacionVolumen_UpdatedAt DEFAULT SYSUTCDATETIME(),
        CONSTRAINT FK_est_EstimacionVolumen_Est    FOREIGN KEY (EstimacionId) REFERENCES est.Estimacion(EstimacionId) ON DELETE CASCADE,
        CONSTRAINT FK_est_EstimacionVolumen_Unidad FOREIGN KEY (UnidadId)     REFERENCES est.Unidad(UnidadId),
        CONSTRAINT UQ_est_EstimacionVolumen_Est UNIQUE (EstimacionId),
        CONSTRAINT CK_est_EstimacionVolumen_Kilos CHECK (Kilos >= 0 AND PorcentajeExportacion BETWEEN 0 AND 100)
    );
END
GO

------------------------------------------------------------
-- est.EstimacionVolumenSemana (kg por semana, 1..53)
------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE object_id = OBJECT_ID(N'est.EstimacionVolumenSemana'))
BEGIN
    CREATE TABLE est.EstimacionVolumenSemana (
        EstimacionVolumenSemanaId BIGINT        IDENTITY(1,1) NOT NULL CONSTRAINT PK_est_EstimacionVolumenSemana PRIMARY KEY,
        EstimacionId              BIGINT        NOT NULL,
        Semana                    INT           NOT NULL,
        Kilos                     DECIMAL(14,2) NOT NULL,
        CONSTRAINT FK_est_EstimacionVolumenSemana_Est FOREIGN KEY (EstimacionId) REFERENCES est.Estimacion(EstimacionId) ON DELETE CASCADE,
        CONSTRAINT UQ_est_EstimacionVolumenSemana_Est_Sem UNIQUE (EstimacionId, Semana),
        CONSTRAINT CK_est_EstimacionVolumenSemana_Semana CHECK (Semana BETWEEN 1 AND 53),
        CONSTRAINT CK_est_EstimacionVolumenSemana_Kilos  CHECK (Kilos >= 0)
    );
    CREATE INDEX IX_est_EstimacionVolumenSemana_Est ON est.EstimacionVolumenSemana(EstimacionId);
END
GO

------------------------------------------------------------
-- est.EstimacionCalibre (% por calibre)
------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE object_id = OBJECT_ID(N'est.EstimacionCalibre'))
BEGIN
    CREATE TABLE est.EstimacionCalibre (
        EstimacionCalibreId BIGINT       IDENTITY(1,1) NOT NULL CONSTRAINT PK_est_EstimacionCalibre PRIMARY KEY,
        EstimacionId        BIGINT       NOT NULL,
        CalibreSapId        BIGINT       NOT NULL,
        Porcentaje          DECIMAL(9,4) NOT NULL,
        CONSTRAINT FK_est_EstimacionCalibre_Est     FOREIGN KEY (EstimacionId) REFERENCES est.Estimacion(EstimacionId) ON DELETE CASCADE,
        CONSTRAINT FK_est_EstimacionCalibre_Calibre FOREIGN KEY (CalibreSapId) REFERENCES sap.CalibreSap(CalibreSapId),
        CONSTRAINT UQ_est_EstimacionCalibre UNIQUE (EstimacionId, CalibreSapId),
        CONSTRAINT CK_est_EstimacionCalibre_Porcentaje CHECK (Porcentaje BETWEEN 0 AND 100)
    );
END
GO

------------------------------------------------------------
-- est.EspecieTipificacion (categoria de tipificacion por especie)
------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE object_id = OBJECT_ID(N'est.EspecieTipificacion'))
BEGIN
    CREATE TABLE est.EspecieTipificacion (
        EspecieTipificacionId INT          IDENTITY(1,1) NOT NULL CONSTRAINT PK_est_EspecieTipificacion PRIMARY KEY,
        EspecieSapId          BIGINT       NOT NULL,
        Codigo                NVARCHAR(32) NOT NULL,
        Nombre                NVARCHAR(120) NOT NULL,
        Orden                 INT          NOT NULL CONSTRAINT DF_est_EspecieTipificacion_Orden DEFAULT 0,
        Activo                BIT          NOT NULL CONSTRAINT DF_est_EspecieTipificacion_Activo DEFAULT 1,
        CreatedAt             DATETIME2(0) NOT NULL CONSTRAINT DF_est_EspecieTipificacion_CreatedAt DEFAULT SYSUTCDATETIME(),
        UpdatedAt             DATETIME2(0) NOT NULL CONSTRAINT DF_est_EspecieTipificacion_UpdatedAt DEFAULT SYSUTCDATETIME(),
        CONSTRAINT FK_est_EspecieTipificacion_Especie FOREIGN KEY (EspecieSapId) REFERENCES sap.EspecieSap(EspecieSapId),
        CONSTRAINT UQ_est_EspecieTipificacion UNIQUE (EspecieSapId, Codigo)
    );
END
GO

------------------------------------------------------------
-- est.EstimacionTipificacion (valor por tipificacion)
------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE object_id = OBJECT_ID(N'est.EstimacionTipificacion'))
BEGIN
    CREATE TABLE est.EstimacionTipificacion (
        EstimacionTipificacionId BIGINT        IDENTITY(1,1) NOT NULL CONSTRAINT PK_est_EstimacionTipificacion PRIMARY KEY,
        EstimacionId             BIGINT        NOT NULL,
        EspecieTipificacionId    INT           NOT NULL,
        Valor                    DECIMAL(14,4) NOT NULL,
        CONSTRAINT FK_est_EstimacionTipificacion_Est FOREIGN KEY (EstimacionId)          REFERENCES est.Estimacion(EstimacionId) ON DELETE CASCADE,
        CONSTRAINT FK_est_EstimacionTipificacion_Tip FOREIGN KEY (EspecieTipificacionId) REFERENCES est.EspecieTipificacion(EspecieTipificacionId),
        CONSTRAINT UQ_est_EstimacionTipificacion UNIQUE (EstimacionId, EspecieTipificacionId)
    );
END
GO

------------------------------------------------------------
-- Tablas *Version (snapshots inmutables)
------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE object_id = OBJECT_ID(N'est.EstimacionVersion'))
BEGIN
    CREATE TABLE est.EstimacionVersion (
        EstimacionVersionId        BIGINT       IDENTITY(1,1) NOT NULL CONSTRAINT PK_est_EstimacionVersion PRIMARY KEY,
        EstimacionControlVersionId INT          NOT NULL,
        NumeroVersion              INT          NOT NULL,
        EstimacionId               BIGINT       NOT NULL,
        AgronomoId                 INT          NOT NULL,
        ProductorVariedadSapId     BIGINT       NOT NULL,
        ManejoSapId                BIGINT       NULL,
        Folio                      NVARCHAR(32) NULL,
        FechaSnapshot              DATETIME2(0) NOT NULL CONSTRAINT DF_est_EstimacionVersion_FechaSnapshot DEFAULT SYSUTCDATETIME()
    );
    CREATE INDEX IX_est_EstimacionVersion_ControlVersion ON est.EstimacionVersion(EstimacionControlVersionId, NumeroVersion);
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE object_id = OBJECT_ID(N'est.EstimacionVolumenVersion'))
BEGIN
    CREATE TABLE est.EstimacionVolumenVersion (
        EstimacionVolumenVersionId BIGINT        IDENTITY(1,1) NOT NULL CONSTRAINT PK_est_EstimacionVolumenVersion PRIMARY KEY,
        EstimacionControlVersionId INT           NOT NULL,
        NumeroVersion              INT           NOT NULL,
        EstimacionId               BIGINT        NOT NULL,
        UnidadId                   INT           NOT NULL,
        Kilos                      DECIMAL(14,2) NOT NULL,
        PorcentajeExportacion      DECIMAL(9,4)  NOT NULL,
        CajasEquivalentes          DECIMAL(14,4) NOT NULL,
        FechaSnapshot              DATETIME2(0)  NOT NULL CONSTRAINT DF_est_EstimacionVolumenVersion_FechaSnapshot DEFAULT SYSUTCDATETIME()
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE object_id = OBJECT_ID(N'est.EstimacionVolumenSemanaVersion'))
BEGIN
    CREATE TABLE est.EstimacionVolumenSemanaVersion (
        EstimacionVolumenSemanaVersionId BIGINT        IDENTITY(1,1) NOT NULL CONSTRAINT PK_est_EstimacionVolumenSemanaVersion PRIMARY KEY,
        EstimacionControlVersionId       INT           NOT NULL,
        NumeroVersion                    INT           NOT NULL,
        EstimacionId                     BIGINT        NOT NULL,
        Semana                           INT           NOT NULL,
        Kilos                            DECIMAL(14,2) NOT NULL,
        FechaSnapshot                    DATETIME2(0)  NOT NULL CONSTRAINT DF_est_EstimacionVolumenSemanaVersion_FechaSnapshot DEFAULT SYSUTCDATETIME()
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE object_id = OBJECT_ID(N'est.EstimacionCalibreVersion'))
BEGIN
    CREATE TABLE est.EstimacionCalibreVersion (
        EstimacionCalibreVersionId BIGINT       IDENTITY(1,1) NOT NULL CONSTRAINT PK_est_EstimacionCalibreVersion PRIMARY KEY,
        EstimacionControlVersionId INT          NOT NULL,
        NumeroVersion              INT          NOT NULL,
        EstimacionId               BIGINT       NOT NULL,
        CalibreSapId               BIGINT       NOT NULL,
        Porcentaje                 DECIMAL(9,4) NOT NULL,
        FechaSnapshot              DATETIME2(0) NOT NULL CONSTRAINT DF_est_EstimacionCalibreVersion_FechaSnapshot DEFAULT SYSUTCDATETIME()
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE object_id = OBJECT_ID(N'est.EstimacionTipificacionVersion'))
BEGIN
    CREATE TABLE est.EstimacionTipificacionVersion (
        EstimacionTipificacionVersionId BIGINT        IDENTITY(1,1) NOT NULL CONSTRAINT PK_est_EstimacionTipificacionVersion PRIMARY KEY,
        EstimacionControlVersionId      INT           NOT NULL,
        NumeroVersion                   INT           NOT NULL,
        EstimacionId                    BIGINT        NOT NULL,
        EspecieTipificacionId           INT           NOT NULL,
        Valor                           DECIMAL(14,4) NOT NULL,
        FechaSnapshot                   DATETIME2(0)  NOT NULL CONSTRAINT DF_est_EstimacionTipificacionVersion_FechaSnapshot DEFAULT SYSUTCDATETIME()
    );
END
GO

------------------------------------------------------------
-- Stored proc: sp_CerrarControlVersion
-- Snapshotea todo lo vivo a las tablas *Version y abre una nueva version.
------------------------------------------------------------
IF OBJECT_ID(N'est.sp_CerrarControlVersion', N'P') IS NOT NULL
    DROP PROCEDURE est.sp_CerrarControlVersion;
GO
CREATE PROCEDURE est.sp_CerrarControlVersion
    @ControlVersionId INT,
    @UsuarioId        BIGINT,
    @Comentario       NVARCHAR(500) = NULL,
    @NuevaVersionId   INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRANSACTION;
    BEGIN TRY
        DECLARE @TemporadaId  INT, @EspecieSapId BIGINT, @NumeroVersion INT, @Estado NVARCHAR(16);
        SELECT @TemporadaId = TemporadaId, @EspecieSapId = EspecieSapId,
               @NumeroVersion = NumeroVersion, @Estado = Estado
        FROM est.EstimacionControlVersion WHERE EstimacionControlVersionId = @ControlVersionId;

        IF @TemporadaId IS NULL
            THROW 50001, N'ControlVersion no existe', 1;
        IF @Estado <> N'Abierta'
            THROW 50002, N'Solo se puede cerrar una version Abierta', 1;

        -- 1) Snapshot de las estimaciones vivas asociadas a esta version
        INSERT INTO est.EstimacionVersion
            (EstimacionControlVersionId, NumeroVersion, EstimacionId, AgronomoId,
             ProductorVariedadSapId, ManejoSapId, Folio)
        SELECT @ControlVersionId, @NumeroVersion, EstimacionId, AgronomoId,
               ProductorVariedadSapId, ManejoSapId, Folio
        FROM est.Estimacion WHERE EstimacionControlVersionId = @ControlVersionId;

        INSERT INTO est.EstimacionVolumenVersion
            (EstimacionControlVersionId, NumeroVersion, EstimacionId, UnidadId, Kilos,
             PorcentajeExportacion, CajasEquivalentes)
        SELECT @ControlVersionId, @NumeroVersion, v.EstimacionId, v.UnidadId, v.Kilos,
               v.PorcentajeExportacion, v.CajasEquivalentes
        FROM est.EstimacionVolumen v
        INNER JOIN est.Estimacion e ON e.EstimacionId = v.EstimacionId
        WHERE e.EstimacionControlVersionId = @ControlVersionId;

        INSERT INTO est.EstimacionVolumenSemanaVersion
            (EstimacionControlVersionId, NumeroVersion, EstimacionId, Semana, Kilos)
        SELECT @ControlVersionId, @NumeroVersion, s.EstimacionId, s.Semana, s.Kilos
        FROM est.EstimacionVolumenSemana s
        INNER JOIN est.Estimacion e ON e.EstimacionId = s.EstimacionId
        WHERE e.EstimacionControlVersionId = @ControlVersionId;

        INSERT INTO est.EstimacionCalibreVersion
            (EstimacionControlVersionId, NumeroVersion, EstimacionId, CalibreSapId, Porcentaje)
        SELECT @ControlVersionId, @NumeroVersion, c.EstimacionId, c.CalibreSapId, c.Porcentaje
        FROM est.EstimacionCalibre c
        INNER JOIN est.Estimacion e ON e.EstimacionId = c.EstimacionId
        WHERE e.EstimacionControlVersionId = @ControlVersionId;

        INSERT INTO est.EstimacionTipificacionVersion
            (EstimacionControlVersionId, NumeroVersion, EstimacionId, EspecieTipificacionId, Valor)
        SELECT @ControlVersionId, @NumeroVersion, t.EstimacionId, t.EspecieTipificacionId, t.Valor
        FROM est.EstimacionTipificacion t
        INNER JOIN est.Estimacion e ON e.EstimacionId = t.EstimacionId
        WHERE e.EstimacionControlVersionId = @ControlVersionId;

        -- 2) Marcar la version actual como cerrada
        UPDATE est.EstimacionControlVersion
        SET Estado = N'Cerrada', FechaCierre = SYSUTCDATETIME(),
            UpdatedAt = SYSUTCDATETIME(), UpdatedBy = @UsuarioId,
            Comentario = COALESCE(@Comentario, Comentario)
        WHERE EstimacionControlVersionId = @ControlVersionId;

        -- 3) Abrir una nueva version (NumeroVersion + 1)
        INSERT INTO est.EstimacionControlVersion
            (TemporadaId, EspecieSapId, NumeroVersion, Estado, FechaApertura, CreatedBy, UpdatedBy)
        VALUES (@TemporadaId, @EspecieSapId, @NumeroVersion + 1, N'Abierta',
                SYSUTCDATETIME(), @UsuarioId, @UsuarioId);

        SET @NuevaVersionId = SCOPE_IDENTITY();

        -- 4) Re-apuntar las estimaciones vivas al nuevo ControlVersionId
        UPDATE est.Estimacion
        SET EstimacionControlVersionId = @NuevaVersionId,
            UpdatedAt = SYSUTCDATETIME(), UpdatedBy = @UsuarioId
        WHERE EstimacionControlVersionId = @ControlVersionId;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

-- Nota: sin triggers UpdatedAt - los UPDATE del backend lo setean explicitamente.

INSERT INTO meta.Migracion (NombreArchivo)
SELECT N'202604160007__estimacion_general.sql'
WHERE NOT EXISTS (SELECT 1 FROM meta.Migracion WHERE NombreArchivo = N'202604160007__estimacion_general.sql');
GO

PRINT '202604160007__estimacion_general aplicada.';
GO
