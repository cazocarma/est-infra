-- =============================================================================
-- 202604160008__drop_updated_at_triggers.sql
--
-- Elimina los triggers TR_<Tabla>_UpdatedAt creados en las migraciones 0002,
-- 0003, 0005, 0006, 0007. Razon:
--
--   SQL Server (error 334) prohibe "INSERT/MERGE ... OUTPUT inserted.* ..."
--   sin INTO clause cuando la tabla destino tiene triggers habilitados.
--   Esto rompe upsertUsuario (login) y los insert OUTPUT de maestros.
--
-- Convencion: todo UPDATE desde el backend debe incluir explicitamente
--   `UpdatedAt = SYSUTCDATETIME()` como parte del SET. Los triggers ya no
--   sirven de red de seguridad, y su costo (romper OUTPUT) no justifica
--   la comodidad.
--
-- Idempotente.
-- =============================================================================
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @triggers TABLE (nombre SYSNAME);
INSERT INTO @triggers (nombre) VALUES
    (N'est.TR_Usuario_UpdatedAt'),
    (N'est.TR_Temporada_UpdatedAt'),
    (N'est.TR_Planta_UpdatedAt'),
    (N'est.TR_Unidad_UpdatedAt'),
    (N'est.TR_GrupoProductor_UpdatedAt'),
    (N'est.TR_UnidadKilos_UpdatedAt'),
    (N'est.TR_PesoPromedio_UpdatedAt'),
    (N'est.TR_Agronomo_UpdatedAt'),
    (N'est.TR_FechaEstimacionGeneral_UpdatedAt'),
    (N'est.TR_EstimacionControlVersion_UpdatedAt'),
    (N'est.TR_Estimacion_UpdatedAt');

DECLARE @trg SYSNAME, @sql NVARCHAR(300);
DECLARE c CURSOR FAST_FORWARD FOR SELECT nombre FROM @triggers;
OPEN c;
FETCH NEXT FROM c INTO @trg;
WHILE @@FETCH_STATUS = 0
BEGIN
    IF OBJECT_ID(@trg, N'TR') IS NOT NULL
    BEGIN
        SET @sql = N'DROP TRIGGER ' + @trg + N';';
        EXEC sp_executesql @sql;
    END
    FETCH NEXT FROM c INTO @trg;
END
CLOSE c;
DEALLOCATE c;
GO

INSERT INTO meta.Migracion (NombreArchivo)
SELECT N'202604160008__drop_updated_at_triggers.sql'
WHERE NOT EXISTS (SELECT 1 FROM meta.Migracion WHERE NombreArchivo = N'202604160008__drop_updated_at_triggers.sql');
GO

PRINT '202604160008__drop_updated_at_triggers aplicada.';
GO
