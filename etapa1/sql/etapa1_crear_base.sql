-- =====================================================================
-- Bicicletas compartidas - ETAPA 1 - Script de creación (PostgreSQL / Supabase)
-- Correr completo en Supabase > SQL Editor > New query > Run.
-- Solo datos ficticios. Se puede volver a correr: primero borra las tablas.
-- =====================================================================
DROP TABLE IF EXISTS viaje, mantenimiento, tarjeta, bicicleta, operario, usuario, estacion CASCADE;
DROP FUNCTION IF EXISTS controlar_capacidad_estacion() CASCADE;

-- ESTACION (entidad fuerte)
CREATE TABLE estacion (
  codigo         VARCHAR(10)  PRIMARY KEY,
  direccion      VARCHAR(150) NOT NULL,
  capacidad_max  INTEGER      NOT NULL CHECK (capacidad_max > 0)
);

-- BICICLETA (fuerte). N:1 con ESTACION -> FK en bicicleta (lado N), obligatoria
CREATE TABLE bicicleta (
  numero_serie     VARCHAR(30) PRIMARY KEY,
  estado           VARCHAR(20) NOT NULL DEFAULT 'DISPONIBLE'
                   CHECK (estado IN ('DISPONIBLE','EN_USO','EN_MANTENIMIENTO')),
  codigo_estacion  VARCHAR(10) NOT NULL REFERENCES estacion(codigo)
);

-- USUARIO (fuerte)
CREATE TABLE usuario (
  dni     VARCHAR(8)   PRIMARY KEY CHECK (dni ~ '^[0-9]{7,8}$'),
  nombre  VARCHAR(120) NOT NULL
);

-- TARJETA (medio de pago). N:1 con USUARIO. Nunca se guarda el número completo.
CREATE TABLE tarjeta (
  id_tarjeta         INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  dni_usuario        VARCHAR(8) NOT NULL REFERENCES usuario(dni) ON DELETE CASCADE,
  marca              VARCHAR(30) NOT NULL,
  ultimos_4_digitos  CHAR(4)    NOT NULL CHECK (ultimos_4_digitos ~ '^[0-9]{4}$'),
  vencimiento        CHAR(5)    NOT NULL CHECK (vencimiento ~ '^(0[1-9]|1[0-2])/[0-9]{2}$'),
  UNIQUE (id_tarjeta, dni_usuario)   -- permite exigir que el viaje se pague con una tarjeta del mismo usuario
);

-- OPERARIO TÉCNICO (fuerte)
CREATE TABLE operario (
  legajo  INTEGER      PRIMARY KEY CHECK (legajo > 0),
  nombre  VARCHAR(120) NOT NULL
);

-- VIAJE (entidad débil de USUARIO y BICICLETA)
-- PK = PK de las dueñas (dni_usuario, numero_serie) + clave parcial (fecha_hora_inicio)
CREATE TABLE viaje (
  dni_usuario              VARCHAR(8)  NOT NULL REFERENCES usuario(dni),
  numero_serie             VARCHAR(30) NOT NULL REFERENCES bicicleta(numero_serie),
  fecha_hora_inicio        TIMESTAMPTZ NOT NULL,
  fecha_hora_fin           TIMESTAMPTZ,                       -- NULL = viaje en curso
  codigo_estacion_origen   VARCHAR(10) NOT NULL REFERENCES estacion(codigo),
  codigo_estacion_destino  VARCHAR(10)          REFERENCES estacion(codigo), -- NULL mientras está en curso
  id_tarjeta               INTEGER     NOT NULL,
  PRIMARY KEY (dni_usuario, numero_serie, fecha_hora_inicio),
  FOREIGN KEY (id_tarjeta, dni_usuario) REFERENCES tarjeta(id_tarjeta, dni_usuario),
  CHECK (fecha_hora_fin IS NULL OR fecha_hora_fin > fecha_hora_inicio),
  CHECK ((fecha_hora_fin IS NULL) = (codigo_estacion_destino IS NULL))
);
-- Una bicicleta no puede estar en dos viajes abiertos a la vez, ni un usuario tampoco
CREATE UNIQUE INDEX un_viaje_abierto_por_bici    ON viaje (numero_serie) WHERE fecha_hora_fin IS NULL;
CREATE UNIQUE INDEX un_viaje_abierto_por_usuario ON viaje (dni_usuario)  WHERE fecha_hora_fin IS NULL;

-- MANTENIMIENTO (tarea programada). N:1 con ESTACION y N:1 con OPERARIO, ambas obligatorias
CREATE TABLE mantenimiento (
  id_mantenimiento  INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  fecha             DATE    NOT NULL,
  descripcion       TEXT    NOT NULL,
  codigo_estacion   VARCHAR(10) NOT NULL REFERENCES estacion(codigo),
  legajo_operario   INTEGER     NOT NULL REFERENCES operario(legajo)
);

-- Regla: una estación no puede tener más bicicletas que su capacidad_max
CREATE FUNCTION controlar_capacidad_estacion() RETURNS trigger AS $$
BEGIN
  IF (SELECT COUNT(*) FROM bicicleta WHERE codigo_estacion = NEW.codigo_estacion)
     > (SELECT capacidad_max FROM estacion WHERE codigo = NEW.codigo_estacion) THEN
    RAISE EXCEPTION 'La estacion % supera su capacidad maxima', NEW.codigo_estacion;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_capacidad_estacion
AFTER INSERT OR UPDATE OF codigo_estacion ON bicicleta
FOR EACH ROW EXECUTE FUNCTION controlar_capacidad_estacion();
