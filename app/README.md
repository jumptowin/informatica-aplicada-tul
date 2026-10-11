# BiciTUL — aplicación web (Etapa 2)

Aplicación web de la empresa ficticia de bicicletas compartidas del trabajo práctico de
**Informática Aplicada** (UTN FRRe, Tecnicatura Universitaria en Logística, Extensión Ituzaingó).
Alumno: Santiago T. Sala (legajo 30794). Todos los datos son ficticios.

Publicada en: https://bicicletas-compartidas.vercel.app

## Qué hace (funciones logísticas)

| Pantalla | Función | Qué se puede hacer |
|---|---|---|
| Panel | F5 Indicadores | Viajes terminados y en curso, duración promedio, % de flota en mantenimiento, estaciones con alerta, fallas abiertas, repuestos a reponer y tareas pendientes |
| Estaciones | F1 Disponibilidad y alertas | Bicis disponibles y asignadas por estación, capacidad, umbrales y alerta VACIA / OK / LLENA |
| Bicicletas | Estados de la flota | Lista con filtro por estado y alta de bicicletas |
| Viajes | Retiro y devolución | Iniciar un viaje (bici DISPONIBLE → EN_USO) y terminarlo en otra estación; si se informa una falla se crea el reporte y un mantenimiento CORRECTIVO |
| Redistribución | F2 Redistribución de flota | Crear órdenes de traslado (sugiere de una estación LLENA a una VACIA), registrar salida (EN_TRASLADO) y llegada (cambia de estación, DISPONIBLE) |
| Mantenimiento | F3 Mantenimiento y fallas | Tareas pendientes, programar preventivos/correctivos, marcar realizado (la bici vuelve a DISPONIBLE y el reporte queda RESUELTO) |
| Repuestos | F4 Control de repuestos | Stock y alerta REPONER, registrar repuestos usados (la base descuenta el stock), ingreso de stock y alta de repuestos |

Las reglas importantes las controla la **base de datos** (no la app): capacidad máxima de cada
estación, estados permitidos, stock que no puede quedar negativo, un solo viaje abierto por bici y
por usuario, traslados entre estaciones distintas. La app muestra esos errores en castellano.

## Cómo está hecha

- `index.html` — la página y el menú.
- `css/estilos.css` — estilo blanco y negro, pensado primero para el celular.
- `js/app.js` — una función por pantalla; usa la librería `supabase-js` (se carga desde un CDN).
- `config.js` — URL de Supabase y clave **anon** (pública). `config.example.js` es la plantilla.
- `generar_config.sh` — arma `config.js` a partir de variables de entorno o de un archivo `.env`.

No hay que instalar nada ni compilar: son archivos estáticos.

## Variables de entorno

| Variable | Qué es |
|---|---|
| `SUPABASE_URL` | URL del proyecto (Supabase → Project Settings → API) |
| `SUPABASE_ANON_KEY` | Clave pública *anon* / *publishable*. Nunca usar la `service_role` |

`.env.example` tiene los nombres sin valores. El `.env` real no se sube (está en `.gitignore`).
La clave anon es pública por diseño (el navegador la ve igual); lo que protege la base es RLS.

## Base de datos

1. En Supabase → SQL Editor correr `etapa2_crear_base.sql` y la Parte A de `etapa2_datos_y_pruebas.sql`.
2. Correr `etapa2_rls.sql` (activa Row Level Security: lectura de todo, alta y cambios solo donde
   la app registra movimientos, sin borrados).

## Probarla en la computadora

Abrir una terminal en esta carpeta y ejecutar `python3 -m http.server 8000`; después entrar a
http://localhost:8000 (hace falta un servidor; abrir el archivo con doble clic no alcanza).

## Publicarla en Vercel

Vercel → Add New → Project → importar el repositorio → **Root Directory: `app`** →
Framework Preset: *Other*, sin Build Command → Deploy. Si se prefiere no subir `config.js`,
cargar `SUPABASE_URL` y `SUPABASE_ANON_KEY` en Environment Variables y poner como
Build Command `sh generar_config.sh`.

## Pendiente

- Inicio de sesión y permisos por rol (usuario / operario / supervisor) con Supabase Auth.
- Pasar las operaciones de varios pasos (por ejemplo, devolver una bici y cerrar el viaje) a
  funciones de la base para que sean una sola transacción.
