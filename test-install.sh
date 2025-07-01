#!/bin/bash

# Script de prueba para verificar el funcionamiento del instalador
echo "=== PRUEBA DEL INSTALADOR MOODLE BACKUP ==="
echo ""

# Probar ejecución normal
echo "1. Probando ejecución normal del script..."
echo "./web-install.sh --help"
echo ""

# Probar con modo automático
echo "2. Para probar modo automático:"
echo "./web-install.sh --auto"
echo ""

# Probar con modo interactivo forzado
echo "3. Para probar modo interactivo forzado (desde tubería):"
echo "cat web-install.sh | bash -s -- --interactive"
echo ""

# Probar con curl simulado
echo "4. Para simular ejecución desde curl:"
echo "cat web-install.sh | bash"
echo ""

echo "=== NOTAS IMPORTANTES ==="
echo "- El error '-bash: N: command not found' se ha corregido"
echo "- Ahora usa /dev/tty para entrada segura"
echo "- Detecta automáticamente ejecución desde tubería"
echo "- Modo auto se activa automáticamente desde curl | bash"
echo "- Puede forzar modo interactivo con --interactive"
echo ""

echo "=== COMANDOS DE PRUEBA ==="
echo "Ejecutar cualquiera de estos comandos para probar:"
echo ""
echo "# Modo automático (sin preguntas)"
echo "./web-install.sh --auto"
echo ""
echo "# Modo interactivo local"
echo "./web-install.sh --interactive"
echo ""
echo "# Simular curl | bash (debería activar modo auto automáticamente)"
echo "cat web-install.sh | bash"
echo ""
echo "# Forzar interactivo desde tubería"
echo "cat web-install.sh | bash -s -- --interactive"
