-- =============================================================================
-- 202604160002__auth.sql
-- Identidad, roles y auditoria. Todo bajo schema `est`.
-- =============================================================================
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
SET NOCOUNT ON;
SET XACT_ABORT ON;

-- est.Rol
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE object_id = OBJECT_ID(N'est.Rol'))
BEGIN
    CREATE TABLE est.Rol (
        RolId       SMALLINT     IDENTITY(1,1) NOT NULL CONSTRAINT PK_est_Rol PRIMARY KEY,
        Codigo      NVARCHAR(32) NOT NULL CONSTRAINT UQ_est_Rol_Codigo UNIQUE,
        Nombre      NVARCHAR(64) NOT NULL,
        Descripcion NVARCHAR(256) NULL,
        Activo      BIT          NOT NULL CONSTRAINT DF_est_Rol_Activo    DEFAULT 1,
        CreatedAt   DATETIME2(0) NOT NULL CONSTRAINT DF_est_Rol_CreatedAt DEFAULT SYSUTCDATETIME(),
        UpdatedAt   DATETIME2(0) NOT NULL CONSTRAINT DF_est_Rol_UpdatedAt DEFAULT SYSUTCDATETIME()
    );
END
GO

-- est.Usuario
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE object_id = OBJECT_ID(N'est.Usuario'))
BEGIN
    CREATE TABLE est.Usuario (
        UsuarioId    BIGINT        IDENTITY(1,1) NOT NULL CONSTRAINT PK_est_Usuario PRIMARY KEY,
        Sub          NVARCHAR(64)  NOT NULL CONSTRAINT UQ_est_Usuario_Sub UNIQUE,
        Usuario      NVARCHAR(128) NOT NULL,
        Nombre       NVARCHAR(200) NOT NULL,
        Email        NVARCHAR(256) NULL,
        PrimaryRole  NVARCHAR(32)  NOT NULL,
        Rut          NVARCHAR(12)  NULL,
        Dv           NCHAR(1)      NULL,
        Activo       BIT           NOT NULL CONSTRAINT DF_est_Usuario_Activo     DEFAULT 1,
        CreatedAt    DATETIME2(0)  NOT NULL CONSTRAINT DF_est_Usuario_CreatedAt  DEFAULT SYSUTCDATETIME(),
        UpdatedAt    DATETIME2(0)  NOT NULL CONSTRAINT DF_est_Usuario_UpdatedAt  DEFAULT SYSUTCDATETIME(),
        UltimoLogin  DATETIME2(0)  NULL
    );
    CREATE INDEX IX_est_Usuario_Usuario ON est.Usuario(Usuario);
END
GO

-- est.UsuarioRol (N:N)
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE object_id = OBJECT_ID(N'est.UsuarioRol'))
BEGIN
    CREATE TABLE est.UsuarioRol (
        UsuarioId BIGINT       NOT NULL,
        RolId     SMALLINT     NOT NULL,
        CreatedAt DATETIME2(0) NOT NULL CONSTRAINT DF_est_UsuarioRol_CreatedAt DEFAULT SYSUTCDATETIME(),
        CONSTRAINT PK_est_UsuarioRol PRIMARY KEY (UsuarioId, RolId),
        CONSTRAINT FK_est_UsuarioRol_Usuario FOREIGN KEY (UsuarioId) REFERENCES est.Usuario(UsuarioId) ON DELETE CASCADE,
        CONSTRAINT FK_est_UsuarioRol_Rol     FOREIGN KEY (RolId)     REFERENCES est.Rol(RolId)
    );
END
GO

-- est.Auditoria
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE object_id = OBJECT_ID(N'est.Auditoria'))
BEGIN
    CREATE TABLE est.Auditoria (
        AuditoriaId BIGINT        IDENTITY(1,1) NOT NULL CONSTRAINT PK_est_Auditoria PRIMARY KEY,
        UsuarioId   BIGINT        NULL,
        Operacion   NVARCHAR(80)  NOT NULL,
        Origen      NVARCHAR(32)  NOT NULL,
        Detalle     NVARCHAR(MAX) NULL,
        RequestId   NVARCHAR(64)  NULL,
        IpOrigen    NVARCHAR(64)  NULL,
        FechaUtc    DATETIME2(0)  NOT NULL CONSTRAINT DF_est_Auditoria_FechaUtc DEFAULT SYSUTCDATETIME(),
        CONSTRAINT FK_est_Auditoria_Usuario FOREIGN KEY (UsuarioId) REFERENCES est.Usuario(UsuarioId)
    );
    CREATE INDEX IX_est_Auditoria_Usuario_Fecha ON est.Auditoria(UsuarioId, FechaUtc DESC);
    CREATE INDEX IX_est_Auditoria_Operacion     ON est.Auditoria(Operacion, FechaUtc DESC);
END
GO

-- Nota: NO se crea trigger TR_Usuario_UpdatedAt - rompe OUTPUT en MERGE/INSERT.
-- Convencion: cada UPDATE incluye `UpdatedAt = SYSUTCDATETIME()` explicitamente.

INSERT INTO meta.Migracion (NombreArchivo)
SELECT N'202604160002__auth.sql'
WHERE NOT EXISTS (SELECT 1 FROM meta.Migracion WHERE NombreArchivo = N'202604160002__auth.sql');
GO

PRINT '202604160002__auth aplicada.';
GO
