-- =====================================================================
-- ETAPA 1 - Datos ficticios (PARTE A) y pruebas (PARTE B)
-- PARTE A: correr toda junta. Tiene que terminar "Success".
-- PARTE B: correr cada prueba POR SEPARADO (seleccionar la línea y Run).
--          Cada una TIENE QUE DAR ERROR: eso demuestra que la base respeta las reglas.
-- =====================================================================

-- ---------- PARTE A: datos válidos ----------
INSERT INTO estacion (codigo, direccion, capacidad_max) VALUES
 ('E01','Plaza Central 100', 3),
 ('E02','Av. Costanera 450', 2),
 ('E03','Terminal de Ómnibus', 4);

INSERT INTO bicicleta (numero_serie, estado, codigo_estacion) VALUES
 ('BK-0001','DISPONIBLE','E03'),   -- terminó un viaje en E03
 ('BK-0002','EN_USO','E01'),       -- está en un viaje en curso que salió de E01
 ('BK-0003','EN_MANTENIMIENTO','E02'),
 ('BK-0004','DISPONIBLE','E03');

INSERT INTO usuario (dni, nombre) VALUES
 ('30111222','Ana Ficticia'),
 ('28999888','Bruno Inventado');

INSERT INTO tarjeta (dni_usuario, marca, ultimos_4_digitos, vencimiento) VALUES
 ('30111222','VISA','4242','08/28'),    -- id 1
 ('30111222','MASTERCARD','5555','01/27'), -- id 2
 ('28999888','VISA','1111','12/29');    -- id 3

INSERT INTO operario (legajo, nombre) VALUES (501,'Carla Técnica'), (502,'Diego Mecánico');

-- un viaje terminado y uno en curso
INSERT INTO viaje (dni_usuario, numero_serie, fecha_hora_inicio, fecha_hora_fin,
                   codigo_estacion_origen, codigo_estacion_destino, id_tarjeta) VALUES
 ('30111222','BK-0001','2026-10-10 09:00-03','2026-10-10 09:25-03','E01','E03',1),
 ('28999888','BK-0002','2026-10-11 18:00-03', NULL,                  'E01', NULL, 3);

INSERT INTO mantenimiento (fecha, descripcion, codigo_estacion, legajo_operario) VALUES
 ('2026-10-15','Revisión de anclajes','E02',501),
 ('2026-10-20','Cambio de cámara BK-0003','E02',502);

-- Consultas para mirar el resultado
SELECT * FROM viaje;
SELECT e.codigo, e.capacidad_max, COUNT(b.numero_serie) AS bicis_en_estacion
FROM estacion e LEFT JOIN bicicleta b ON b.codigo_estacion = e.codigo
GROUP BY e.codigo, e.capacidad_max ORDER BY e.codigo;

-- ---------- PARTE B: pruebas que DEBEN FALLAR (una por vez) ----------
-- B1 estado no permitido
INSERT INTO bicicleta VALUES ('BK-0099','ROTA','E01');
-- B2 estación inexistente (integridad referencial)
INSERT INTO bicicleta VALUES ('BK-0098','DISPONIBLE','E99');
-- B3 supera capacidad (E02 tiene capacidad 2 y ya tiene 1: no entran 2 más)
INSERT INTO bicicleta VALUES ('BK-0097','DISPONIBLE','E02'), ('BK-0096','DISPONIBLE','E02');
-- B4 viaje sin usuario (no existe el DNI): un viaje no existe sin el usuario
INSERT INTO viaje VALUES ('99999999','BK-0004','2026-10-11 10:00-03',NULL,'E03',NULL,1);
-- B5 viaje con fin anterior al inicio
INSERT INTO viaje VALUES ('30111222','BK-0004','2026-10-11 10:00-03','2026-10-11 09:00-03','E03','E01',1);
-- B6 pagar con la tarjeta de OTRO usuario (tarjeta 3 es de Bruno)
INSERT INTO viaje VALUES ('30111222','BK-0004','2026-10-11 11:00-03',NULL,'E03',NULL,3);
-- B7 la bici BK-0002 ya está en un viaje abierto
INSERT INTO viaje VALUES ('30111222','BK-0002','2026-10-11 18:30-03',NULL,'E01',NULL,1);
-- B8 mantenimiento sin operario
INSERT INTO mantenimiento (fecha, descripcion, codigo_estacion, legajo_operario) VALUES ('2026-10-30','Limpieza','E01',NULL);
-- B9 DNI con letras
INSERT INTO usuario VALUES ('12AB5678','Prueba Mal');
-- B10 borrar una estación que tiene bicicletas (no se permite dejar bicis "huérfanas")
DELETE FROM estacion WHERE codigo = 'E01';
