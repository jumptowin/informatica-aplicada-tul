-- =====================================================================
-- Bicicletas compartidas - ETAPA 2 - Script COMPLETO (recrea la base desde cero)
-- PostgreSQL / Supabase SQL Editor. Solo datos ficticios.
-- Decisión: se recrea desde cero porque la base de la Etapa 1 solo tiene datos de prueba.
-- (Si hubiera datos reales habría que usar ALTER TABLE para no perderlos.)
-- =====================================================================
DROP VIEW  IF EXISTS v_disponibilidad_estacion, v_repuestos_a_reponer, v_mantenimientos_pendientes, v_indicadores CASCADE;
DROP TABLE IF EXISTS redistribucion_bicicleta, redistribucion, consumo_repuesto, repuesto,
                     reporte_falla, viaje, mantenimiento, tarjeta, bicicleta, operario, usuario, estacion CASCADE;
DROP FUNCTION IF EXISTS controlar_capacidad_estacion() CASCADE;
DROP FUNCTION IF EXISTS descontar_stock_repuesto() CASCADE;

CREATE TABLE estacion (
  codigo         VARCHAR(10)  PRIMARY KEY,
  direccion      VARCHAR(150) NOT NULL,
  capacidad_max  INTEGER      NOT NULL CHECK (capacidad_max > 0),
  latitud        NUMERIC(9,6),                                   -- NUEVO
  longitud       NUMERIC(9,6),                                   -- NUEVO
  umbral_minimo  INTEGER NOT NULL DEFAULT 1,                     -- NUEVO: menos bicis que esto = alerta "vacía"
  umbral_maximo  INTEGER,                                        -- NUEVO: más bicis que esto = alerta "llena"
  CHECK (umbral_minimo >= 0 AND (umbral_maximo IS NULL OR (umbral_maximo <= capacidad_max AND umbral_maximo >= umbral_minimo)))
);

CREATE TABLE bicicleta (
  numero_serie     VARCHAR(30) PRIMARY KEY,
  estado           VARCHAR(20) NOT NULL DEFAULT 'DISPONIBLE'
                   CHECK (estado IN ('DISPONIBLE','EN_USO','EN_MANTENIMIENTO','EN_TRASLADO')),  -- MODIFICADO
  codigo_estacion  VARCHAR(10) NOT NULL REFERENCES estacion(codigo),
  fecha_alta       DATE NOT NULL DEFAULT CURRENT_DATE                                        -- NUEVO
);

CREATE TABLE usuario (
  dni     VARCHAR(8)   PRIMARY KEY CHECK (dni ~ '^[0-9]{7,8}$'),
  nombre  VARCHAR(120) NOT NULL
);

CREATE TABLE tarjeta (
  id_tarjeta         INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  dni_usuario        VARCHAR(8) NOT NULL REFERENCES usuario(dni) ON DELETE CASCADE,
  marca              VARCHAR(30) NOT NULL,
  ultimos_4_digitos  CHAR(4) NOT NULL CHECK (ultimos_4_digitos ~ '^[0-9]{4}$'),
  vencimiento        CHAR(5) NOT NULL CHECK (vencimiento ~ '^(0[1-9]|1[0-2])/[0-9]{2}$'),
  UNIQUE (id_tarjeta, dni_usuario)
);

CREATE TABLE operario (
  legajo  INTEGER PRIMARY KEY CHECK (legajo > 0),
  nombre  VARCHAR(120) NOT NULL
);

CREATE TABLE viaje (
  dni_usuario              VARCHAR(8)  NOT NULL REFERENCES usuario(dni),
  numero_serie             VARCHAR(30) NOT NULL REFERENCES bicicleta(numero_serie),
  fecha_hora_inicio        TIMESTAMPTZ NOT NULL,
  fecha_hora_fin           TIMESTAMPTZ,
  codigo_estacion_origen   VARCHAR(10) NOT NULL REFERENCES estacion(codigo),
  codigo_estacion_destino  VARCHAR(10) REFERENCES estacion(codigo),
  id_tarjeta               INTEGER NOT NULL,
  PRIMARY KEY (dni_usuario, numero_serie, fecha_hora_inicio),
  FOREIGN KEY (id_tarjeta, dni_usuario) REFERENCES tarjeta(id_tarjeta, dni_usuario),
  CHECK (fecha_hora_fin IS NULL OR fecha_hora_fin > fecha_hora_inicio),
  CHECK ((fecha_hora_fin IS NULL) = (codigo_estacion_destino IS NULL))
);
CREATE UNIQUE INDEX un_viaje_abierto_por_bici    ON viaje (numero_serie) WHERE fecha_hora_fin IS NULL;
CREATE UNIQUE INDEX un_viaje_abierto_por_usuario ON viaje (dni_usuario)  WHERE fecha_hora_fin IS NULL;

-- NUEVA: reporte de falla hecho por el usuario al terminar un viaje (N:1 con VIAJE)
CREATE TABLE reporte_falla (
  id_reporte         INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  dni_usuario        VARCHAR(8)  NOT NULL,
  numero_serie       VARCHAR(30) NOT NULL,
  fecha_hora_inicio  TIMESTAMPTZ NOT NULL,
  fecha_hora         TIMESTAMPTZ NOT NULL DEFAULT now(),
  descripcion        TEXT NOT NULL,
  estado             VARCHAR(10) NOT NULL DEFAULT 'ABIERTO' CHECK (estado IN ('ABIERTO','RESUELTO')),
  FOREIGN KEY (dni_usuario, numero_serie, fecha_hora_inicio)
    REFERENCES viaje(dni_usuario, numero_serie, fecha_hora_inicio)
);

-- MODIFICADA: tipo, estado y bicicleta (opcional)
CREATE TABLE mantenimiento (
  id_mantenimiento  INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  fecha             DATE NOT NULL,
  descripcion       TEXT NOT NULL,
  codigo_estacion   VARCHAR(10) NOT NULL REFERENCES estacion(codigo),
  legajo_operario   INTEGER     NOT NULL REFERENCES operario(legajo),
  tipo              VARCHAR(12) NOT NULL DEFAULT 'PREVENTIVO' CHECK (tipo IN ('PREVENTIVO','CORRECTIVO')),   -- NUEVO
  estado            VARCHAR(12) NOT NULL DEFAULT 'PROGRAMADO' CHECK (estado IN ('PROGRAMADO','REALIZADO')),  -- NUEVO
  numero_serie      VARCHAR(30) REFERENCES bicicleta(numero_serie)                                          -- NUEVO (NULL = tarea de la estación)
);

-- NUEVAS: repuestos y su consumo (N:M MANTENIMIENTO-REPUESTO con atributo cantidad)
CREATE TABLE repuesto (
  codigo_repuesto  VARCHAR(20) PRIMARY KEY,
  descripcion      VARCHAR(120) NOT NULL,
  stock_actual     INTEGER NOT NULL DEFAULT 0 CHECK (stock_actual >= 0),
  stock_minimo     INTEGER NOT NULL DEFAULT 0 CHECK (stock_minimo >= 0)
);
CREATE TABLE consumo_repuesto (
  id_mantenimiento  INTEGER     NOT NULL REFERENCES mantenimiento(id_mantenimiento) ON DELETE CASCADE,
  codigo_repuesto   VARCHAR(20) NOT NULL REFERENCES repuesto(codigo_repuesto),
  cantidad          INTEGER     NOT NULL CHECK (cantidad > 0),
  PRIMARY KEY (id_mantenimiento, codigo_repuesto)
);

-- NUEVAS: redistribución de flota (orden de traslado) y bicis trasladadas (N:M)
CREATE TABLE redistribucion (
  id_redistribucion       INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  codigo_estacion_desde   VARCHAR(10) NOT NULL REFERENCES estacion(codigo),
  codigo_estacion_hacia   VARCHAR(10) NOT NULL REFERENCES estacion(codigo),
  legajo_operario         INTEGER     NOT NULL REFERENCES operario(legajo),
  fecha_hora_salida       TIMESTAMPTZ,
  fecha_hora_llegada      TIMESTAMPTZ,
  estado                  VARCHAR(12) NOT NULL DEFAULT 'PENDIENTE' CHECK (estado IN ('PENDIENTE','EN_CURSO','COMPLETADA')),
  CHECK (codigo_estacion_desde <> codigo_estacion_hacia),
  CHECK (fecha_hora_llegada IS NULL OR fecha_hora_llegada > fecha_hora_salida)
);
CREATE TABLE redistribucion_bicicleta (
  id_redistribucion  INTEGER     NOT NULL REFERENCES redistribucion(id_redistribucion) ON DELETE CASCADE,
  numero_serie       VARCHAR(30) NOT NULL REFERENCES bicicleta(numero_serie),
  PRIMARY KEY (id_redistribucion, numero_serie)
);

-- Regla de capacidad (igual que Etapa 1)
CREATE FUNCTION controlar_capacidad_estacion() RETURNS trigger AS $$
BEGIN
  IF (SELECT COUNT(*) FROM bicicleta WHERE codigo_estacion = NEW.codigo_estacion)
     > (SELECT capacidad_max FROM estacion WHERE codigo = NEW.codigo_estacion) THEN
    RAISE EXCEPTION 'La estacion % supera su capacidad maxima', NEW.codigo_estacion;
  END IF;
  RETURN NEW;
END; $$ LANGUAGE plpgsql;
CREATE TRIGGER trg_capacidad_estacion AFTER INSERT OR UPDATE OF codigo_estacion ON bicicleta
FOR EACH ROW EXECUTE FUNCTION controlar_capacidad_estacion();

-- Regla: usar un repuesto descuenta stock (y falla si no alcanza, por el CHECK stock_actual >= 0)
CREATE FUNCTION descontar_stock_repuesto() RETURNS trigger AS $$
BEGIN
  UPDATE repuesto SET stock_actual = stock_actual - NEW.cantidad WHERE codigo_repuesto = NEW.codigo_repuesto;
  RETURN NEW;
END; $$ LANGUAGE plpgsql;
CREATE TRIGGER trg_descontar_stock AFTER INSERT ON consumo_repuesto
FOR EACH ROW EXECUTE FUNCTION descontar_stock_repuesto();

-- ===== Vistas para las funciones logísticas =====
-- F1 Disponibilidad y alertas por estación
CREATE VIEW v_disponibilidad_estacion AS
SELECT e.codigo, e.direccion, e.capacidad_max, e.umbral_minimo, e.umbral_maximo,
       COUNT(b.numero_serie) FILTER (WHERE b.estado = 'DISPONIBLE') AS bicis_disponibles,
       COUNT(b.numero_serie)                                         AS bicis_asignadas,
       CASE WHEN COUNT(b.numero_serie) FILTER (WHERE b.estado='DISPONIBLE') < e.umbral_minimo THEN 'VACIA'
            WHEN e.umbral_maximo IS NOT NULL AND COUNT(b.numero_serie) > e.umbral_maximo THEN 'LLENA'
            ELSE 'OK' END AS alerta
FROM estacion e LEFT JOIN bicicleta b ON b.codigo_estacion = e.codigo
GROUP BY e.codigo;
-- F3 Mantenimientos pendientes
CREATE VIEW v_mantenimientos_pendientes AS
SELECT m.*, o.nombre AS operario FROM mantenimiento m JOIN operario o ON o.legajo = m.legajo_operario
WHERE m.estado = 'PROGRAMADO' ORDER BY m.fecha;
-- F4 Repuestos a reponer
CREATE VIEW v_repuestos_a_reponer AS
SELECT * FROM repuesto WHERE stock_actual <= stock_minimo;
-- F5 Indicadores
CREATE VIEW v_indicadores AS
SELECT
  (SELECT COUNT(*) FROM viaje WHERE fecha_hora_fin IS NOT NULL)                                   AS viajes_terminados,
  (SELECT ROUND(AVG(EXTRACT(EPOCH FROM (fecha_hora_fin - fecha_hora_inicio))/60)::numeric,1)
     FROM viaje WHERE fecha_hora_fin IS NOT NULL)                                                 AS duracion_promedio_min,
  (SELECT ROUND(100.0*COUNT(*) FILTER (WHERE estado='EN_MANTENIMIENTO')/NULLIF(COUNT(*),0),1) FROM bicicleta) AS pct_flota_en_mantenimiento,
  (SELECT COUNT(*) FROM v_disponibilidad_estacion WHERE alerta <> 'OK')                            AS estaciones_con_alerta,
  (SELECT COUNT(*) FROM reporte_falla WHERE estado='ABIERTO')                                      AS fallas_abiertas;
