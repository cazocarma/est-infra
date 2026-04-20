-- =============================================================================
-- 00_drop_all.sql -- DESTRUCTIVO
-- Elimina TODOS los objetos y datos de los schemas propios del sistema EST:
--   est   -> dominio de aplicacion (auth, maestros, estimaciones, BI, carga, ...)
--   sap   -> espejo de maestros SAP
--   meta  -> tracking de migraciones
--
-- NO TOCA otros schemas del servidor (dbo, etc.) ni otras BDs.
-- Es idempotente: se puede correr varias veces.
--
-- Uso: make db-drop-all  (o  sqlcmd -i sql/00_drop_all.sql)
-- =============================================================================
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @sql NVARCHAR(MAX);
DECLARE @schemas TABLE (name SYSNAME);
INSERT INTO @schemas (name) VALUES (N'est'), (N'sap'), (N'meta');

PRINT N'=== DROP ALL -- schemas objetivo: est, sap, meta ===';

------------------------------------------------------------
-- 1. Drop de FKs (primero para soltar dependencias)
------------------------------------------------------------
PRINT N'--> dropping FOREIGN KEYs...';
SET @sql = N'';
SELECT @sql = @sql + N'ALTER TABLE [' + s.name + N'].[' + t.name + N'] DROP CONSTRAINT [' + fk.name + N'];' + CHAR(10)
FROM sys.foreign_keys fk
INNER JOIN sys.tables t  ON fk.parent_object_id = t.object_id
INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
WHERE s.name IN (SELECT name FROM @schemas);
IF LEN(@sql) > 0 EXEC sp_executesql @sql;

-- Tambien las FKs que apuntan DESDE dbo (u otros) HACIA nuestros schemas deben caer,
-- pero no deberian existir si respetamos la convencion. Si existieran, SQL Server
-- impedira el DROP TABLE mas abajo y abortara con mensaje claro.

------------------------------------------------------------
-- 2. Drop de check / default constraints
------------------------------------------------------------
PRINT N'--> dropping CHECK / DEFAULT constraints...';
SET @sql = N'';
SELECT @sql = @sql + N'ALTER TABLE [' + s.name + N'].[' + t.name + N'] DROP CONSTRAINT [' + c.name + N'];' + CHAR(10)
FROM sys.check_constraints c
INNER JOIN sys.tables t  ON c.parent_object_id = t.object_id
INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
WHERE s.name IN (SELECT name FROM @schemas);

SELECT @sql = @sql + N'ALTER TABLE [' + s.name + N'].[' + t.name + N'] DROP CONSTRAINT [' + d.name + N'];' + CHAR(10)
FROM sys.default_constraints d
INNER JOIN sys.tables t  ON d.parent_object_id = t.object_id
INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
WHERE s.name IN (SELECT name FROM @schemas);
IF LEN(@sql) > 0 EXEC sp_executesql @sql;

------------------------------------------------------------
-- 3. Drop de triggers (de tabla)
------------------------------------------------------------
PRINT N'--> dropping TRIGGERs...';
SET @sql = N'';
SELECT @sql = @sql + N'DROP TRIGGER [' + s.name + N'].[' + tr.name + N'];' + CHAR(10)
FROM sys.triggers tr
INNER JOIN sys.tables t  ON tr.parent_id = t.object_id
INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
WHERE s.name IN (SELECT name FROM @schemas)
  AND tr.is_ms_shipped = 0;
IF LEN(@sql) > 0 EXEC sp_executesql @sql;

------------------------------------------------------------
-- 4. Drop de views
------------------------------------------------------------
PRINT N'--> dropping VIEWs...';
SET @sql = N'';
SELECT @sql = @sql + N'DROP VIEW [' + s.name + N'].[' + v.name + N'];' + CHAR(10)
FROM sys.views v
INNER JOIN sys.schemas s ON v.schema_id = s.schema_id
WHERE s.name IN (SELECT name FROM @schemas);
IF LEN(@sql) > 0 EXEC sp_executesql @sql;

------------------------------------------------------------
-- 5. Drop de stored procs
------------------------------------------------------------
PRINT N'--> dropping PROCEDUREs...';
SET @sql = N'';
SELECT @sql = @sql + N'DROP PROCEDURE [' + s.name + N'].[' + p.name + N'];' + CHAR(10)
FROM sys.procedures p
INNER JOIN sys.schemas s ON p.schema_id = s.schema_id
WHERE s.name IN (SELECT name FROM @schemas);
IF LEN(@sql) > 0 EXEC sp_executesql @sql;

------------------------------------------------------------
-- 6. Drop de funciones (escalar, tabla, inline)
------------------------------------------------------------
PRINT N'--> dropping FUNCTIONs...';
SET @sql = N'';
SELECT @sql = @sql + N'DROP FUNCTION [' + s.name + N'].[' + o.name + N'];' + CHAR(10)
FROM sys.objects o
INNER JOIN sys.schemas s ON o.schema_id = s.schema_id
WHERE s.name IN (SELECT name FROM @schemas)
  AND o.type IN ('FN', 'IF', 'TF', 'FS', 'FT');
IF LEN(@sql) > 0 EXEC sp_executesql @sql;

------------------------------------------------------------
-- 7. Drop de tablas (borra todos los datos)
------------------------------------------------------------
PRINT N'--> dropping TABLEs (y todos sus datos)...';
SET @sql = N'';
SELECT @sql = @sql + N'DROP TABLE [' + s.name + N'].[' + t.name + N'];' + CHAR(10)
FROM sys.tables t
INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
WHERE s.name IN (SELECT name FROM @schemas);
IF LEN(@sql) > 0 EXEC sp_executesql @sql;

------------------------------------------------------------
-- 8. Drop de tipos definidos por usuario (si los hubiera)
------------------------------------------------------------
PRINT N'--> dropping TYPEs...';
SET @sql = N'';
SELECT @sql = @sql + N'DROP TYPE [' + s.name + N'].[' + t.name + N'];' + CHAR(10)
FROM sys.types t
INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
WHERE s.name IN (SELECT name FROM @schemas)
  AND t.is_user_defined = 1;
IF LEN(@sql) > 0 EXEC sp_executesql @sql;

------------------------------------------------------------
-- 9. Drop de secuencias (si las hubiera)
------------------------------------------------------------
PRINT N'--> dropping SEQUENCEs...';
SET @sql = N'';
SELECT @sql = @sql + N'DROP SEQUENCE [' + s.name + N'].[' + seq.name + N'];' + CHAR(10)
FROM sys.sequences seq
INNER JOIN sys.schemas s ON seq.schema_id = s.schema_id
WHERE s.name IN (SELECT name FROM @schemas);
IF LEN(@sql) > 0 EXEC sp_executesql @sql;

------------------------------------------------------------
-- 10. Drop de los schemas mismos
------------------------------------------------------------
PRINT N'--> dropping SCHEMAs...';
IF EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'est')  EXEC(N'DROP SCHEMA [est]');
IF EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'sap')  EXEC(N'DROP SCHEMA [sap]');
IF EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'meta') EXEC(N'DROP SCHEMA [meta]');

PRINT N'=== DROP ALL completo. La BD quedo vacia de objetos del sistema EST. ===';
GO
