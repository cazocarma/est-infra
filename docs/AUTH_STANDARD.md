# Greenvic Platform — Estándar de Autenticación

Este documento define **el patrón obligatorio** que debe usar cualquier aplicación que se sume al stack de Greenvic Platform para autenticarse contra Keycloak. Sirve como contrato transversal para CDC, CFL y cualquier app futura.

> Última revisión: 2026-04. Patrón vigente: **Backend-for-Frontend (BFF)** / Token-Mediating Backend.

---

## 1. Patrón obligatorio: BFF (Backend-for-Frontend)

Todas las aplicaciones SPA + API del stack deben implementar OIDC siguiendo el patrón **BFF / Token-Mediating Backend**:

- Los **tokens OAuth** (`access_token`, `id_token`, `refresh_token`) **viven exclusivamente en el backend**, dentro de un session store server-side (Redis).
- El **browser** únicamente sostiene una **cookie de sesión opaca** (`HttpOnly`, `Secure`, `SameSite=Strict`).
- El **backend** es el único cliente OIDC frente a Keycloak: hace `authorization_code` exchange, refresh, y `end_session`.
- El **frontend** nunca llama a Keycloak por XHR/fetch — solo navegación top-level cuando el back redirige.

### Justificación

- IETF draft `oauth-browser-based-apps` (revisión 2024) recomienda explícitamente BFF sobre PKCE-en-browser cuando hay un backend en el mismo origen.
- `OAuth 2.0 Security Best Current Practice` (RFC draft) prohíbe Implicit Flow y desaconseja `localStorage`/`sessionStorage` para tokens.
- XSS sigue siendo el vector dominante de robo de tokens en SPAs. `HttpOnly` lo neutraliza para esta clase de ataques.

### Diagrama de secuencia

```
[browser]                       [router :NN]                    [<app>-back]                    [keycloak (interno)]
   |                                 |                                |                                 |
   | GET /api/v1/auth/login          |                                |                                 |
   |-------------------------------->|------------------------------->|                                 |
   |                                 |                                | genera state+nonce+pkce         |
   |                                 |                                | guarda preauth en sesion        |
   |                                 |<------ 302 + Set-Cookie sid ---|                                 |
   |<------- 302 a Keycloak ---------|                                |                                 |
   |                                                                                                    |
   | GET /realms/<R>/protocol/openid-connect/auth?...        (browser → keycloak via router :8080)      |
   |-------------------------------------------------------------------------------------------------->|
   |<------ pantalla de login + consent ----------------------------------------------------------------|
   | POST credenciales                                                                                  |
   |-------------------------------------------------------------------------------------------------->|
   |<------ 302 a /api/v1/auth/callback?code&state ----------------------------------------------------|
   |                                                                                                    |
   | GET /api/v1/auth/callback?code&state                                                               |
   |--------------------------->|------------------------------->|                                      |
   |                            |                                | valida state contra sid             |
   |                            |                                | exchange code (con PKCE + secret)   |
   |                            |                                |------------------------------------->|
   |                            |                                |<-------- access+id+refresh ----------|
   |                            |                                | valida id_token (firma+iss+aud+nonce)|
   |                            |                                | valida rol del realm                 |
   |                            |                                | upsert <app>.Usuario por sub         |
   |                            |                                | regenera sid (defensa fijacion)      |
   |                            |                                | guarda tokens en redis bajo nuevo sid|
   |                            |<-- 302 / + Set-Cookie sid ------|                                     |
   |<-- 302 / + Set-Cookie -----|                                |                                      |
   |                                                                                                    |
   | GET /api/v1/auth/me  (cookie sid automatica)                                                        |
   |--------------------------->|------------------------------->| lee sesion -> { user, csrfToken }    |
   |                                                                                                    |
   | POST /api/v1/temporadas (cookie sid + X-CSRF-Token)                                                 |
   |--------------------------->|------------------------------->| valida sid + csrf                    |
   |                            |                                | refresca access_token si toca       |
   |                            |<------- 200 datos -------------|                                      |
   |                                                                                                    |
   | POST /api/v1/auth/logout (CSRF)                                                                     |
   |--------------------------->|------------------------------->| destroy session + end_session_endpoint|
   |                            |<------ 204 + cookie expirada --|                                      |
```

---

## 2. Contrato HTTP de los endpoints de auth

Toda app del stack **debe exponer** estos cuatro endpoints, exactamente con esta forma:

| Método | Path | Comportamiento |
|---|---|---|
| `GET` | `/api/v1/auth/login?returnTo=<ruta>` | 302 al `authorization_endpoint` del IdP. Guarda `state`, `nonce`, `code_verifier`, `returnTo` en la sesión preauth. |
| `GET` | `/api/v1/auth/callback?code&state` | Valida `state`, exchange con PKCE+secret, valida `id_token`, valida rol, upsert usuario, **regenera `sid`**, guarda tokens en Redis, 302 a `returnTo` o `/`. |
| `GET` | `/api/v1/auth/me` | `200 { user: { id, usuario, nombre, role }, csrfToken }` o `401`. Refresca tokens si están por expirar. |
| `POST` | `/api/v1/auth/logout` | Requiere `X-CSRF-Token`. Destruye la sesión, llama `end_session_endpoint` con `id_token_hint`, borra cookie, `204`. |

**Prohibido**: `POST /api/v1/auth/login` con `usuario`/`password` (password grant). El login local queda eliminado.

---

## 3. Cookies de sesión

| Atributo | Valor |
|---|---|
| Nombre | `<app>.sid` (`cdc.sid`, `cfl.sid`, …) |
| `HttpOnly` | **siempre true** |
| `Secure` | **true en QA y prod**. En dev local con HTTP plano se acepta `false` solo si está documentado |
| `SameSite` | **`Strict`** (front y back en el mismo origen vía router) |
| `Path` | `/` |
| TTL | `8h` (rolling, idle 30 min) |
| Firma | secret de `>= 32 bytes` por app, distinto del de cualquier otra |
| Contenido | **opaco** — nunca colocar el `accessToken`/`refreshToken` dentro del cookie value, solo el `sid` |

---

## 4. Sesión server-side en Redis

### Convenciones

- El servidor Redis vive en `platform_cache` (`platform/docker-compose.yml`).
- Cada app usa una **DB distinta** para aislamiento operacional:

| App | Redis DB |
|---|---|
| CFL | `0` |
| CDC | `3` |
| futuras | `4`, `5`, … (registrar aquí) |

### Estructura del payload de sesión

```js
{
  userId: number,            // PK en <app>.Usuario
  sub: string,               // sub del id_token (UUID Keycloak)
  usuario: string,           // preferred_username
  nombre: string,            // name claim
  email: string | null,
  role: string,              // PrimaryRole
  accessToken: string,
  refreshToken: string,
  idToken: string,           // necesario para end_session_endpoint
  accessTokenExpiresAt: number,  // ms epoch
  csrfToken: string,         // 32 bytes random hex, regenerado en cada login
}
```

### Refresh

- El middleware de authn refresca el `accessToken` **proactivamente** cuando faltan menos de **30 segundos** para expirar.
- Si el refresh falla → destruir sesión + responder `401 Sesion expirada`.
- El `refresh_token` es **single-use** (Keycloak `refreshTokenMaxReuse=0`); el back **debe** persistir el nuevo refresh token después de cada uso.

---

## 5. CSRF

- Cookie `SameSite=Strict` mitiga el grueso del CSRF en navegadores modernos.
- **Defensa en profundidad obligatoria**: `csrfToken` por sesión, generado en login (`crypto.randomBytes(32).hex`), regenerado en cada `regenerate()`.
- Se entrega al front en el body de `GET /auth/me`.
- El front lo envía como header **`X-CSRF-Token`** en todos los métodos `POST/PUT/PATCH/DELETE`.
- El middleware compara con **`crypto.timingSafeEqual`** para evitar timing attacks.
- Métodos seguros (`GET`, `HEAD`, `OPTIONS`) no requieren CSRF.
- Falta o mismatch → `403 CSRF token invalido` + audit `CSRF_FAIL`.

---

## 6. Cliente OIDC en Keycloak

### Configuración obligatoria por aplicación

| Atributo | Valor |
|---|---|
| `clientId` | `<app>-back` (kebab-case) |
| `publicClient` | **false** (confidencial) |
| `secret` | fijo en `platform/.env`, inyectado al realm via `keycloak-config-cli` |
| `standardFlowEnabled` | `true` |
| `directAccessGrantsEnabled` | **`false`** (no password grant) |
| `implicitFlowEnabled` | **`false`** |
| `serviceAccountsEnabled` | `false` (a menos que la app necesite client credentials) |
| `redirectUris` | **una sola URL exacta**: `https://<host>/api/v1/auth/callback` |
| `webOrigins` | **vacío** (browser nunca llama por CORS) |
| `attributes."pkce.code.challenge.method"` | **`S256`** |
| `attributes."post.logout.redirect.uris"` | `https://<host>/login` |
| `attributes."backchannel.logout.session.required"` | `true` |
| `attributes."access.token.lifespan"` | `300` (5 min) |
| `attributes."client.session.idle.timeout"` | `1800` (30 min) |
| `attributes."client.session.max.lifespan"` | `28800` (8 h) |
| Audience mapper | obligatorio: agrega `<app>-back` al `aud` del id_token y access_token |

### Configuración de realm

| Setting | Valor |
|---|---|
| `bruteForceProtected` | **true** |
| `failureFactor` | 10 |
| `revokeRefreshToken` | **true** |
| `refreshTokenMaxReuse` | **0** |
| `ssoSessionIdleTimeout` | 1800 |
| `ssoSessionMaxLifespan` | 28800 |
| `accessTokenLifespan` | 300 |
| `registrationAllowed` | **false** (provisioning fuera de banda) |
| `loginTheme` | tema custom de la app si existe (`cdc`, `cfl`, …) |

### Provisioning

Toda configuración de Keycloak (realms, clients, roles, users, themes activos) **debe** estar declarada en JSON bajo `platform/keycloak/import/<app>-realm.json` y aplicarse vía el servicio one-shot **`keycloak-config-cli`**. **Cero pasos manuales en la consola.** Cualquier cambio se hace editando el JSON y reaplicando.

---

## 7. Configuración de red en docker-compose

### Redes externas que debe consumir cada app

| Red | Externa | Para qué |
|---|---|---|
| `platform_identity` | sí | El back se conecta a Keycloak (`http://keycloak:8080`) |
| `platform_cache` | sí | El back se conecta a Redis (`redis://redis:6379`) |
| `<app>_default` | sí (la propia) | Comunicación interna front ↔ back y exposición al router |

### Reglas

- **Solo `greenvic-router` publica puertos al host.** Ninguna app individual abre puertos.
- **Keycloak nunca alcanzable por XHR/fetch del browser.** Solo por navegación top-level vía el router en `:8080`.
- **El back se conecta a Keycloak por hostname interno** (`http://keycloak:8080`), pero **valida `iss`** contra la URL pública (`http://<host>:8080/realms/<R>`). Permitirá migrar a HTTPS cambiando el issuer en el `.env`.

---

## 8. Endurecimiento de endpoints

### Backend (Express)

- `helmet()` con `referrerPolicy: 'no-referrer'`, `crossOriginResourcePolicy: 'same-origin'`. CSP la pone el router por vhost.
- `express.json({ limit: '256kb' })`. Body grandes prohibidos en API normal.
- `cookie-parser` antes de `express-session`.
- `express-session` + `connect-redis` con la configuración de §3.
- `express-rate-limit` en `/auth/login` y `/auth/callback` (ventanas y umbrales sobre la base de Keycloak brute-force ya activo).
- `express.urlencoded` **deshabilitado** salvo que se use HTML forms (no aplica al BFF).
- Logs estructurados con `pino`. **Prohibido** loguear: `accessToken`, `refreshToken`, `idToken`, `sid` completo. El sid puede aparecer truncado a 8 chars (`sid=abcd1234…`).

### Router (NGINX)

- CSP estricta por vhost (`default-src 'self'`).
- `client_max_body_size 256k` en `/api/`.
- `proxy_set_header Cookie $http_cookie` (default OK).
- **No** sobrescribir `Set-Cookie` desde el router.
- `proxy_hide_header X-Powered-By`.

### Storage prohibido en el browser

- ❌ `localStorage` con tokens
- ❌ `sessionStorage` con tokens
- ❌ JS-accessible cookies (`document.cookie`) con tokens
- ❌ Service worker cache de respuestas autenticadas

Criterio bloqueante de aceptación de cualquier deploy: **devtools → Application → Storage debe estar vacío de cualquier cosa relacionada con OIDC**.

---

## 8.bis Mapeo de usuarios y autorización mínima

### Mapeo IdP → BD local

Cada app debe mantener su propia tabla `<schema>.Usuario` con el `sub` de Keycloak como clave única. El callback OIDC ejecuta un upsert en cada login exitoso:

```sql
MERGE <schema>.Usuario AS t
USING (SELECT @sub, @usuario, @nombre, @email, @role) AS s
ON t.Sub = s.Sub
WHEN MATCHED THEN UPDATE SET Usuario, Nombre, Email, PrimaryRole, UpdatedAt
WHEN NOT MATCHED THEN INSERT (Sub, Usuario, Nombre, Email, PrimaryRole, Activo);
```

Reglas del mapeo:

- **`Sub` (PK lógica)** = claim `sub` del id_token. Estable aunque renombren al usuario.
- **`Usuario`** = `preferred_username` o `email` o `sub`. Human-readable, mutable.
- **`Nombre`** = `name` o `preferred_username`.
- **`Email`** = claim `email` (puede ser null).
- **`PrimaryRole`** = primer rol del realm que matchee `OIDC_REQUIRED_ROLE`.
- **`Activo`** = `1` por defecto. Permite suspensión local sin tocar el IdP.

**Keycloak es la fuente de verdad** para `Usuario`/`Nombre`/`Email` — los cambios manuales en la BD se sobrescriben en el próximo login.

### Autorización mínima (single role)

Toda app debe definir `OIDC_REQUIRED_ROLE` en su `.env`. El comportamiento es:

1. En el callback, el back lee `claims.realm_access.roles` y busca `OIDC_REQUIRED_ROLE`.
2. Si **no** está → responde `403 Usuario sin acceso` y **no** crea sesión ni row en BD.
3. Si está → guarda en `req.session.role` y en `<schema>.Usuario.PrimaryRole`.
4. El middleware `authn` valida `req.session.role === OIDC_REQUIRED_ROLE` en cada request.

Esto permite que un realm pueda hospedar usuarios de varias apps sin que tengan acceso cruzado: un usuario con `cfl-user` no puede entrar a CDC aunque autentique correctamente contra Keycloak.

Cuando una app necesite **roles múltiples** (ej. `cdc-admin`, `cdc-readonly`), reemplazar el check single-role por un helper `requireRole(...allowed)` en el middleware. Por ahora, single-role es el MVP estándar.

### Provisioning de usuarios

| Caso | Mecanismo |
|---|---|
| Equipo fijo (admins, cuentas de servicio) | Agregar al bloque `users` de `<app>-realm.json`, definir bootstrap password en `platform/.env`, reaplicar con `keycloak-config-cli`. Versionable. |
| Usuarios de día a día | Crear desde la consola admin de Keycloak con rol `<app>-user` asignado (la `defaultRole` del realm lo asigna automáticamente al crear). |
| Auto-creación en BD local | Implícita: el primer login del usuario dispara el upsert, no hay paso manual. |

### Operaciones comunes

| Acción | Cómo |
|---|---|
| Suspender en todas las apps | Keycloak admin → User → `Enabled: OFF` |
| Suspender solo en una app | `UPDATE <schema>.Usuario SET Activo = 0 WHERE Sub = '<sub>'` |
| Forzar logout inmediato | Keycloak admin → Sessions → Logout. Para expulsión instantánea, también borrar `<app>:sess:*` de Redis (caso contrario espera al siguiente refresh, < 30s) |
| Quitar acceso a una app sin borrar usuario | Keycloak admin → User → Role mapping → unassign `<app>-user` |
| Resetear password | Keycloak admin → User → Credentials → Reset password |

## 9. Auditoría

Cada app debe persistir los siguientes eventos en su tabla de auditoría (`<app>.Auditoria`) con `Origen='OIDC'`:

| Operacion | Cuándo |
|---|---|
| `LOGIN` | callback OIDC exitoso (post-regenerate sid) |
| `LOGOUT` | logout exitoso (antes de destroy) |
| `REFRESH_FAIL` | `oidcClient.refresh()` lanza |
| `CSRF_FAIL` | mismatch del header `X-CSRF-Token` |
| `UNAUTHORIZED` | request a recurso protegido sin sesión válida |
| `FORBIDDEN_ROLE` | usuario sin el rol mínimo intenta entrar |

`Detalle` debe incluir el `sub` truncado o el `userId`, nunca el token.

---

## 10. HTTPS

- **Obligatorio en QA y prod.** Las cookies de sesión llevan flag `Secure` y el browser las descarta sobre HTTP plano.
- En dev local con HTTP, se permite `SESSION_COOKIE_SECURE=false` **solo si está marcado en el `.env` con un comentario explícito**. El estándar lo marca como deuda visible.
- Recomendado: terminar TLS en `greenvic-router` con cert interno (CA propia para LAN) o Let's Encrypt si hay dominio público.

---

## 11. Logout federado (obligatorio)

El back **debe** llamar al `end_session_endpoint` de Keycloak con `id_token_hint` cuando procesa `POST /auth/logout`. Esto revoca la sesión global del usuario en el IdP, no solo la cookie local.

```js
const url = oidcClient.endSessionUrl({
  id_token_hint: session.idToken,
  post_logout_redirect_uri: config.oidc.postLogoutRedirectUri,
});
await fetch(url, { redirect: 'manual' });   // back-channel desde el back
session.destroy(...);
res.clearCookie(...);
res.status(204).end();
```

---

## 12. Variables de entorno (template)

Cada app debe leer las siguientes variables (prefijadas, respetando los nombres canónicos):

```bash
# OIDC
OIDC_ISSUER_URL=http://<public-host>:8080/realms/<RealmName>
OIDC_DISCOVERY_URL=http://keycloak:8080/realms/<RealmName>/.well-known/openid-configuration
OIDC_CLIENT_ID=<app>-back
OIDC_CLIENT_SECRET=<32-byte hex>
OIDC_REDIRECT_URI=http(s)://<public-host>:<port>/api/v1/auth/callback
OIDC_POST_LOGOUT_REDIRECT_URI=http(s)://<public-host>:<port>/login
OIDC_SCOPES=openid profile email
OIDC_REQUIRED_ROLE=<app>-user

# Sesion BFF
SESSION_REDIS_URL=redis://:<REDIS_PASSWORD>@redis:6379/<DB_NUMBER>
SESSION_COOKIE_NAME=<app>.sid
SESSION_COOKIE_SECRET=<32-byte hex, distinto al cliente OIDC>
SESSION_COOKIE_SECURE=true     # false solo en dev local con HTTP
SESSION_COOKIE_SAMESITE=strict
SESSION_TTL_SECONDS=28800
```

`OIDC_CLIENT_SECRET`, `SESSION_COOKIE_SECRET` y `REDIS_PASSWORD` **no van en `.env.example`**. En la plantilla quedan como `<changeme>` o vacíos.

---

## 13. Checklist de migración para una nueva app

Cuando se agregue una nueva aplicación al stack, el responsable debe:

- [ ] Reservar un número de DB en Redis (registrar en §4 de este documento).
- [ ] Crear `<app>-realm.json` en `platform/keycloak/import/` siguiendo el template de CDC.
- [ ] Definir `<APP>_BACK_CLIENT_SECRET` en `platform/.env` (`openssl rand -hex 32`).
- [ ] Aplicar el realm con `docker compose run --rm keycloak-config-cli`.
- [ ] Conectar el back de la app a `platform_identity` y `platform_cache` (externas).
- [ ] Implementar los 4 endpoints `/api/v1/auth/{login,callback,me,logout}` siguiendo el contrato §2.
- [ ] Implementar `csrfMiddleware` y `authnMiddleware` siguiendo §5.
- [ ] Persistir eventos `LOGIN`/`LOGOUT`/etc. en la tabla de auditoría (§9).
- [ ] Eliminar cualquier `localStorage`/`sessionStorage` de tokens en el front.
- [ ] Configurar el vhost del router para la app, sin abrir puertos extras.
- [ ] Verificación end-to-end: login + CSRF + refresh + logout + auditoría.
- [ ] Asegurar `Secure=true` o documentar la deuda en `cdc-infra/.env`.

---

## 14. Anti-patrones explícitamente prohibidos

| Anti-patrón | Razón |
|---|---|
| Guardar `accessToken`/`refreshToken`/`idToken` en `localStorage`/`sessionStorage`/JS | XSS los robaría inmediatamente |
| Exponer `/realms/.../token` o `/userinfo` al browser por XHR | El browser no debe conocer el client_secret ni el flujo PKCE en este patrón |
| Compartir `OIDC_CLIENT_SECRET` entre apps | Compromiso de una expone a todas |
| Habilitar `directAccessGrants` (password grant) | Bypassa MFA, brute-force protection y auditoría del IdP |
| Cookies sin `HttpOnly` y/o sin `SameSite` | Vulnerable a robo por XSS y CSRF respectivamente |
| Reusar el JWT del IdP como sesión propia (mezclar formatos en el middleware) | Acopla la app a la rotación de Keycloak; complica refresh y revocación |
| Reinventar parsing/firma OIDC | Usar `openid-client` (panva). Validar firma a mano es un foot-gun |
| Configurar Keycloak desde la consola y no commitear el JSON | Pierde reproducibilidad y rollback |
| Login local con usuario/password en la BD de la app | Hay un IdP para eso. Una sola fuente de identidad por realm |

---

## Referencias

- IETF draft `oauth-browser-based-apps` — https://datatracker.ietf.org/doc/draft-ietf-oauth-browser-based-apps/
- OAuth 2.0 Security Best Current Practice — https://datatracker.ietf.org/doc/html/draft-ietf-oauth-security-topics
- Keycloak Server Administration Guide — https://www.keycloak.org/docs/latest/server_admin/
- `openid-client` (panva) — https://github.com/panva/node-openid-client
- `keycloak-config-cli` — https://github.com/adorsys/keycloak-config-cli
