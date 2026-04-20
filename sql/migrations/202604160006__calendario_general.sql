-- =============================================================================
-- 202604160006__calendario_general.sql
-- est.FechaEstimacionGeneral: ventanas temporales por temporada + especie
-- en las que se permite crear/editar una estimacion general.
-- Idempotente.
-- =============================================================================
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
SET NOCOUNT ON;
SET XACT_ABORT ON;

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE object_id = OBJECT_ID(N'est.FechaEstimacionGeneral'))
BEGIN
    CREATE TABLE est.FechaEstimacionGeneral (
        FechaEstimacionGeneralId INT          IDENTITY(1,1) NOT NULL CONSTRAINT PK_est_FechaEstimacionGeneral PRIMARY KEY,
        TemporadaId              INT          NOT NULL,
        EspecieSapId             BIGINT       NOT NULL,
        FechaApertura            DATE         NOT NULL,
        FechaCierre              DATE         NOT NULL,
        Activo                   BIT          NOT NULL CONSTRAINT DF_est_FechaEstimacionGeneral_Activo DEFAULT 1,
        CreatedAt                DATETIME2(0) NOT NULL CONSTRAINT DF_est_FechaEstimacionGeneral_CreatedAt DEFAULT SYSUTCDATETIME(),
        UpdatedAt                DATETIME2(0) NOT NULL CONSTRAINT DF_est_FechaEstimacionGeneral_UpdatedAt DEFAULT SYSUTCDATETIME(),
        CreatedBy                BIGINT       NULL,
        UpdatedBy                BIGINT       NULL,
        CONSTRAINT FK_est_FEG_Temporada FOREIGN KEY (TemporadaId)  REFERENCES est.Temporada(TemporadaId),
        CONSTRAINT FK_est_FEG_Especie   FOREIGN KEY (EspecieSapId) REFERENCES sap.EspecieSap(EspecieSapId),
        CONSTRAINT FK_est_FEG_Created   FOREIGN KEY (CreatedBy)    REFERENCES est.Usuario(UsuarioId),
        CONSTRAINT FK_est_FEG_Updated   FOREIGN KEY (UpdatedBy)    REFERENCES est.Usuario(UsuarioId),
        CONSTRAINT UQ_est_FEG_Temporada_Especie UNIQUE (TemporadaId, EspecieSapId),
        CONSTRAINT CK_est_FEG_Fechas CHECK (FechaCierre >= FechaApertura)
    );
    CREATE INDEX IX_est_FEG_Temporada ON est.FechaEstimacionGeneral(TemporadaId);
    CREATE INDEX IX_est_FEG_Especie   ON est.FechaEstimacionGeneral(EspecieSapId);
END
GO

-- Nota: sin trigger UpdatedAt - los UPDATE del backend lo setean explicitamente.

------------------------------------------------------------
-- Helper: verificar si la ventana esta abierta para (temporada, especie)
-- en una fecha concreta (default: hoy UTC).
------------------------------------------------------------
IF OBJECT_ID(N'est.fn_VentanaGeneralAbierta', N'FN') IS NULL
    EXEC(N'
    CREATE FUNCTION est.fn_VentanaGeneralAbierta (
        @TemporadaId  INT,
        @EspecieSapId BIGINT,
        @Fecha        DATE
    )
    RETURNS BIT
    AS
    BEGIN
        DECLARE @abierta BIT = 0;
        DECLARE @f DATE = COALESCE(@Fecha, CAST(SYSUTCDATETIME() AS DATE));
        IF EXISTS (
            SELECT 1 FROM est.FechaEstimacionGeneral
            WHERE TemporadaId  = @TemporadaId
              AND EspecieSapId = @EspecieSapId
              AND Activo = 1
              AND @f BETWEEN FechaApertura AND FechaCierre
        ) SET @abierta = 1;
        RETURN @abierta;
    END');
GO

INSERT INTO meta.Migracion (NombreArchivo)
SELECT N'202604160006__calendario_general.sql'
WHERE NOT EXISTS (SELECT 1 FROM meta.Migracion WHERE NombreArchivo = N'202604160006__calendario_general.sql');
GO

PRINT '202604160006__calendario_general aplicada.';
GO
