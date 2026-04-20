-- =============================================================================
-- 202604160005__agronomos.sql
-- Agronomos y asignaciones productor-variedad. Todo bajo schema `est`.
-- Idempotente.
-- =============================================================================
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
SET NOCOUNT ON;
SET XACT_ABORT ON;

------------------------------------------------------------
-- est.Agronomo
-- Promueve un Usuario autenticado a agronomo. 1-a-1 con Usuario.
------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE object_id = OBJECT_ID(N'est.Agronomo'))
BEGIN
    CREATE TABLE est.Agronomo (
        AgronomoId INT          IDENTITY(1,1) NOT NULL CONSTRAINT PK_est_Agronomo PRIMARY KEY,
        UsuarioId  BIGINT       NOT NULL CONSTRAINT UQ_est_Agronomo_Usuario UNIQUE,
        PlantaId   INT          NULL,
        Activo     BIT          NOT NULL CONSTRAINT DF_est_Agronomo_Activo    DEFAULT 1,
        CreatedAt  DATETIME2(0) NOT NULL CONSTRAINT DF_est_Agronomo_CreatedAt DEFAULT SYSUTCDATETIME(),
        UpdatedAt  DATETIME2(0) NOT NULL CONSTRAINT DF_est_Agronomo_UpdatedAt DEFAULT SYSUTCDATETIME(),
        CreatedBy  BIGINT       NULL,
        UpdatedBy  BIGINT       NULL,
        CONSTRAINT FK_est_Agronomo_Usuario FOREIGN KEY (UsuarioId) REFERENCES est.Usuario(UsuarioId),
        CONSTRAINT FK_est_Agronomo_Planta  FOREIGN KEY (PlantaId)  REFERENCES est.Planta(PlantaId),
        CONSTRAINT FK_est_Agronomo_Created FOREIGN KEY (CreatedBy) REFERENCES est.Usuario(UsuarioId),
        CONSTRAINT FK_est_Agronomo_Updated FOREIGN KEY (UpdatedBy) REFERENCES est.Usuario(UsuarioId)
    );
    CREATE INDEX IX_est_Agronomo_Planta ON est.Agronomo(PlantaId);
END
GO

------------------------------------------------------------
-- est.AgronomoProductorVariedad
-- Pivot de asignacion: un agronomo es responsable de una combinacion
-- productor-variedad para una temporada concreta.
------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE object_id = OBJECT_ID(N'est.AgronomoProductorVariedad'))
BEGIN
    CREATE TABLE est.AgronomoProductorVariedad (
        AgronomoProductorVariedadId BIGINT       IDENTITY(1,1) NOT NULL CONSTRAINT PK_est_AgronomoProductorVariedad PRIMARY KEY,
        AgronomoId                  INT          NOT NULL,
        ProductorVariedadSapId      BIGINT       NOT NULL,
        TemporadaId                 INT          NOT NULL,
        CreatedAt                   DATETIME2(0) NOT NULL CONSTRAINT DF_est_AgronomoProductorVariedad_CreatedAt DEFAULT SYSUTCDATETIME(),
        CreatedBy                   BIGINT       NULL,
        CONSTRAINT FK_est_APV_Agronomo  FOREIGN KEY (AgronomoId)             REFERENCES est.Agronomo(AgronomoId),
        CONSTRAINT FK_est_APV_PV        FOREIGN KEY (ProductorVariedadSapId) REFERENCES sap.ProductorVariedadSap(ProductorVariedadSapId),
        CONSTRAINT FK_est_APV_Temporada FOREIGN KEY (TemporadaId)            REFERENCES est.Temporada(TemporadaId),
        CONSTRAINT FK_est_APV_Created   FOREIGN KEY (CreatedBy)              REFERENCES est.Usuario(UsuarioId),
        CONSTRAINT UQ_est_APV_Asignacion UNIQUE (AgronomoId, ProductorVariedadSapId, TemporadaId)
    );
    CREATE INDEX IX_est_APV_Agronomo_Temporada  ON est.AgronomoProductorVariedad(AgronomoId, TemporadaId);
    CREATE INDEX IX_est_APV_PV_Temporada        ON est.AgronomoProductorVariedad(ProductorVariedadSapId, TemporadaId);
END
GO

-- Nota: sin trigger UpdatedAt - los UPDATE del backend lo setean explicitamente.

INSERT INTO meta.Migracion (NombreArchivo)
SELECT N'202604160005__agronomos.sql'
WHERE NOT EXISTS (SELECT 1 FROM meta.Migracion WHERE NombreArchivo = N'202604160005__agronomos.sql');
GO

PRINT '202604160005__agronomos aplicada.';
GO
