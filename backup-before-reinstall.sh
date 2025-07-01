#!/bin/bash
# ===================== BACKUP ANTES DE REINSTALAR =====================
# Script para hacer backup de configuraciones personales antes de reinstalar
# Autor: Sistema Moodle Backup - Versión: 3.0.3
# ========================================================================

set -euo pipefail

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Directorios comunes de instalación
POSSIBLE_INSTALL_DIRS=(
    "/usr/local/bin"
    "$HOME/bin"
    "/opt/moodle-backup"
    "/usr/bin"
)

POSSIBLE_CONFIG_DIRS=(
    "/etc"
    "$HOME/.config/moodle-backup"
    "/usr/local/etc"
)

# Función para mostrar mensajes
print_info() { echo -e "${BLUE}ℹ️ $1${NC}"; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️ $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }
print_step() { echo -e "${BLUE}🔄 $1${NC}"; }

# Crear directorio de backup
BACKUP_DIR="$HOME/moodle-backup-personal-$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

print_info "🏠 Directorio de backup: $BACKUP_DIR"
echo ""

# Función para buscar y hacer backup de archivos
backup_file() {
    local filename="$1"
    local description="$2"
    local found=false
    
    for dir in "${POSSIBLE_INSTALL_DIRS[@]}" "${POSSIBLE_CONFIG_DIRS[@]}"; do
        local filepath="$dir/$filename"
        if [[ -f "$filepath" ]]; then
            print_step "Haciendo backup de $description"
            cp "$filepath" "$BACKUP_DIR/${filename}.backup"
            print_success "✓ $filepath → $BACKUP_DIR/${filename}.backup"
            found=true
        fi
    done
    
    if [[ "$found" == false ]]; then
        print_warning "No se encontró $description ($filename)"
    fi
}

# Función para hacer backup de configuraciones personalizadas
backup_custom_configs() {
    print_step "Buscando configuraciones personalizadas..."
    
    # Buscar archivos .conf personalizados
    for dir in "${POSSIBLE_CONFIG_DIRS[@]}"; do
        if [[ -d "$dir" ]]; then
            find "$dir" -name "*moodle*backup*.conf" -type f 2>/dev/null | while read -r conf_file; do
                if [[ -f "$conf_file" ]]; then
                    local basename_file=$(basename "$conf_file")
                    print_step "Haciendo backup de configuración personalizada"
                    cp "$conf_file" "$BACKUP_DIR/$basename_file.backup"
                    print_success "✓ $conf_file → $BACKUP_DIR/$basename_file.backup"
                fi
            done
        fi
    done
}

# Función para hacer backup de scripts personalizados
backup_custom_scripts() {
    print_step "Buscando modificaciones en scripts principales..."
    
    for dir in "${POSSIBLE_INSTALL_DIRS[@]}"; do
        local script_path="$dir/moodle_backup.sh"
        if [[ -f "$script_path" ]]; then
            # Verificar si tiene modificaciones personales (buscar comentarios o fechas de modificación)
            local mod_date=$(stat -c %Y "$script_path" 2>/dev/null || stat -f %m "$script_path" 2>/dev/null || echo "0")
            local current_date=$(date +%s)
            local days_old=$(( (current_date - mod_date) / 86400 ))
            
            if [[ $days_old -lt 30 ]]; then
                print_step "Haciendo backup del script principal (modificado recientemente)"
                cp "$script_path" "$BACKUP_DIR/moodle_backup.sh.backup"
                print_success "✓ $script_path → $BACKUP_DIR/moodle_backup.sh.backup"
            fi
        fi
        
        local wrapper_path="$dir/mb"
        if [[ -f "$wrapper_path" ]]; then
            local mod_date=$(stat -c %Y "$wrapper_path" 2>/dev/null || stat -f %m "$wrapper_path" 2>/dev/null || echo "0")
            local current_date=$(date +%s)
            local days_old=$(( (current_date - mod_date) / 86400 ))
            
            if [[ $days_old -lt 30 ]]; then
                print_step "Haciendo backup del wrapper mb (modificado recientemente)"
                cp "$wrapper_path" "$BACKUP_DIR/mb.backup"
                print_success "✓ $wrapper_path → $BACKUP_DIR/mb.backup"
            fi
        fi
    done
}

# Función para hacer backup de cron jobs
backup_cron_jobs() {
    print_step "Haciendo backup de tareas cron relacionadas..."
    
    if crontab -l 2>/dev/null | grep -q "moodle_backup\|backup.*moodle"; then
        crontab -l 2>/dev/null | grep "moodle_backup\|backup.*moodle" > "$BACKUP_DIR/cron_jobs.backup"
        print_success "✓ Tareas cron → $BACKUP_DIR/cron_jobs.backup"
    else
        print_warning "No se encontraron tareas cron relacionadas"
    fi
}

# Función para hacer backup de configuración de rclone
backup_rclone_config() {
    print_step "Haciendo backup de configuración de rclone..."
    
    if [[ -f "$HOME/.config/rclone/rclone.conf" ]]; then
        cp "$HOME/.config/rclone/rclone.conf" "$BACKUP_DIR/rclone.conf.backup"
        print_success "✓ Configuración rclone → $BACKUP_DIR/rclone.conf.backup"
    else
        print_warning "No se encontró configuración de rclone"
    fi
}

# Función para crear script de restauración
create_restore_script() {
    cat > "$BACKUP_DIR/restore.sh" << 'EOF'
#!/bin/bash
# Script de restauración automática
# Ejecutar después de la reinstalación

BACKUP_DIR="$(dirname "$0")"

echo "🔄 Restaurando configuraciones personales..."

# Buscar directorio de configuración actual
CONFIG_DIRS=("/etc" "$HOME/.config/moodle-backup" "/usr/local/etc")

for dir in "${CONFIG_DIRS[@]}"; do
    if [[ -w "$dir" ]] || [[ "$dir" == "$HOME"* ]]; then
        CONFIG_DIR="$dir"
        break
    fi
done

# Restaurar archivos de configuración
for backup_file in "$BACKUP_DIR"/*.conf.backup; do
    if [[ -f "$backup_file" ]]; then
        original_name=$(basename "$backup_file" .backup)
        echo "📁 Restaurando $original_name a $CONFIG_DIR/"
        cp "$backup_file" "$CONFIG_DIR/$original_name"
    fi
done

# Restaurar configuración de rclone
if [[ -f "$BACKUP_DIR/rclone.conf.backup" ]]; then
    mkdir -p "$HOME/.config/rclone"
    cp "$BACKUP_DIR/rclone.conf.backup" "$HOME/.config/rclone/rclone.conf"
    echo "📁 Configuración de rclone restaurada"
fi

# Restaurar cron jobs
if [[ -f "$BACKUP_DIR/cron_jobs.backup" ]]; then
    echo "📁 Tareas cron disponibles en: $BACKUP_DIR/cron_jobs.backup"
    echo "   Para restaurar: crontab $BACKUP_DIR/cron_jobs.backup"
fi

echo "✅ Restauración completada"
echo "📋 Revisar archivos en: $BACKUP_DIR"
EOF

    chmod +x "$BACKUP_DIR/restore.sh"
    print_success "✓ Script de restauración creado: $BACKUP_DIR/restore.sh"
}

# EJECUCIÓN PRINCIPAL
echo "🛡️ BACKUP ANTES DE REINSTALAR MOODLE BACKUP V3"
echo "==============================================="
echo ""

print_info "Iniciando backup de configuraciones personales..."
echo ""

# Hacer backup de archivos específicos
backup_file "moodle_backup.conf" "configuración principal"
backup_file "moodle_backup.sh" "script principal"
backup_file "mb" "wrapper mb"

# Buscar configuraciones personalizadas
backup_custom_configs

# Scripts modificados recientemente
backup_custom_scripts

# Cron jobs
backup_cron_jobs

# Configuración rclone
backup_rclone_config

# Crear script de restauración
create_restore_script

echo ""
print_success "🎉 BACKUP COMPLETADO"
echo ""
print_info "📁 Backup guardado en: $BACKUP_DIR"
print_info "🔄 Script de restauración: $BACKUP_DIR/restore.sh"
echo ""
print_warning "DESPUÉS DE REINSTALAR:"
print_info "1. Ejecutar: $BACKUP_DIR/restore.sh"
print_info "2. Verificar configuraciones restauradas"
print_info "3. Probar: mb config"
echo ""
