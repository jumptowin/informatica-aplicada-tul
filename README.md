# Informática Aplicada — TUL Ituzaingó

**UTN FRRe** · Tecnicatura Universitaria en Logística, Extensión Ituzaingó (Corrientes)  
**Materia:** Informática Aplicada · **Profesor:** Ing. Juan Manuel Goya  
**Alumno:** Santiago T. Sala · **Legajo:** 30794

Trabajo práctico sobre una empresa ficticia de bicicletas compartidas (BiciTUL): del problema escrito
a la base de datos en Supabase (Etapa 1) y a una aplicación web publicada en Vercel (Etapa 2).
Todos los datos son ficticios.

**Aplicación publicada:** https://bicicletas-compartidas.vercel.app

## Contenido

| Carpeta / archivo | Qué hay |
|---|---|
| `etapa1/` | Entrega de la Etapa 1: PDF, MER y diagrama logístico (.drawio y .png), SQL y capturas de Supabase |
| `etapa2/Etapa2_Bicicletas.pdf` | Entrega de la Etapa 2: funciones logísticas, documento descriptivo, nuevo MER, MR y SQL con IA, aplicación |
| `etapa2/documento_descriptivo.md` | El documento descriptivo del negocio (el prompt usado para la IA) |
| `etapa2/bicicletas_MER_etapa2.drawio` y `.png` | MER actualizado, con lo nuevo marcado |
| `etapa2/sql/` | `etapa2_crear_base.sql`, `etapa2_datos_y_pruebas.sql` y `etapa2_rls.sql` (seguridad por filas) |
| `etapa2/capturas/` | Capturas de Supabase y de la aplicación (escritorio y celular) |
| `app/` | Código de la aplicación web (HTML, CSS y JavaScript con supabase-js). Ver `app/README.md` |

La carpeta `etapa2/` cumple el papel de la carpeta *docs* que pide la consigna.

## Aplicación (resumen)

Funciones logísticas que cubre: disponibilidad y alertas por estación (F1), redistribución de flota (F2),
mantenimiento y reportes de falla (F3), control de repuestos (F4) e indicadores (F5), además del retiro
y la devolución de bicicletas.

Variables de entorno: `SUPABASE_URL` y `SUPABASE_ANON_KEY` (clave pública *anon*). Ver `app/.env.example`.
Nunca se suben claves secretas; el archivo `.env` está excluido en `.gitignore`.

Para publicarla en Vercel: importar este repositorio y elegir **Root Directory = `app`**, sin build.
