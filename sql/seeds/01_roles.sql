-- =============================================================================
-- 01_roles.sql — Roles base de EST. Idempotente.
-- =============================================================================
SET NOCOUNT ON;

MERGE est.Rol AS t
USING (VALUES
    (N'est-admin', N'Administrador',        N'Acceso total a EST, mantenedores y cierres de version'),
    (N'est-user',  N'Usuario / Agronomo',   N'Acceso a estimaciones de sus productor-variedad asignados'),
    (N'est-bi',    N'BI',                   N'Acceso de lectura a vistas y reportes')
) AS s (Codigo, Nombre, Descripcion)
ON t.Codigo = s.Codigo
WHEN MATCHED THEN
    UPDATE SET Nombre = s.Nombre, Descripcion = s.Descripcion, UpdatedAt = SYSUTCDATETIME()
WHEN NOT MATCHED THEN
    INSERT (Codigo, Nombre, Descripcion) VALUES (s.Codigo, s.Nombre, s.Descripcion);

PRINT 'Roles seed OK.';
GO
