# Estándar de Diseño Frontend — CFL (Control de Fletes)

Guía completa para replicar el sistema de diseño del frontend en nuevos módulos o sistemas hermanos.
Verificado contra el código fuente real de `cfl-front-ng` (abril 2026).

---

## 1. Stack Tecnológico

| Componente | Tecnología | Versión |
|---|---|---|
| Framework | Angular (Standalone Components) | 21.x |
| Estilos | Tailwind CSS | 3.4.x |
| Tipografía | Inter (Google Fonts / system-ui fallback) | — |
| Iconos | Heroicons (SVG inline, sin librería) | 24px viewBox |
| Charts | Chart.js + ng2-charts | 4.x / 10.x |
| Build | `@angular/build:application` (esbuild-based) | — |
| Lenguaje | TypeScript | 5.9.x |

---

## 2. Paleta de Colores

### 2.1 Forest Green — Color primario / identidad corporativa

Usado en: sidebar, botones primarios, textos principales, headers de tabla.

| Token | Hex | Uso principal |
|---|---|---|
| `forest-50` | `#f3faf4` | Fondo principal de la app, hover de filas |
| `forest-100` | `#e3f5e6` | Scrollbar track, bordes sutiles |
| `forest-200` | `#c8eacd` | Bordes de inputs, separadores |
| `forest-300` | `#9fd8a8` | Texto sidebar inactivo |
| `forest-400` | `#6dbc7a` | Scrollbar thumb, ring de focus |
| `forest-500` | `#45a054` | Texto secundario, iconos |
| `forest-600` | `#348040` | **Botón primario**, acciones principales |
| `forest-700` | `#2b6734` | Hover de botón primario, nav-item activo |
| `forest-800` | `#25522b` | Sidebar background, dark accents |
| `forest-900` | `#1e4424` | **Texto principal** (headings, body) |
| `forest-950` | `#102614` | Sidebar gradient start (más oscuro) |

### 2.2 Sage Green y Earth — Definidas pero sin uso

Ambas paletas están declaradas en `tailwind.config.js` pero **no se usan en ningún componente**.
Se documentan aquí solo como referencia por si se activan en el futuro.

<details>
<summary>Sage (completa)</summary>

| Token | Hex |
|---|---|
| `sage-50` | `#f6f8f2` |
| `sage-100` | `#eaefdf` |
| `sage-200` | `#d5e0c1` |
| `sage-300` | `#b7ca97` |
| `sage-400` | `#97b06d` |
| `sage-500` | `#7b9650` |
| `sage-600` | `#62793f` |
| `sage-700` | `#4d5f33` |
| `sage-800` | `#404e2c` |
| `sage-900` | `#374327` |
| `sage-950` | `#1c2312` |

</details>

<details>
<summary>Earth (completa)</summary>

| Token | Hex |
|---|---|
| `earth-50` | `#fdf8f3` |
| `earth-100` | `#f9ede0` |
| `earth-200` | `#f2d9bc` |
| `earth-300` | `#e8be8e` |
| `earth-400` | `#dc9c5e` |
| `earth-500` | `#d48040` |
| `earth-600` | `#c56831` |
| `earth-700` | `#a35129` |
| `earth-800` | `#834127` |
| `earth-900` | `#6a3723` |
| `earth-950` | `#391b10` |

</details>

### 2.3 Colores funcionales (Tailwind defaults)

| Propósito | Color | Ejemplo |
|---|---|---|
| Éxito | `emerald-*` | Badges completados, acciones positivas |
| Advertencia | `amber-*` / `orange-*` | Badges actualizado / en revisión |
| Error | `red-*` | Mensajes de error, botón de anular |
| Info | `blue-*` / `cyan-*` | Badges detectados, prefacturado |
| Neutro | `slate-*` | Badges anulados, texto deshabilitado |
| Selección de fila | `teal-50` | Filas seleccionadas en tabla |
| Facturado | `violet-*` | Badge facturado |

### 2.4 Badges de estado — Fletes (clases en `styles.css`)

Cada estado tiene una clase CSS definida en `styles.css` dentro de `@layer components`:

```
DETECTADO:    badge badge-detectado      → bg-blue-50    border-blue-200    text-blue-800
ACTUALIZADO:  badge badge-actualizado    → bg-amber-50   border-amber-200   text-amber-800
EN_REVISION:  badge badge-en-revision    → bg-orange-50  border-orange-200  text-orange-800
COMPLETADO:   badge badge-completado     → bg-emerald-50 border-emerald-200 text-emerald-800
PREFACTURADO: badge badge-prefacturado   → bg-cyan-50    border-cyan-200    text-cyan-800
FACTURADO:    badge badge-facturado      → bg-violet-50  border-violet-200  text-violet-800
ANULADO:      badge badge-anulado        → bg-slate-100  border-slate-200   text-slate-600
```

Dot colors (para indicadores de progreso):

```
DETECTADO:    bg-blue-500
ACTUALIZADO:  bg-amber-500
EN_REVISION:  bg-orange-500
COMPLETADO:   bg-emerald-500
PREFACTURADO: bg-cyan-500
FACTURADO:    bg-violet-500
ANULADO:      bg-slate-400
```

### 2.5 Badges de estado — Facturas (chips sin borde)

Definidos en `factura.utils.ts`. No usan la clase `.badge`; son chips inline con `rounded-full`:

```
borrador:  bg-slate-100 text-slate-700
recibida:  bg-blue-100  text-blue-700
anulada:   bg-red-100   text-red-700
```

### 2.6 Badges de estado — Planillas SAP (chips sin borde)

Definidos en `planilla-detalle.component.ts`:

```
generada:  bg-slate-100  text-slate-700
enviada:   bg-green-100  text-green-700
anulada:   bg-red-100    text-red-700
```

### 2.7 Badge de sentido de flete (Ida / Vuelta)

Inline en bandeja, no usa clase `.badge`:

```html
<!-- IDA -->
<span class="inline-flex items-center justify-center rounded-full bg-emerald-100 w-5 h-5 text-[10px] font-bold text-emerald-700 flex-shrink-0">I</span>

<!-- VUELTA -->
<span class="inline-flex items-center justify-center rounded-full bg-amber-100 w-5 h-5 text-[10px] font-bold text-amber-700 flex-shrink-0">V</span>
```

---

## 3. CSS Custom Properties (Variables globales)

Definidas en `:root` dentro de `styles.css`:

```css
:root {
  --color-primary:     #348040;   /* forest-600 */
  --color-primary-dark:#25522b;   /* forest-800 */
  --color-bg:          #f3faf4;   /* forest-50  */
  --color-sidebar-bg:  #102614;   /* forest-950 */
  --scrollbar-thumb:   #6dbc7a;   /* forest-400 */
  --scrollbar-track:   #e3f5e6;   /* forest-100 */
}
```

> Nota: Los comments `/* forest-* */` son de referencia en este documento; el código real no los incluye.

Body base:

```css
body {
  font-family: 'Inter', system-ui, sans-serif;
  background-color: var(--color-bg);
  color: #1e4424; /* forest-900 */
}
```

Selection:

```css
::selection {
  background-color: #9fd8a8; /* forest-300 */
  color: #102614;            /* forest-950 */
}
```

---

## 4. Tipografía

### 4.1 Font stack

Cargada via Google Fonts en `index.html`:

```html
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700;800&display=swap" rel="stylesheet">
```

```css
font-family: 'Inter', system-ui, sans-serif;
```

Tailwind config override:

```js
fontFamily: {
  sans: ['Inter', 'system-ui', 'sans-serif'],
},
```

### 4.2 Jerarquía de texto

| Elemento | Clases Tailwind | Ejemplo de uso |
|---|---|---|
| Título principal (h1) | `text-2xl font-bold text-forest-900` | Título de página |
| Título de sección (h2) | `text-lg font-bold text-forest-900` | Header de modal, sección |
| Subtítulo (h3) | `text-base font-semibold text-forest-900` | Subsección |
| Label de campo | `text-xs font-semibold uppercase tracking-wider text-forest-700` | Formularios (component-level) |
| Cuerpo | `text-sm text-forest-600` o `text-forest-700` | Texto general |
| Texto pequeño | `text-xs text-forest-500` | Ayuda, metadatos |
| Texto en tabla header | `text-xs font-semibold uppercase tracking-wider` | Columnas |
| Texto en tabla body | `text-sm text-forest-900` | Celdas |

### 4.3 Pesos tipográficos

| Peso | Clase | Uso |
|---|---|---|
| Light (300) | `font-light` | Decorativo |
| Regular (400) | `font-normal` | Cuerpo, celdas |
| Medium (500) | `font-medium` | Nav items, chips, btn-secondary, btn-ghost |
| Semibold (600) | `font-semibold` | Labels, subtítulos, headers de tabla, btn-primary, badges |
| Bold (700) | `font-bold` | Títulos, totales |
| Extrabold (800) | `font-extrabold` | Decorativo |

### 4.4 Letter spacing

| Clase | Uso |
|---|---|
| `tracking-wider` (0.05em) | Labels de formulario, headers de tabla |
| `tracking-widest` (0.1em) | Texto uppercase decorativo (stat cards) |

---

## 5. Sombras y Elevación

### 5.1 Sombras custom (en `tailwind.config.js`)

```js
boxShadow: {
  'nature':    '0 4px 24px -4px rgba(45, 111, 58, 0.18)',
  'nature-lg': '0 8px 40px -8px rgba(45, 111, 58, 0.25)',
}
```

### 5.2 Niveles de elevación

| Nivel | Sombra | Uso |
|---|---|---|
| Base | Sin sombra | Elementos planos |
| Tarjeta | `shadow-nature` | Cards, tablas, paneles, stat cards |
| Elevado | `shadow-nature-lg` | Login card |
| Modal | `shadow-xl` / `shadow-2xl` | Modals sobre overlay |
| Header | `shadow-sm` | Workspace header |

---

## 6. Animaciones

### 6.1 Animaciones custom (definidas en Tailwind config)

```js
animation: {
  'fade-in':    'fadeIn 0.25s ease-in-out',
  'slide-down': 'slideDown 0.3s ease-out',
  'pulse-slow': 'pulse 3s cubic-bezier(0.4, 0, 0.6, 1) infinite',
},
keyframes: {
  fadeIn: {
    '0%':   { opacity: '0' },
    '100%': { opacity: '1' },
  },
  slideDown: {
    '0%':   { transform: 'translateY(-8px)', opacity: '0' },
    '100%': { transform: 'translateY(0)',     opacity: '1' },
  },
}
```

### 6.2 Transiciones estándar

| Contexto | Clases |
|---|---|
| Hover de fila | `transition-colors duration-150` |
| Sidebar mobile | `transition-transform duration-300 ease-in-out` |
| Botón click | `active:scale-[0.98]` |
| Cambio de color | `transition-colors` |
| Inputs y botones | `transition` (genérico) |

---

## 7. Componentes de UI

Todas las clases de componentes están definidas en `styles.css` dentro de `@layer components`, salvo que se indique lo contrario.

### 7.1 Botones

#### Primario

```css
.btn-primary {
  @apply inline-flex items-center gap-2 rounded-lg bg-forest-600 px-4 py-2
         text-sm font-semibold text-white shadow-sm transition
         hover:bg-forest-700 focus:outline-none focus:ring-2 focus:ring-forest-400
         focus:ring-offset-1 active:scale-[0.98] disabled:opacity-50;
}
```

#### Secundario

```css
.btn-secondary {
  @apply inline-flex items-center gap-2 rounded-lg border border-forest-200
         bg-white px-4 py-2 text-sm font-medium text-forest-700 shadow-sm transition
         hover:bg-forest-50 focus:outline-none focus:ring-2 focus:ring-forest-300
         active:scale-[0.98];
}
```

#### Ghost

```css
.btn-ghost {
  @apply inline-flex items-center gap-2 rounded-lg px-3 py-2
         text-sm font-medium text-forest-600 transition
         hover:bg-forest-100 focus:outline-none focus:ring-2 focus:ring-forest-300
         active:scale-[0.98];
}
```

#### Icono (solo icono)

```css
.btn-icon {
  @apply inline-flex items-center justify-center rounded-lg p-2
         text-forest-500 transition hover:bg-forest-100 hover:text-forest-700
         focus:outline-none focus:ring-2 focus:ring-forest-300;
}
```

#### Peligro

```css
.btn-danger {
  @apply inline-flex items-center gap-2 rounded-lg px-3 py-2
         text-sm font-medium text-red-600 transition
         hover:bg-red-50 hover:text-red-700
         focus:outline-none focus:ring-2 focus:ring-red-300
         active:scale-[0.98];
}
```

#### Estado loading en botón

```html
<button class="btn-primary" [disabled]="loading()">
  @if (loading()) {
    <svg class="animate-spin h-5 w-5" viewBox="0 0 24 24">...</svg>
    Procesando...
  } @else {
    <svg class="h-4 w-4">...</svg>
    Guardar
  }
</button>
```

#### Estado deshabilitado

```
disabled:opacity-50
```

Nota: `disabled:cursor-not-allowed` **no** se usa en el proyecto.

---

### 7.2 Inputs y formularios

#### Input estándar

```css
.cfl-input {
  @apply block w-full rounded-lg border border-forest-200 bg-white
         px-3 py-2 text-sm text-forest-900 placeholder-forest-400
         shadow-sm transition
         focus:border-forest-500 focus:outline-none focus:ring-2 focus:ring-forest-200;
}
```

#### Select estándar

```css
.cfl-select {
  @apply block w-full rounded-lg border border-forest-200 bg-white
         px-3 py-2 text-sm text-forest-900
         shadow-sm transition
         focus:border-forest-500 focus:outline-none focus:ring-2 focus:ring-forest-200;
}
```

Nota: `.cfl-select` no incluye `placeholder-forest-400` (los `<select>` no usan placeholder).

#### Label de campo (component-level, no global)

Definida en los `styles` de cada componente que la necesita (edit-flete-modal, detalles-tab, searchable-combobox, usuario-form-modal), **no** en `styles.css` global:

```css
/* edit-flete-modal, detalles-tab, usuario-form-modal */
.field-label {
  @apply block text-xs font-semibold text-forest-700 uppercase tracking-wider mb-1.5;
}

/* searchable-combobox (sin mb-1.5, el margin lo maneja el layout del componente) */
.field-label {
  @apply block text-xs font-semibold text-forest-700 uppercase tracking-wider;
}
```

#### Estructura de campo

```html
<div>
  <label class="field-label">Nombre del campo</label>
  <input class="cfl-input" [ngModel]="value()" (ngModelChange)="value.set($event)" />
  @if (hasError) {
    <span class="text-xs text-red-600 mt-1">Mensaje de error</span>
  }
</div>
```

#### Formularios reactivos (modales complejos)

```typescript
this.form = this.fb.group({
  campo: ['', Validators.required],
  email: ['', [Validators.required, Validators.email]],
});
```

#### Formularios template-driven (formularios simples)

```html
<input [(ngModel)]="email" (ngModelChange)="email.set($event)" />
```

---

### 7.3 Tablas

#### Estructura completa

```html
<div class="relative rounded-2xl bg-white shadow-nature overflow-hidden">
  <!-- Barra de filtros (opcional) -->
  <div class="px-4 py-3 flex flex-wrap gap-3 items-center border-b border-forest-100">
    ...filtros...
  </div>

  <!-- Overlay de carga -->
  @if (loading()) {
    <div class="absolute inset-0 z-10 flex items-center justify-center bg-white/70 backdrop-blur-[1px]">
      <div class="h-8 w-8 rounded-full border-3 border-forest-100 border-t-forest-500 animate-spin"></div>
    </div>
  }

  <!-- Tabla con scroll horizontal -->
  <div class="overflow-x-auto">
    <table class="min-w-full">
      <thead>
        <tr style="background: linear-gradient(90deg, #1e4424 0%, #2b6734 100%);">
          <th class="table-header-cell sortable-header">
            Columna
            @if (sortBy() === 'columna') {
              <!-- Ícono de dirección de orden -->
            }
          </th>
        </tr>
      </thead>
      <tbody class="divide-y divide-forest-50">
        @for (item of items(); track item.id) {
          <tr class="table-row">
            <td class="table-cell">{{ item.campo }}</td>
          </tr>
        }
      </tbody>
    </table>
  </div>

  <!-- Paginación -->
  <div class="px-4 py-3 flex items-center justify-between border-t border-forest-100">
    ...controles de paginación...
  </div>
</div>
```

#### Clases de tabla (en `styles.css`)

```css
.table-header-cell {
  @apply px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-forest-200;
}
.sortable-header {
  @apply cursor-pointer select-none hover:text-white transition-colors;
}
.table-cell {
  @apply px-4 py-3 text-sm text-forest-900;
}
.table-row {
  @apply border-b border-forest-100 transition-colors duration-150 hover:bg-forest-50;
}
```

#### Header con gradiente

```
background: linear-gradient(90deg, #1e4424 0%, #2b6734 100%);
```

#### Columna sticky (acciones)

La columna de acciones usa el mismo gradiente que el `<tr>` padre:

```html
<th class="table-header-cell text-center sticky right-0"
    style="background: linear-gradient(90deg, #1e4424 0%, #2b6734 100%);">
  Acciones
</th>
<td class="table-cell sticky right-0 bg-white">
  ...botones de acción...
</td>
```

#### Fila seleccionada

```
bg-teal-50
```

#### Paginación

```html
<div class="flex items-center justify-between border-t border-forest-100 px-5 py-3">
  <span class="text-sm text-forest-600">
    {{ (currentPage() - 1) * itemsPerPage() + 1 }} - {{ paginationEnd() }} de {{ totalItems() }}
  </span>
  <div class="flex items-center gap-2">
    <select class="cfl-select w-auto">
      <option>10</option><option>25</option><option>50</option><option>100</option>
    </select>
    <button class="btn-icon" [disabled]="currentPage() === 1">«</button>
    @for (page of pageNumbers(); track page) {
      <button class="text-xs font-medium px-3 py-1.5 rounded-lg transition"
        [class.bg-forest-600]="page === currentPage()"
        [class.text-white]="page === currentPage()"
        [class.font-semibold]="page === currentPage()"
        [class.text-forest-600]="page !== currentPage()"
        [class.hover:bg-forest-100]="page !== currentPage()">
        {{ page }}
      </button>
    }
    <button class="btn-icon" [disabled]="currentPage() === totalPages()">»</button>
  </div>
</div>
```

---

### 7.4 Badges / Chips

#### Badge base (en `styles.css`)

```css
.badge {
  @apply inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full
         text-xs font-semibold border whitespace-nowrap;
}
```

#### Badge dot (en `styles.css`)

```css
.badge-dot {
  @apply w-1.5 h-1.5 rounded-full flex-shrink-0;
}
```

#### Detail chip (component-level, no global)

Definida en los `styles` de `edit-flete-modal` y `detalles-tab`:

```css
.detail-chip {
  @apply inline-flex items-center rounded-full border border-forest-200
         bg-white px-2.5 py-1 text-[11px] font-medium text-forest-700;
}
```

---

### 7.5 Cards / Paneles

#### Card estándar

```html
<div class="rounded-2xl border border-forest-100 bg-white p-6 shadow-nature">
  <!-- contenido -->
</div>
```

#### Stat Card (en `styles.css`)

```css
.stat-card         { @apply relative overflow-hidden rounded-2xl p-5 text-white shadow-nature; }
.stat-card-primary { @apply bg-gradient-to-br from-forest-600 to-forest-900; }
.stat-card-emerald { @apply bg-gradient-to-br from-emerald-500 to-emerald-800; }
.stat-card-amber   { @apply bg-gradient-to-br from-amber-500  to-amber-800;  }
.stat-card-teal    { @apply bg-gradient-to-br from-teal-500   to-teal-800;   }
```

#### Card seleccionable (wizard)

```html
<div class="rounded-xl border-2 p-4 cursor-pointer transition-colors"
  [class.border-teal-500]="selected"
  [class.bg-teal-50]="selected"
  [class.border-forest-200]="!selected">
```

---

### 7.6 Modales

#### Modal estándar (edit-flete, tamaño grande)

```html
<!-- Overlay -->
<div class="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm p-4 animate-fade-in">
  <!-- Modal -->
  <div class="relative w-full max-w-5xl max-h-[92vh] overflow-y-auto rounded-2xl bg-white shadow-2xl">
    <!-- Header sticky con gradiente -->
    <div class="sticky top-0 z-20 flex items-center gap-4 border-b border-forest-900/20 px-6 py-4"
         style="background: linear-gradient(135deg, #102614 0%, #1e4424 50%, #2d6635 100%);">
      <div class="flex h-10 w-10 flex-shrink-0 items-center justify-center rounded-xl bg-white/10 ring-1 ring-white/20">
        <svg class="h-5 w-5 text-white"><!-- icono --></svg>
      </div>
      <div class="flex-1 min-w-0">
        <h2 class="text-lg font-bold text-white truncate">Título</h2>
        <p class="text-sm text-forest-200 truncate">Subtítulo</p>
      </div>
      <button class="btn-icon text-forest-200 hover:text-white hover:bg-white/10" (click)="close()">
        <svg class="h-5 w-5"><!-- X icon --></svg>
      </button>
    </div>

    <!-- Body -->
    <div class="p-6 space-y-4">
      ...contenido...
    </div>

    <!-- Footer -->
    <div class="border-t border-forest-100 px-6 py-4 flex justify-end gap-3">
      <button class="btn-secondary" (click)="close()">Cancelar</button>
      <button class="btn-primary" (click)="save()" [disabled]="loading()">Guardar</button>
    </div>
  </div>
</div>
```

#### Modal pequeño (formulario, mantenedores)

Header con gradiente pero sin sticky:

```html
<div class="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm p-4 animate-fade-in">
  <div class="w-full max-w-2xl rounded-2xl bg-white shadow-2xl overflow-hidden">
    <!-- Header con gradiente -->
    <div class="px-6 py-4 text-white"
         style="background: linear-gradient(160deg, #1e4424 0%, #348040 100%);">
      <h2 class="text-lg font-bold">Título</h2>
      <p class="text-sm text-forest-200">Subtítulo</p>
    </div>
    <!-- Body + Footer -->
    ...
  </div>
</div>
```

#### Modal de confirmación (componente reutilizable: `confirm-modal`)

```html
<!-- Overlay -->
<div class="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4">
  <!-- Card -->
  <div class="w-full max-w-md rounded-2xl bg-white p-6 shadow-xl">
    <h3 class="text-base font-semibold">Título configurable</h3>
    <div class="mt-2 text-sm text-forest-600">
      <ng-content></ng-content>
    </div>
    <div class="mt-4 flex justify-end gap-3">
      <button class="rounded-xl border border-forest-200 px-4 py-2 text-sm font-semibold text-forest-700 hover:bg-forest-50">
        Cancelar
      </button>
      <button class="rounded-xl px-4 py-2 text-sm font-semibold text-white"
              [class]="confirmClass ?? 'bg-red-600 hover:bg-red-700'">
        Confirmar
      </button>
    </div>
  </div>
</div>
```

#### Modal de confirmación inline (bandeja — con header gradiente)

```html
<div class="fixed inset-0 z-[110] flex items-center justify-center bg-black/60 backdrop-blur-sm px-4 animate-fade-in">
  <div class="w-full max-w-md rounded-2xl bg-white shadow-2xl overflow-hidden">
    <!-- Header con gradiente condicional -->
    <!-- Anular:   bg-gradient-to-r from-red-600 to-red-500 -->
    <!-- Descartar: bg-gradient-to-r from-amber-500 to-amber-400 -->
    <div class="px-6 py-4 text-white" [class]="gradientClass">
      ...
    </div>
    ...
  </div>
</div>
```

#### Anchos de modal

| Tipo | Clase | Ancho aprox. |
|---|---|---|
| Confirmación | `max-w-md` | 448px |
| Formulario mediano | `max-w-2xl` | 672px |
| Detalle grande | `max-w-4xl` | 896px |
| Edit flete | `max-w-5xl` | 1024px |

#### Tabs dentro de modal (edit-flete)

```html
<div class="flex flex-wrap gap-2 rounded-2xl border border-forest-100 bg-forest-50/70 p-2">
  <button class="rounded-xl px-4 py-2 text-sm font-semibold transition-colors"
    [class.border-forest-200]="activeTab === tab"
    [class.bg-white]="activeTab === tab"
    [class.text-forest-800]="activeTab === tab"
    [class.shadow-sm]="activeTab === tab"
    [class.text-forest-600]="activeTab !== tab"
    [class.hover:bg-white/70]="activeTab !== tab">
    Tab label
  </button>
</div>
```

---

### 7.7 Toasts / Notificaciones

#### Posición y estilo

```
Posición: fixed bottom-6 left-1/2 -translate-x-1/2
Z-index: z-[9999]
Animación: animate-fade-in
Max width: max-w-lg
```

#### Variantes

```
Éxito:  bg-forest-700/95 text-white rounded-xl px-5 py-3.5 shadow-lg backdrop-blur-sm
Error:  bg-red-600/95    text-white rounded-xl px-5 py-3.5 shadow-lg backdrop-blur-sm
```

#### Estructura HTML (en `app.component.ts`)

```html
<div role="alert" aria-live="assertive"
     class="fixed bottom-6 left-1/2 z-[9999] -translate-x-1/2 animate-fade-in">
  <div class="flex items-center gap-3 rounded-xl px-5 py-3.5 shadow-lg backdrop-blur-sm cursor-pointer max-w-lg"
       [class]="t.isError ? 'bg-red-600/95 text-white' : 'bg-forest-700/95 text-white'">
    <!-- SVG icon (condicional error/success) -->
    <span class="text-sm font-medium">{{ t.message }}</span>
  </div>
</div>
```

#### Uso en servicio

```typescript
this.toast.show('Operación exitosa');           // éxito (5s por defecto)
this.toast.show('Error al guardar', true);      // error
this.toast.show('Guardado', false, 3000);       // duración custom
```

---

### 7.8 Mensajes de error inline

```html
@if (errorMsg()) {
  <div role="alert" class="rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
    {{ errorMsg() }}
  </div>
}
```

---

### 7.9 Loading / Skeleton

#### Spinner estándar

```html
<div class="h-8 w-8 rounded-full border-3 border-forest-100 border-t-forest-500 animate-spin"></div>
```

#### Overlay de carga sobre contenido

```html
@if (loading()) {
  <div class="absolute inset-0 z-10 flex items-center justify-center bg-white/70 backdrop-blur-[1px]">
    <div class="flex flex-col items-center gap-2">
      <div class="h-8 w-8 rounded-full border-3 border-forest-100 border-t-forest-500 animate-spin"></div>
      <span class="text-sm text-forest-600">Cargando...</span>
    </div>
  </div>
}
```

#### Loading en botón

```html
<button class="btn-primary" [disabled]="loading()">
  @if (loading()) {
    <svg class="animate-spin h-5 w-5" viewBox="0 0 24 24">...</svg>
    Procesando...
  } @else {
    <svg class="h-4 w-4">...</svg>
    Guardar
  }
</button>
```

---

## 8. Layouts

### 8.1 Layout principal (Workspace Shell)

```
┌──────────────────────────────────────────────┐
│ ┌──────────┐ ┌─────────────────────────────┐ │
│ │          │ │  Header (título + acciones) │ │
│ │ Sidebar  │ ├─────────────────────────────┤ │
│ │ (16rem)  │ │                             │ │
│ │          │ │  <ng-content> scrollable    │ │
│ │ nav-items│ │                             │ │
│ │          │ │                             │ │
│ │ user info│ │                             │ │
│ └──────────┘ └─────────────────────────────┘ │
└──────────────────────────────────────────────┘
```

#### Sidebar

```
Ancho: w-64 (16rem / 256px)
Background: linear-gradient(180deg, #102614 0%, #1e4424 60%, #25522b 100%)
Mobile: fixed inset-y-0 left-0 z-50, translate-x animation
Desktop (md+): relative, siempre visible
```

#### Navegación del sidebar (en `styles.css`)

```css
.nav-item {
  @apply flex items-center gap-3 px-3 py-2.5 rounded-xl
         text-sm font-medium text-forest-300 transition-all duration-200
         hover:bg-forest-800 hover:text-white cursor-pointer;
}
.nav-item-active {
  @apply bg-forest-700 text-white shadow-sm;
}
```

#### Header

```html
<header class="flex flex-shrink-0 items-center gap-3 border-b border-forest-100 bg-white px-4 py-4 shadow-sm">
  <!-- Hamburger (mobile only) -->
  <button class="btn-icon md:hidden">...</button>
  <!-- Logo -->
  <img class="h-10 w-10 flex-shrink-0 rounded-xl object-contain bg-white/10 p-1" />
  <!-- Título -->
  <div class="flex-1 min-w-0">
    <h1 class="text-xl font-bold text-forest-900 truncate">Título</h1>
    <p class="text-sm text-forest-500 truncate">Subtítulo</p>
  </div>
  <!-- User info -->
  <div class="flex items-center gap-2">
    <span class="rounded-full bg-forest-500 px-2 py-0.5 text-xs font-bold text-white">AB</span>
  </div>
</header>
```

#### Área de contenido

```html
<div class="flex-1 overflow-y-auto px-4 py-4 sm:px-6 sm:py-6 bg-forest-50">
  <ng-content></ng-content>
</div>
```

### 8.2 Login (pantalla completa)

```
┌──────────────────────────────────────────────┐
│          Gradiente Forest completo           │
│                                              │
│  ┌─────────────┐  ┌─────────────────────┐   │
│  │ Credenciales│  │   Card login        │   │
│  │ demo        │  │   (bg-white/95)     │   │
│  │ (glass)     │  │   backdrop-blur-xl  │   │
│  └─────────────┘  └─────────────────────┘   │
│                                              │
│          SVG decorativos (hojas)             │
└──────────────────────────────────────────────┘
```

Gradiente de fondo:

```css
background: linear-gradient(135deg, #102614 0%, #1e4424 40%, #2b6734 70%, #45a054 100%);
```

Card de login:

```html
<div class="rounded-3xl bg-white/95 backdrop-blur-xl shadow-nature-lg overflow-hidden">
  <!-- Header interno con gradiente -->
  <div class="px-8 pt-10 pb-8"
       style="background: linear-gradient(160deg, #1e4424 0%, #348040 100%);">
    <div class="inline-flex items-center justify-center w-24 h-24 rounded-2xl bg-white/10 backdrop-blur mb-4 ring-2 ring-white/20 p-2">
      <img ... />
    </div>
    <h1 class="text-2xl font-bold text-white">...</h1>
  </div>
  <!-- Formulario -->
  <div class="px-8 py-8">
    <input class="cfl-input" />
    <button class="btn-primary w-full justify-center py-3 text-base">Entrar</button>
  </div>
</div>
```

Panel de credenciales demo:

```
Posición: absolute right-full top-1/2 -translate-y-1/2 mr-4
Background: rounded-xl bg-white/15 backdrop-blur-sm border border-white/20 px-4 py-3
Visible: hidden lg:block (solo desktop ≥1024px)
```

### 8.3 Bandeja (layout propio con sidebar integrado)

La bandeja tiene su propio sidebar integrado con el mismo gradiente y estructura que workspace-shell, pero **no** usa el componente workspace-shell.

Mobile overlay: `fixed inset-0 z-40 bg-black/50 md:hidden`

---

## 9. Catálogo de Gradientes

Todos los gradientes usados en el proyecto:

| Contexto | Gradiente |
|---|---|
| Sidebar (vertical) | `linear-gradient(180deg, #102614 0%, #1e4424 60%, #25522b 100%)` |
| Header de tabla | `linear-gradient(90deg, #1e4424 0%, #2b6734 100%)` |
| Login background | `linear-gradient(135deg, #102614 0%, #1e4424 40%, #2b6734 70%, #45a054 100%)` |
| Login card header | `linear-gradient(160deg, #1e4424 0%, #348040 100%)` |
| Modal header (form) | `linear-gradient(160deg, #1e4424 0%, #348040 100%)` |
| Modal header (edit-flete) | `linear-gradient(135deg, #102614 0%, #1e4424 50%, #2d6635 100%)` |
| Card decorativa (mantenedores) | `linear-gradient(135deg, #1e4424 0%, #348040 100%)` |
| Confirmación anular | `bg-gradient-to-r from-red-600 to-red-500` (Tailwind) |
| Confirmación descartar | `bg-gradient-to-r from-amber-500 to-amber-400` (Tailwind) |
| Stat card primary | `bg-gradient-to-br from-forest-600 to-forest-900` (Tailwind) |

---

## 10. Iconos

### 10.1 Librería: Heroicons (Outline / 24px)

Se usan directamente como SVG inline, **sin librería ni componente wrapper**. Los paths son estilo Heroicons pero copiados manualmente.

```html
<svg class="h-5 w-5 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="..." />
</svg>
```

### 10.2 Tamaños estándar

| Contexto | Clase | Tamaño |
|---|---|---|
| Navegación sidebar | `h-5 w-5` | 20px |
| Dentro de botón | `h-4 w-4` | 16px |
| Indicador pequeño | `h-3.5 w-3.5` | 14px |
| Decorativo grande | `w-96 h-96` | 384px |

### 10.3 Color

Los iconos usan `currentColor` (heredan del color del texto padre) o se les asigna una clase de color explícita:

```html
<!-- Hereda del padre -->
<svg class="h-5 w-5" stroke="currentColor">...</svg>

<!-- Color explícito -->
<svg class="h-5 w-5 text-forest-500" stroke="currentColor">...</svg>
```

---

## 11. Responsive Design

### 11.1 Breakpoints (Tailwind defaults)

| Breakpoint | Ancho mínimo | Uso |
|---|---|---|
| (default) | 0px | Mobile-first, estilos base |
| `sm:` | 640px | Ajustes menores de padding |
| `md:` | 768px | Sidebar visible, layout horizontal |
| `lg:` | 1024px | Credenciales demo en login, grids de 3+ columnas |
| `xl:` | 1280px | Grids de 4+ columnas |

### 11.2 Patrones responsive

| Elemento | Mobile | Desktop (md+) |
|---|---|---|
| Sidebar | Fixed overlay + hamburger | Relative, siempre visible |
| Tablas | `overflow-x-auto` horizontal scroll | Ancho completo |
| Filtros | `flex-wrap` apilados | `flex-row` en línea |
| Modales | Padding `p-4`, full width | Centrado con `max-w-*` |
| Contenido | `px-4 py-4` | `px-6 py-6` |
| Grids | `grid-cols-1` o `grid-cols-2` | `grid-cols-3` / `grid-cols-4` |

### 11.3 Mobile overlay para sidebar

```html
<!-- Overlay oscuro -->
@if (sidebarOpen()) {
  <div class="fixed inset-0 z-40 bg-black/50 md:hidden" (click)="closeSidebar()"></div>
}

<!-- Sidebar con transición -->
<aside class="fixed inset-y-0 left-0 z-50 w-64 transform transition-transform duration-300 ease-in-out md:relative md:translate-x-0"
  [class.translate-x-0]="sidebarOpen()"
  [class.-translate-x-full]="!sidebarOpen()">
```

---

## 12. Patrones de Arquitectura Angular

### 12.1 Componentes standalone

Todos los componentes son standalone (sin NgModules):

```typescript
@Component({
  selector: 'app-ejemplo',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink, OtroComponente],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `...`,
})
export class EjemploComponent { }
```

### 12.2 Estado con Signals

```typescript
// Estado simple
loading = signal(false);
items = signal<Item[]>([]);
error = signal('');

// Estado derivado
filteredItems = computed(() =>
  this.items().filter(i => i.name.includes(this.search()))
);

// Actualización
this.loading.set(true);
this.items.update(prev => [...prev, newItem]);
```

### 12.3 Inyección de dependencias

Usar `inject()` en lugar de constructor injection:

```typescript
private api = inject(CflApiService);
private toast = inject(ToastService);
private router = inject(Router);
private destroyRef = inject(DestroyRef);
```

### 12.4 Suscripciones con cleanup

```typescript
this.api.getData().pipe(
  takeUntilDestroyed(this.destroyRef)
).subscribe({
  next: (data) => this.items.set(data),
  error: (err) => this.toast.show(err.message, true),
  complete: () => this.loading.set(false),
});
```

### 12.5 Control flow moderno (@if, @for, @switch)

```html
@if (loading()) {
  <div>Cargando...</div>
} @else if (error()) {
  <div class="text-red-600">{{ error() }}</div>
} @else {
  @for (item of items(); track item.id) {
    <div>{{ item.name }}</div>
  } @empty {
    <div class="text-forest-500">Sin resultados</div>
  }
}
```

### 12.6 Inputs y Outputs

```typescript
// Inputs (nueva API)
visible = input.required<boolean>();
mode = input<'view' | 'edit'>('view');

// Outputs
cerrado = output<void>();
guardado = output<Item>();
```

### 12.7 Lazy loading de rutas

```typescript
{
  path: 'facturas',
  loadComponent: () => import('./features/facturas/facturas.component')
    .then(m => m.FacturasComponent),
  canActivate: [authnGuard],
}
```

---

## 13. Servicios HTTP

### 13.1 Estructura del servicio API

```typescript
@Injectable({ providedIn: 'root' })
export class CflApiService {
  constructor(private http: HttpClient) {}

  getItems(params: QueryParams): Observable<PagedResponse<Item>> {
    return this.http.get<PagedResponse<Item>>('/api/items', { params });
  }

  createItem(body: CreateItemDto): Observable<Item> {
    return this.http.post<Item>('/api/items', body);
  }

  updateItem(id: number, body: UpdateItemDto): Observable<Item> {
    return this.http.put<Item>(`/api/items/${id}`, body);
  }

  deleteItem(id: number): Observable<void> {
    return this.http.delete<void>(`/api/items/${id}`);
  }
}
```

### 13.2 Respuesta paginada estándar

```typescript
interface Pagination {
  page: number;
  page_size: number;
  total: number;
  total_pages: number;
}

interface PagedResponse<T> {
  data: T[];
  pagination: Pagination;
}
```

### 13.3 Interceptores

| Interceptor | Función |
|---|---|
| `authn.interceptor` | Agrega `Authorization: Bearer <token>` a requests same-origin |
| `network-error.interceptor` | Maneja errores 0, 401, 403, 5xx con toasts |

---

## 14. Patrones de Página

### 14.1 Página de listado (e.g. Facturas)

```
┌────────────────────────────────────┐
│  Filtros (inputs + botones)        │
├────────────────────────────────────┤
│  Tabla con headers, filas, badges  │
│  Acciones por fila (iconos)        │
├────────────────────────────────────┤
│  Paginación                        │
└────────────────────────────────────┘
```

### 14.2 Página de detalle (e.g. Factura Detalle)

```
┌────────────────────────────────────┐
│  Breadcrumb / Botón volver         │
├────────────────────────────────────┤
│  Card: Información general         │
│  (key-value pairs en grid)         │
├────────────────────────────────────┤
│  Card: Tabla de detalles/líneas    │
├────────────────────────────────────┤
│  Card: Acciones / Totales          │
└────────────────────────────────────┘
```

### 14.3 Wizard multi-paso (e.g. Nueva Factura)

```
┌────────────────────────────────────┐
│  Step indicator (circles + lines)  │
│  ① Selección  >  ② Agrupación  >  ③ Confirmar │
├────────────────────────────────────┤
│  Contenido del paso actual         │
│  (cards seleccionables / tablas)   │
├────────────────────────────────────┤
│  Botones: Anterior / Siguiente     │
└────────────────────────────────────┘
```

Step indicator:

```html
<div class="flex items-center gap-2">
  @for (step of steps; track step.number) {
    <div class="h-6 w-6 rounded-full flex items-center justify-center text-xs font-bold"
      [class.bg-teal-600]="currentStep() === step.number"
      [class.text-white]="currentStep() === step.number"
      [class.bg-forest-200]="currentStep() !== step.number"
      [class.text-forest-700]="currentStep() !== step.number">
      {{ step.number }}
    </div>
    @if (!$last) { <span class="text-forest-300">›</span> }
  }
</div>
```

### 14.4 Dashboard con tabs (e.g. Bandeja)

```
┌────────────────────────────────────┐
│  Tabs: [ Candidatos | En curso ]   │
├────────────────────────────────────┤
│  Stat cards (grid responsive)      │
├────────────────────────────────────┤
│  Barra de búsqueda + filtros       │
├────────────────────────────────────┤
│  Tabla con selección múltiple      │
│  + acciones masivas                │
├────────────────────────────────────┤
│  Paginación server-side            │
└────────────────────────────────────┘
```

---

## 15. Accesibilidad

### 15.1 Atributos ARIA requeridos

| Elemento | Atributo |
|---|---|
| Toast / alerta | `role="alert" aria-live="assertive"` |
| Modal de confirmación | `role="alertdialog"` |
| Botón solo con icono | `aria-label="Descripción de la acción"` |
| Elemento decorativo | `aria-hidden="true"` |
| Input con label | `<label for="id">` o `aria-label` |

### 15.2 Focus management

```
Inputs/botones: focus:outline-none focus:ring-2 focus:ring-forest-400 (primary)
                focus:outline-none focus:ring-2 focus:ring-forest-300 (secondary, ghost, icon)
Tab order: Automático por orden del DOM
```

### 15.3 Contraste mínimo (WCAG AA)

| Combinación | Ratio |
|---|---|
| forest-900 sobre blanco | ~13:1 |
| forest-600 sobre blanco | ~4.5:1 |
| Blanco sobre forest-600 | ~4.5:1 |

---

## 16. Scrollbar personalizado

```css
/* Todos los elementos */
* {
  scrollbar-width: thin;
  scrollbar-color: var(--scrollbar-thumb) var(--scrollbar-track);
}

/* Webkit (Chrome, Edge, Safari) */
*::-webkit-scrollbar { width: 6px; height: 6px; }
*::-webkit-scrollbar-track { background: var(--scrollbar-track); border-radius: 3px; }
*::-webkit-scrollbar-thumb { background: var(--scrollbar-thumb); border-radius: 3px; }
```

---

## 17. Reglas globales adicionales (en `styles.css`)

### 17.1 Bloqueo de scroll con modal abierto

```css
body:has(.modal-overlay) {
  overflow: hidden;
}
```

Previene el scroll del `<body>` cuando hay un modal con clase `.modal-overlay` visible.

### 17.2 Elementos deshabilitados por permisos

```css
[disabled][title].cursor-not-allowed {
  position: relative;
  transition: opacity 0.2s ease;
  pointer-events: auto;
}
```

Permite que elementos deshabilitados con `title` y `cursor-not-allowed` sigan recibiendo eventos de hover (para mostrar el tooltip), manteniendo la transición de opacidad.

---

## 18. Textura decorativa (Leaf Pattern)

Clase definida en `styles.css` (fuera de `@layer components`):

```css
.leaf-pattern {
  background-image: url("data:image/svg+xml,%3Csvg width='60' height='60' viewBox='0 0 60 60' xmlns='http://www.w3.org/2000/svg'%3E%3Cg fill='none' fill-rule='evenodd'%3E%3Cg fill='%236dbc7a' fill-opacity='0.08'%3E%3Cpath d='M36 34v-4h-2v4h-4v2h4v4h2v-4h4v-2h-4zm0-30V0h-2v4h-4v2h4v4h2V6h4V4h-4zM6 34v-4H4v4H0v2h4v4h2v-4h4v-2H6zM6 4V0H4v4H0v2h4v4h2V6h4V4H6z'/%3E%3C/g%3E%3C/g%3E%3C/svg%3E");
}
```

Color del patrón: `#6dbc7a` (forest-400) con opacidad 0.08.

---

## 19. Estructura de Archivos

```
src/
├── app/
│   ├── core/                    # Servicios, guards, interceptors, utils, models
│   │   ├── config/
│   │   ├── guards/
│   │   ├── interceptors/
│   │   ├── models/
│   │   ├── services/
│   │   └── utils/
│   ├── features/                # Módulos de funcionalidad (lazy-loaded)
│   │   ├── login/
│   │   ├── bandeja/
│   │   ├── facturas/
│   │   ├── estadisticas/
│   │   ├── auditoria/
│   │   ├── mantenedores/
│   │   ├── planillas-sap/
│   │   └── workspace/
│   ├── shared/                  # Componentes reutilizables
│   ├── app.routes.ts
│   ├── app.config.ts
│   └── app.component.ts
├── styles.css                   # Tailwind + custom utilities
└── index.html
```

### Convención de nombres

| Tipo | Formato | Ejemplo |
|---|---|---|
| Componente | `kebab-case.component.ts` | `bandeja.component.ts` |
| Servicio | `kebab-case.service.ts` | `cfl-api.service.ts` |
| Guard | `kebab-case.guard.ts` | `authn.guard.ts` |
| Interceptor | `kebab-case.interceptor.ts` | `network-error.interceptor.ts` |
| Modelo/Interfaz | `kebab-case.model.ts` | `flete.model.ts` |
| Utilidad | `kebab-case.utils.ts` | `format.utils.ts` |

---

## 20. Utilidades de Formateo

```typescript
formatCLP(value): string        // "$ 1.234.567" (peso chileno)
formatDate(value): string       // "25-03-2024"
formatDateTime(value): string   // "25-03-2024, 14:30"
toLocalDateInput(value): string // "2024-03-25" (para input type=date)
toLocalTimeInput(value): string // "14:30" (para input type=time)
triggerDownload(blob, filename) // Descarga de archivos
```

---

## 21. Resumen de Principios de Diseño

1. **Paleta Forest Green como identidad**: Solo forest se usa activamente. Sage y earth están declaradas pero sin uso.
2. **Gradientes para profundidad**: En sidebar, headers de tabla, login, stat cards, headers de modales.
3. **Mobile-first**: Estilos base para mobile, `md:` para desktop.
4. **Consistencia en spacing**: Escala de 4px de Tailwind (4, 8, 12, 16, 20, 24).
5. **Componentes reusables**: Modales, toasts, combobox, confirm dialogs.
6. **Feedback visual constante**: Loading spinners, toasts, estados disabled.
7. **Accesibilidad**: Contraste WCAG AA, ARIA attributes, semantic HTML.
8. **Signals sobre RxJS**: Estado local con signals, HTTP con RxJS + takeUntilDestroyed.
9. **Standalone components**: Sin NgModules, lazy loading por ruta.
10. **OnPush change detection**: En todos los componentes.
11. **Inline SVG para iconos**: Heroicons 24px, colores heredados, sin librería externa.
12. **Border radius consistente**: `rounded-lg` (8px) para inputs/botones, `rounded-2xl` (16px) para cards/modales, `rounded-3xl` (24px) para login card.
13. **Sombras con tinte verde**: `shadow-nature` en lugar de sombras grises neutras.
14. **Clases de componente en `styles.css`**: Badges, botones, inputs, tablas, nav-items, stat-cards — todo centralizado en `@layer components`.
15. **`field-label` y `detail-chip` son component-level**: No globales, se repiten en cada componente que los necesita.
