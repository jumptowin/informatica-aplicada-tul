-- ETAPA 2 - Datos ficticios (PARTE A, correr junta) y pruebas (PARTE B, una por vez: todas deben dar error)
-- ---------- PARTE A ----------
INSERT INTO estacion VALUES
 ('E01','Plaza Central 100',  6, -27.4690,-58.8300, 2, 5),
 ('E02','Av. Costanera 450',  4, -27.4600,-58.8400, 1, 3),
 ('E03','Terminal de Ómnibus',8, -27.4800,-58.8200, 2, 6);
INSERT INTO bicicleta (numero_serie, estado, codigo_estacion, fecha_alta) VALUES
 ('BK-0001','DISPONIBLE','E03','2025-03-01'),
 ('BK-0002','EN_USO','E01','2025-03-01'),
 ('BK-0003','EN_MANTENIMIENTO','E02','2025-05-10'),
 ('BK-0004','DISPONIBLE','E03','2025-05-10'),
 ('BK-0005','DISPONIBLE','E03','2026-01-15'),
 ('BK-0006','DISPONIBLE','E03','2026-01-15'),
 ('BK-0007','DISPONIBLE','E03','2026-01-15'),
 ('BK-0008','DISPONIBLE','E03','2026-01-15'),
 ('BK-0009','DISPONIBLE','E03','2026-01-15');
INSERT INTO usuario VALUES ('30111222','Ana Ficticia'), ('28999888','Bruno Inventado');
INSERT INTO tarjeta (dni_usuario, marca, ultimos_4_digitos, vencimiento) VALUES
 ('30111222','VISA','4242','08/28'), ('30111222','MASTERCARD','5555','01/27'), ('28999888','VISA','1111','12/29');
INSERT INTO operario VALUES (501,'Carla Técnica'), (502,'Diego Mecánico');
INSERT INTO viaje VALUES
 ('30111222','BK-0001','2026-10-10 09:00-03','2026-10-10 09:25-03','E01','E03',1),
 ('30111222','BK-0003','2026-10-10 17:00-03','2026-10-10 17:40-03','E03','E02',2),
 ('28999888','BK-0002','2026-10-11 18:00-03',NULL,'E01',NULL,3);
INSERT INTO reporte_falla (dni_usuario, numero_serie, fecha_hora_inicio, descripcion)
VALUES ('30111222','BK-0003','2026-10-10 17:00-03','Freno trasero no frena');
INSERT INTO repuesto VALUES ('R-FRENO','Pastilla de freno',10,4), ('R-CAMARA','Cámara 26"',3,3);
INSERT INTO mantenimiento (fecha, descripcion, codigo_estacion, legajo_operario, tipo, estado, numero_serie) VALUES
 ('2026-10-12','Cambio de pastillas de freno','E02',501,'CORRECTIVO','PROGRAMADO','BK-0003'),
 ('2026-10-15','Revisión de anclajes','E02',502,'PREVENTIVO','PROGRAMADO',NULL);
INSERT INTO consumo_repuesto VALUES (1,'R-FRENO',2);
INSERT INTO redistribucion (codigo_estacion_desde, codigo_estacion_hacia, legajo_operario, estado)
VALUES ('E03','E01',502,'PENDIENTE');
INSERT INTO redistribucion_bicicleta VALUES (1,'BK-0008'), (1,'BK-0009');

SELECT * FROM v_disponibilidad_estacion ORDER BY codigo;
SELECT * FROM v_repuestos_a_reponer;
SELECT * FROM v_mantenimientos_pendientes;
SELECT * FROM v_indicadores;

-- ---------- PARTE B: deben dar ERROR ----------
-- B1 usar más repuestos que el stock (R-CAMARA tiene 3)
INSERT INTO consumo_repuesto VALUES (2,'R-CAMARA',5);
-- B2 redistribución desde y hacia la misma estación
INSERT INTO redistribucion (codigo_estacion_desde, codigo_estacion_hacia, legajo_operario) VALUES ('E01','E01',501);
-- B3 umbral máximo mayor que la capacidad
INSERT INTO estacion VALUES ('E09','Prueba',4,NULL,NULL,1,9);
-- B4 reporte de falla de un viaje que no existe
INSERT INTO reporte_falla (dni_usuario, numero_serie, fecha_hora_inicio, descripcion) VALUES ('30111222','BK-0004','2026-01-01 10:00-03','x');
-- B5 tipo de mantenimiento no permitido
INSERT INTO mantenimiento (fecha, descripcion, codigo_estacion, legajo_operario, tipo) VALUES ('2026-10-20','x','E01',501,'URGENTE');
