# AUTH_STANDARD — pointer

> **Este archivo no es canónico.** No editar aquí.
>
> La fuente única del estándar de autenticación OIDC/BFF de Greenvic Platform vive en:
>
> **`platform/docs/AUTH_STANDARD.md`**
>
> (ruta absoluta en el servidor: `/opt/platform/docs/AUTH_STANDARD.md`).
>
> Cualquier cambio al patrón se hace allá y se aplica a **todas** las apps (CFL, CDC, EST, futuras) simultáneamente. Copiar el contenido aquí genera drift — está explícitamente prohibido en §14 de la spec.

## Por qué el pointer

Antes existía una copia paralela en `est-infra/docs/AUTH_STANDARD.md`. Se detectó drift contra `platform/docs/` (diferencias silenciosas tras ediciones independientes). Para eliminar la clase de riesgo, `platform/docs/` es canónico y este archivo solo señala dónde leerla.

Si estás desarrollando en EST sin acceso al repo de platform, la última versión consolidada está versionada en el mismo git que este archivo en commits previos; revisa el historial o clona `platform` localmente.

## Resumen express (no sustituye la spec)

- **BFF obligatorio**: tokens solo en el back (Redis DB `4` para EST), browser solo cookie opaca `est.sid`.
- **4 endpoints**: `/api/v1/auth/{login,callback,me,logout}`.
- **5.º endpoint**: `POST /api/v1/auth/backchannel-logout` para logout iniciado por Keycloak.
- **Rol mínimo**: `est-user` del realm `ESTRealm` (gate del login).
- **Multi-rol fino**: `est.UsuarioRol` + `requireRole(...)` con cache 60 s.
- **Suspensión local**: `UPDATE est.Usuario SET Activo=0` → callback responde `403 user_suspended`.
- **Auditoría**: tabla `est.Auditoria`, operaciones en §9 de la spec.
