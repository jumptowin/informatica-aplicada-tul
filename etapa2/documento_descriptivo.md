# Documento descriptivo del negocio — BiciTUL

Texto que usé como prompt para generar el MR, el SQL y la aplicación (Etapa 2). Datos ficticios.

**Contexto de la empresa.** BiciTUL (nombre ficticio) es una empresa de bicicletas compartidas en una ciudad mediana del NEA. Tiene estaciones fijas con anclajes en lugares de mucho movimiento (plaza central, costanera, terminal). Los usuarios registrados retiran una bicicleta en una estación y la devuelven en cualquier otra. Los problemas logísticos son:

- estaciones que se vacían (sobre todo a la mañana, en los barrios) o se llenan (en el centro);
- bicicletas con fallas que se siguen prestando;
- reparaciones que se demoran por falta de repuestos;
- ninguna medición de cómo funciona la operación.

**Actores y roles.**

1. *Usuario:* se registra, carga sus tarjetas, ve la disponibilidad, inicia y termina viajes y reporta fallas.
2. *Operario técnico:* ve sus tareas de mantenimiento y sus órdenes de traslado, las marca como hechas y registra los repuestos que usó.
3. *Supervisor de operaciones:* administra estaciones, bicicletas, operarios y repuestos, crea órdenes de traslado, programa mantenimientos y ve los indicadores.

**Datos del negocio (según el MER de la Etapa 2).**

- ESTACION (codigo, direccion, capacidad_max, latitud, longitud, umbral_minimo, umbral_maximo).
- BICICLETA (numero_serie, estado: DISPONIBLE / EN_USO / EN_MANTENIMIENTO / EN_TRASLADO, fecha_alta, estación actual).
- USUARIO (dni, nombre).
- TARJETA (id, marca, últimos 4 dígitos, vencimiento; pertenece a un usuario).
- VIAJE (usuario, bicicleta, fecha_hora_inicio, fecha_hora_fin, estación de origen, estación de destino, tarjeta).
- REPORTE_FALLA (id, viaje, fecha_hora, descripción, estado ABIERTO / RESUELTO).
- MANTENIMIENTO (id, fecha, descripción, estación, operario, tipo PREVENTIVO / CORRECTIVO, estado PROGRAMADO / REALIZADO, bicicleta opcional).
- REPUESTO (código, descripción, stock_actual, stock_minimo).
- CONSUMO_REPUESTO (mantenimiento, repuesto, cantidad).
- REDISTRIBUCION (id, estación de salida, estación de llegada, operario, hora de salida, hora de llegada, estado).
- REDISTRIBUCION_BICICLETA (redistribución, bicicleta).

**Funciones logísticas.**

- **F1 Disponibilidad y alertas:** para cada estación se cuentan las bicis disponibles y las asignadas. La estación está VACIA si las disponibles son menos que el umbral mínimo, y LLENA si las asignadas superan el umbral máximo.
- **F2 Redistribución:**
  - El supervisor crea una orden desde una estación LLENA hacia una VACIA, y elige las bicis y el operario.
  - Al salir, las bicis pasan a EN_TRASLADO.
  - Al llegar, cambian de estación y vuelven a DISPONIBLE.
- **F3 Mantenimiento:**
  - Un reporte de falla genera un mantenimiento CORRECTIVO para esa bici, y la bici pasa a EN_MANTENIMIENTO.
  - Los mantenimientos PREVENTIVOS los programa el supervisor.
  - Cuando un mantenimiento se marca REALIZADO, la bici vuelve a DISPONIBLE y el reporte pasa a RESUELTO.
- **F4 Repuestos:** al registrar un consumo se descuenta el stock. Si el stock queda igual o por debajo del mínimo, el repuesto aparece en la lista "a reponer".
- **F5 Indicadores:** tablero con los indicadores de la tabla del punto 1.

**Reglas del negocio.**

- Una estación nunca supera su capacidad máxima.
- Una bici solo se puede retirar si está DISPONIBLE.
- Una bici, o un usuario, no pueden tener dos viajes abiertos al mismo tiempo.
- El viaje termina después de empezar y se paga con una tarjeta del mismo usuario.
- Nunca se guarda el número completo de la tarjeta.
- El stock de repuestos no puede ser negativo.
- Un traslado no puede ir de una estación a la misma estación.
- Solo el supervisor da de alta estaciones, bicis, operarios y repuestos.
- El operario solo modifica sus propias tareas.
- El usuario solo ve y modifica sus datos y sus viajes.

**Pantallas y reportes.**

- *Usuario:* lista o mapa de estaciones con disponibilidad, retirar bici, devolver bici, mis viajes y reportar falla.
- *Operario:* mis tareas (mantenimientos y traslados) y registro de repuestos usados.
- *Supervisor:* altas, bajas y cambios de estaciones, bicis, operarios y repuestos; alertas por estación; crear orden de traslado; programar mantenimiento; repuestos a reponer; indicadores.

**Datos de ejemplo.**

- 3 estaciones: E01 Plaza Central (capacidad 6), E02 Costanera (capacidad 4) y E03 Terminal (capacidad 8).
- 9 bicis, 7 de ellas en E03 (por eso E03 queda LLENA y E01 VACIA).
- 2 usuarios ficticios con 3 tarjetas.
- 3 viajes (uno en curso).
- 1 reporte de falla, 2 mantenimientos, 2 repuestos y 1 orden de traslado.

Están en sql/etapa2_datos_y_pruebas.sql.

**Requisitos técnicos.**

- Aplicación web que se pueda usar desde el celular.
- Conectada a una base PostgreSQL en Supabase, creada con sql/etapa2_crear_base.sql.
- Pensada para publicarse en Vercel (por ejemplo, Next.js con supabase-js).
- Las credenciales van en variables de entorno (NEXT_PUBLIC_SUPABASE_URL y NEXT_PUBLIC_SUPABASE_ANON_KEY), nunca en el código.
- Permisos por rol con Row Level Security de Supabase.
- Pantallas en español.

