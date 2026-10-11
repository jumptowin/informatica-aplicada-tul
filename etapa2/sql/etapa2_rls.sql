-- =====================================================================
-- Bicicletas compartidas - ETAPA 2 - Seguridad por filas (RLS) básica
-- Correr en Supabase > SQL Editor DESPUÉS de etapa2_crear_base.sql
-- (y de cargar los datos). Se puede volver a correr: primero borra las políticas.
--
-- Por qué: la aplicación usa la clave pública "anon", que cualquiera puede ver
-- en el navegador. Sin RLS, con esa clave se puede leer, modificar y BORRAR
-- todo. Con este script:
--   * RLS queda activado en las 12 tablas;
--   * el rol anon solo puede LEER todas las tablas que muestra la app;
--   * solo puede INSERTAR/MODIFICAR en las tablas donde la app registra
--     movimientos (bicicleta, viaje, reporte_falla, mantenimiento, repuesto,
--     consumo_repuesto, redistribucion, redistribucion_bicicleta);
--   * estacion, usuario, tarjeta y operario quedan de solo lectura;
--   * NADIE puede borrar desde la app (no hay política de DELETE).
-- Límite: sigue sin haber usuarios ni roles (usuario / operario / supervisor).
-- Para eso haría falta Supabase Auth y políticas por rol (mejora pendiente).
-- =====================================================================

-- 1) Activar RLS en todas las tablas
ALTER TABLE estacion                 ENABLE ROW LEVEL SECURITY;
ALTER TABLE bicicleta                ENABLE ROW LEVEL SECURITY;
ALTER TABLE usuario                  ENABLE ROW LEVEL SECURITY;
ALTER TABLE tarjeta                  ENABLE ROW LEVEL SECURITY;
ALTER TABLE operario                 ENABLE ROW LEVEL SECURITY;
ALTER TABLE viaje                    ENABLE ROW LEVEL SECURITY;
ALTER TABLE reporte_falla            ENABLE ROW LEVEL SECURITY;
ALTER TABLE mantenimiento            ENABLE ROW LEVEL SECURITY;
ALTER TABLE repuesto                 ENABLE ROW LEVEL SECURITY;
ALTER TABLE consumo_repuesto         ENABLE ROW LEVEL SECURITY;
ALTER TABLE redistribucion           ENABLE ROW LEVEL SECURITY;
ALTER TABLE redistribucion_bicicleta ENABLE ROW LEVEL SECURITY;

-- 2) Borrar políticas anteriores (para poder correr el script dos veces)
DO $$
DECLARE p record;
BEGIN
  FOR p IN SELECT policyname, tablename FROM pg_policies
           WHERE schemaname = 'public' AND policyname LIKE 'app_%' LOOP
    EXECUTE format('DROP POLICY %I ON public.%I', p.policyname, p.tablename);
  END LOOP;
END $$;

-- 3) LECTURA: la app muestra todas estas tablas
CREATE POLICY app_leer ON estacion                 FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY app_leer ON bicicleta                FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY app_leer ON usuario                  FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY app_leer ON tarjeta                  FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY app_leer ON operario                 FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY app_leer ON viaje                    FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY app_leer ON reporte_falla            FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY app_leer ON mantenimiento            FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY app_leer ON repuesto                 FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY app_leer ON consumo_repuesto         FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY app_leer ON redistribucion           FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY app_leer ON redistribucion_bicicleta FOR SELECT TO anon, authenticated USING (true);

-- 4) ALTA (INSERT): solo donde la app registra movimientos
CREATE POLICY app_alta ON bicicleta                FOR INSERT TO anon, authenticated WITH CHECK (true);  -- alta de bici
CREATE POLICY app_alta ON viaje                    FOR INSERT TO anon, authenticated WITH CHECK (fecha_hora_fin IS NULL);  -- un viaje nace abierto
CREATE POLICY app_alta ON reporte_falla            FOR INSERT TO anon, authenticated WITH CHECK (estado = 'ABIERTO');
CREATE POLICY app_alta ON mantenimiento            FOR INSERT TO anon, authenticated WITH CHECK (estado = 'PROGRAMADO');
CREATE POLICY app_alta ON repuesto                 FOR INSERT TO anon, authenticated WITH CHECK (true);
CREATE POLICY app_alta ON consumo_repuesto         FOR INSERT TO anon, authenticated WITH CHECK (true);
CREATE POLICY app_alta ON redistribucion           FOR INSERT TO anon, authenticated WITH CHECK (estado = 'PENDIENTE');
CREATE POLICY app_alta ON redistribucion_bicicleta FOR INSERT TO anon, authenticated WITH CHECK (true);

-- 5) CAMBIOS (UPDATE): estados, cierre de viajes, stock y órdenes
CREATE POLICY app_cambio ON bicicleta      FOR UPDATE TO anon, authenticated USING (true) WITH CHECK (true);
CREATE POLICY app_cambio ON viaje          FOR UPDATE TO anon, authenticated USING (fecha_hora_fin IS NULL) WITH CHECK (true);  -- solo se cierran viajes abiertos
CREATE POLICY app_cambio ON reporte_falla  FOR UPDATE TO anon, authenticated USING (true) WITH CHECK (true);
CREATE POLICY app_cambio ON mantenimiento  FOR UPDATE TO anon, authenticated USING (true) WITH CHECK (true);
CREATE POLICY app_cambio ON repuesto       FOR UPDATE TO anon, authenticated USING (true) WITH CHECK (true);  -- también lo usa el trigger de stock
CREATE POLICY app_cambio ON redistribucion FOR UPDATE TO anon, authenticated USING (estado <> 'COMPLETADA') WITH CHECK (true);

-- 6) Sin borrados ni vaciados desde la API
REVOKE TRUNCATE ON ALL TABLES IN SCHEMA public FROM anon, authenticated;

-- 7) Las vistas respetan RLS de quien consulta (sin esto, una vista se
--    ejecuta con los permisos de su dueño y "saltea" la seguridad).
ALTER VIEW v_disponibilidad_estacion   SET (security_invoker = true);
ALTER VIEW v_mantenimientos_pendientes SET (security_invoker = true);
ALTER VIEW v_repuestos_a_reponer       SET (security_invoker = true);
ALTER VIEW v_indicadores               SET (security_invoker = true);

-- 8) Control: debería listar 12 tablas con rowsecurity = true
SELECT tablename, rowsecurity FROM pg_tables WHERE schemaname = 'public' ORDER BY tablename;
