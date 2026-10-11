#!/bin/sh
# Genera config.js a partir de variables de entorno (o de un archivo .env).
# Uso local:  sh generar_config.sh        (lee .env si existe)
# En Vercel:  Build Command = sh generar_config.sh  (lee las Environment Variables)
[ -f .env ] && . ./.env
if [ -z "$SUPABASE_URL" ] || [ -z "$SUPABASE_ANON_KEY" ]; then
  echo "Faltan SUPABASE_URL o SUPABASE_ANON_KEY; dejo config.js como está."; exit 0
fi
cat > config.js <<FIN
// Generado por generar_config.sh. La clave anon es pública (no es secreta).
window.APP_CONFIG = {
  SUPABASE_URL: "$SUPABASE_URL",
  SUPABASE_ANON_KEY: "$SUPABASE_ANON_KEY"
};
FIN
echo "config.js generado."
