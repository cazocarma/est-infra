-- =============================================================================
-- 02_catalogos.sql -- Valores base de catalogos (idempotente, MERGE por Codigo).
-- El admin puede extender estos valores desde la UI de mantenedores.
-- =============================================================================
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
SET NOCOUNT ON;

------------------------------------------------------------
-- Condicion (estado de la fruta)
------------------------------------------------------------
MERGE est.Condicion AS t
USING (VALUES
    (N'NORMAL',     N'Normal',       1),
    (N'BLANDA',     N'Blanda',       2),
    (N'SOBREMADURA',N'Sobremadura',  3),
    (N'VERDE',      N'Verde',        4),
    (N'DANADA',     N'Danada',       5)
) AS s (Codigo, Nombre, Orden)
ON t.Codigo = s.Codigo
WHEN MATCHED THEN UPDATE SET Nombre = s.Nombre, Orden = s.Orden, UpdatedAt = SYSUTCDATETIME()
WHEN NOT MATCHED THEN INSERT (Codigo, Nombre, Orden) VALUES (s.Codigo, s.Nombre, s.Orden);

------------------------------------------------------------
-- Destino (mercado / uso)
------------------------------------------------------------
MERGE est.Destino AS t
USING (VALUES
    (N'EXPORTACION',     N'Exportacion',        1),
    (N'MERCADO_INTERNO', N'Mercado Interno',    2),
    (N'INDUSTRIA',       N'Industria',          3),
    (N'DESECHO',         N'Desecho',            4)
) AS s (Codigo, Nombre, Orden)
ON t.Codigo = s.Codigo
WHEN MATCHED THEN UPDATE SET Nombre = s.Nombre, Orden = s.Orden, UpdatedAt = SYSUTCDATETIME()
WHEN NOT MATCHED THEN INSERT (Codigo, Nombre, Orden) VALUES (s.Codigo, s.Nombre, s.Orden);

------------------------------------------------------------
-- TipoCalidad
------------------------------------------------------------
MERGE est.TipoCalidad AS t
USING (VALUES
    (N'PREMIUM',    N'Premium',       1),
    (N'CATEGORIA_1',N'Categoria 1',   2),
    (N'CATEGORIA_2',N'Categoria 2',   3),
    (N'INDUSTRIAL', N'Industrial',    4)
) AS s (Codigo, Nombre, Orden)
ON t.Codigo = s.Codigo
WHEN MATCHED THEN UPDATE SET Nombre = s.Nombre, Orden = s.Orden, UpdatedAt = SYSUTCDATETIME()
WHEN NOT MATCHED THEN INSERT (Codigo, Nombre, Orden) VALUES (s.Codigo, s.Nombre, s.Orden);

------------------------------------------------------------
-- TipoColor
------------------------------------------------------------
MERGE est.TipoColor AS t
USING (VALUES
    (N'C1', N'Color 1',  1),
    (N'C2', N'Color 2',  2),
    (N'C3', N'Color 3',  3),
    (N'C4', N'Color 4',  4),
    (N'C5', N'Color 5',  5)
) AS s (Codigo, Nombre, Orden)
ON t.Codigo = s.Codigo
WHEN MATCHED THEN UPDATE SET Nombre = s.Nombre, Orden = s.Orden, UpdatedAt = SYSUTCDATETIME()
WHEN NOT MATCHED THEN INSERT (Codigo, Nombre, Orden) VALUES (s.Codigo, s.Nombre, s.Orden);

------------------------------------------------------------
-- TipoEnvase
------------------------------------------------------------
MERGE est.TipoEnvase AS t
USING (VALUES
    (N'CAJA_8_2',   N'Caja 8.2 kg',  1),
    (N'CAJA_10',    N'Caja 10 kg',   2),
    (N'CLAMSHELL',  N'Clamshell',    3),
    (N'GRANEL',     N'Granel',       4),
    (N'BOLSA',      N'Bolsa',        5)
) AS s (Codigo, Nombre, Orden)
ON t.Codigo = s.Codigo
WHEN MATCHED THEN UPDATE SET Nombre = s.Nombre, Orden = s.Orden, UpdatedAt = SYSUTCDATETIME()
WHEN NOT MATCHED THEN INSERT (Codigo, Nombre, Orden) VALUES (s.Codigo, s.Nombre, s.Orden);

PRINT 'Catalogos seed OK.';
GO
