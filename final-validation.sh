#!/bin/bash
# =====================================================================
# VALIDACIÓN FINAL PARA PUBLICACIÓN - Moodle Backup V3
# Verificar que el repositorio está listo para la comunidad
# =====================================================================

echo "🔍 VALIDACIÓN FINAL PARA PUBLICACIÓN PÚBLICA"
echo "============================================"

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Contadores
ERRORS=0
WARNINGS=0
CHECKS=0

# Función para reportar resultados
report_check() {
    local status="$1"
    local message="$2"
    local details="$3"
    
    ((CHECKS++))
    
    case "$status" in
        "OK")
            echo -e "${GREEN}✅ $message${NC}"
            [[ -n "$details" ]] && echo -e "   ${details}"
            ;;
        "WARNING")
            echo -e "${YELLOW}⚠️  $message${NC}"
            [[ -n "$details" ]] && echo -e "   ${details}"
            ((WARNINGS++))
            ;;
        "ERROR")
            echo -e "${RED}❌ $message${NC}"
            [[ -n "$details" ]] && echo -e "   ${details}"
            ((ERRORS++))
            ;;
    esac
}

echo ""
echo "📋 VERIFICACIÓN DE ARCHIVOS PRINCIPALES"
echo "--------------------------------------"

# Verificar archivos principales
main_files=("moodle_backup.sh" "mb" "README.md" "CHANGELOG.md" "CONTRIBUTING.md" ".gitignore")
for file in "${main_files[@]}"; do
    if [[ -f "$file" ]]; then
        report_check "OK" "Archivo principal presente: $file"
    else
        report_check "ERROR" "Archivo principal faltante: $file"
    fi
done

echo ""
echo "🧹 VERIFICACIÓN DE LIMPIEZA"
echo "---------------------------"

# Verificar que no hay archivos sensibles
sensitive_patterns=(
    "*.conf" 
    "moodle_backup.conf"
    "debug_*"
    "test_*"
    "validate_*"
    "CORRECCIONES_*"
    ".vscode"
    "*.tmp"
    "*.bak"
)

for pattern in "${sensitive_patterns[@]}"; do
    if ls $pattern >/dev/null 2>&1; then
        files=$(ls $pattern 2>/dev/null)
        report_check "WARNING" "Archivos sensibles encontrados: $pattern" "$files"
    else
        report_check "OK" "No hay archivos sensibles: $pattern"
    fi
done

echo ""
echo "🔧 VERIFICACIÓN DEL WRAPPER mb"
echo "-----------------------------"

# Verificar permisos del wrapper
if [[ -x "mb" ]]; then
    report_check "OK" "Wrapper mb es ejecutable"
else
    report_check "ERROR" "Wrapper mb no es ejecutable"
fi

# Probar comandos básicos del wrapper
if ./mb wrapper-help >/dev/null 2>&1; then
    report_check "OK" "Wrapper mb responde correctamente"
else
    report_check "ERROR" "Wrapper mb no responde correctamente"
fi

echo ""
echo "📝 VERIFICACIÓN DE DOCUMENTACIÓN"
echo "-------------------------------"

# Verificar README.md
if grep -q "tu-usuario" README.md; then
    urls=$(grep -n "tu-usuario" README.md)
    report_check "WARNING" "URLs placeholder en README.md" "$urls"
else
    report_check "OK" "No hay URLs placeholder en README.md"
fi

# Verificar CONTRIBUTING.md
if grep -q "tu-usuario" CONTRIBUTING.md; then
    urls=$(grep -n "tu-usuario" CONTRIBUTING.md)
    report_check "WARNING" "URLs placeholder en CONTRIBUTING.md" "$urls"
else
    report_check "OK" "No hay URLs placeholder en CONTRIBUTING.md"
fi

# Verificar CHANGELOG.md
if grep -q "3.0.3" CHANGELOG.md; then
    report_check "OK" "CHANGELOG.md actualizado con versión 3.0.3"
else
    report_check "WARNING" "CHANGELOG.md no muestra versión 3.0.3"
fi

echo ""
echo "🎯 VERIFICACIÓN DE CONVENCIÓN DE COMANDOS"
echo "----------------------------------------"

# Verificar consistencia en README
if grep -q "Comandos simples.*sin dash" README.md; then
    report_check "OK" "Convención de comandos documentada en README"
else
    report_check "WARNING" "Convención de comandos no clara en README"
fi

# Verificar que el wrapper tiene comandos básicos
basic_commands=("config" "test" "help" "diagnose" "version" "status" "logs" "clean")
missing_commands=()

for cmd in "${basic_commands[@]}"; do
    if grep -q "\"$cmd\")" mb; then
        report_check "OK" "Comando básico presente en wrapper: $cmd"
    else
        missing_commands+=("$cmd")
        report_check "ERROR" "Comando básico faltante en wrapper: $cmd"
    fi
done

echo ""
echo "🔍 VERIFICACIÓN FINAL"
echo "-------------------"

# Verificar structure del repositorio
total_files=$(find . -type f ! -path "./.git/*" | wc -l)
report_check "OK" "Total de archivos en el repositorio: $total_files"

# Verificar tamaño aproximado
repo_size=$(du -sh . 2>/dev/null | cut -f1)
report_check "OK" "Tamaño del repositorio: $repo_size"

echo ""
echo "📊 RESUMEN DE VALIDACIÓN"
echo "======================="
echo -e "Total de verificaciones: ${BLUE}$CHECKS${NC}"
echo -e "Errores encontrados: ${RED}$ERRORS${NC}"
echo -e "Advertencias: ${YELLOW}$WARNINGS${NC}"

echo ""
if [[ $ERRORS -eq 0 ]]; then
    echo -e "${GREEN}🎉 REPOSITORIO LISTO PARA PUBLICACIÓN${NC}"
    echo ""
    echo "📋 PASOS SIGUIENTES:"
    echo "1. Reemplazar URLs placeholder (tu-usuario) si las hay"
    echo "2. Hacer commit final:"
    echo "   git add -A"
    echo "   git commit -m 'feat: Wrapper unificado y repositorio listo para comunidad'"
    echo "3. Crear tag de versión:"
    echo "   git tag -a v3.0.3 -m 'Version 3.0.3: Variables de entorno y wrapper unificado'"
    echo "4. Subir a GitHub:"
    echo "   git push origin main"
    echo "   git push origin v3.0.3"
    echo "5. Publicar release en GitHub con notas del CHANGELOG"
    
    if [[ $WARNINGS -gt 0 ]]; then
        echo ""
        echo -e "${YELLOW}⚠️ Advertencias detectadas. Revisar antes de publicar.${NC}"
    fi
else
    echo -e "${RED}❌ ERRORES CRÍTICOS ENCONTRADOS${NC}"
    echo "Corregir errores antes de publicar"
    exit 1
fi

exit 0
