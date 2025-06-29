# ===================== GUÍA DE INSTALACIÓN Y USO - MOODLE BACKUP V3 =====================

## 1. UBICACIÓN DEL SCRIPT SEGÚN TIPO DE SERVIDOR

### ✅ OPCIÓN 1: Sistema Global (Recomendado para VPS/Dedicados)
```bash
# Instalar en PATH del sistema
sudo cp moodle_backup.sh /usr/local/bin/moodle-backup
sudo chmod +x /usr/local/bin/moodle-backup
sudo chown root:root /usr/local/bin/moodle-backup

# Configuración global
sudo cp moodle_backup.conf.example /etc/moodle_backup.conf
sudo chmod 600 /etc/moodle_backup.conf
sudo chown root:root /etc/moodle_backup.conf
```

### ✅ OPCIÓN 2: Por Cliente/Usuario (Recomendado para Hosting Compartido)
```bash
# Instalar en directorio del usuario (cPanel, Plesk, etc.)
mkdir -p ~/bin
cp moodle_backup.sh ~/bin/moodle-backup
chmod +x ~/bin/moodle-backup

# Configuración local
cp moodle_backup.conf.example ~/moodle_backup.conf
chmod 600 ~/moodle_backup.conf

# Agregar ~/bin al PATH en ~/.bashrc
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

### ✅ OPCIÓN 3: Junto al Proyecto (Para casos específicos)
```bash
# Mantener en directorio del proyecto
chmod +x ./moodle_backup.sh
# Configuración local en el mismo directorio
cp moodle_backup.conf.example ./moodle_backup.conf
chmod 600 ./moodle_backup.conf
```

### ⚠️ CONSIDERACIONES POR PANEL:

#### cPanel/WHM:
- ✅ Usuario: `~/bin/moodle-backup` (más común)
- ✅ Global: `/usr/local/bin/moodle-backup` (si tienes acceso root)
- ⚠️ Permisos: El usuario debe poder leer moodledata y WWW_DIR

#### Plesk:
- ✅ Global: `/usr/local/bin/moodle-backup` (recomendado)
- ✅ Por dominio: `/var/www/vhosts/dominio.com/bin/moodle-backup`
- ⚠️ Usuario: puede correr como root o como usuario del dominio

#### DirectAdmin:
- ✅ Usuario: `~/bin/moodle-backup`
- ✅ Global: `/usr/local/bin/moodle-backup`

#### VestaCP/HestiaCP:
- ✅ Global: `/usr/local/bin/moodle-backup` (recomendado)
- ✅ Usuario: `~/bin/moodle-backup`

#### Servidor Manual/VPS:
- ✅ Global: `/usr/local/bin/moodle-backup` (preferido)
- ✅ Alternativa: `/opt/scripts/moodle-backup`

## 2. PERMISOS REQUERIDOS

### Mínimos Necesarios:
```bash
# El script necesita acceso de LECTURA a:
- WWW_DIR (directorio web de Moodle)
- MOODLEDATA_DIR (directorio de datos)
- config.php (para auto-detección de BD)

# El script necesita acceso de ESCRITURA a:
- TMP_DIR (directorio temporal)
- LOG_FILE (archivo de logs)

# El script necesita EJECUCIÓN de:
- mysqldump (backup de BD)
- tar, zstd (compresión)
- rclone (subida a Google Drive)
```

### ⚠️ NO SIEMPRE NECESITA ROOT:
- **Con root**: Puede acceder a todo, más fácil setup
- **Sin root**: Funciona si el usuario tiene acceso a los directorios de Moodle

## 3. ALIASES Y COMANDOS CORTOS

### ✅ CREAR ALIASES GLOBALES (Recomendado)

#### Para instalación global:
```bash
# Agregar a /etc/bash.bashrc (global) o ~/.bashrc (usuario)
alias mb='moodle-backup'
alias mb-config='moodle-backup --show-config'
alias mb-test='moodle-backup --test-rclone'
alias mb-help='moodle-backup --help'
alias mb-diag='moodle-backup --diagnose'

# Aplicar cambios
source ~/.bashrc
# o para global:
source /etc/bash.bashrc
```

#### Para instalación local:
```bash
# Agregar a ~/.bashrc del usuario
alias mb='~/bin/moodle-backup'
alias mb-config='~/bin/moodle-backup --show-config'
alias mb-test='~/bin/moodle-backup --test-rclone'
alias mb-help='~/bin/moodle-backup --help'
alias mb-run='~/bin/moodle-backup'

source ~/.bashrc
```

### ✅ USO SIMPLIFICADO CON ALIASES:

```bash
# Ver configuración
mb-config

# Ejecutar backup
mb

# Probar conexión Google Drive
mb-test

# Ver ayuda
mb-help

# Diagnóstico completo
mb-diag

# Forzar tipo de panel
PANEL_TYPE=plesk mb-config

# Backup con configuración específica
CLIENT_NAME=mi_cliente mb
```

## 4. SCRIPT DE INSTALACIÓN AUTOMÁTICA

### Crear instalador automático:
```bash
#!/bin/bash
# install.sh - Instalador automático de Moodle Backup V3

set -euo pipefail

echo "=== INSTALADOR MOODLE BACKUP V3 ==="

# Detectar privilegios
if [[ $EUID -eq 0 ]]; then
    echo "✅ Ejecutando como root - Instalación global"
    INSTALL_DIR="/usr/local/bin"
    CONFIG_DIR="/etc"
    GLOBAL_INSTALL=true
else
    echo "⚠️ Ejecutando como usuario - Instalación local"
    INSTALL_DIR="$HOME/bin"
    CONFIG_DIR="$HOME"
    GLOBAL_INSTALL=false
    mkdir -p "$INSTALL_DIR"
fi

# Copiar script principal
echo "📁 Instalando script en: $INSTALL_DIR"
cp moodle_backup.sh "$INSTALL_DIR/moodle-backup"
chmod +x "$INSTALL_DIR/moodle-backup"

# Copiar configuración de ejemplo
echo "📝 Instalando configuración en: $CONFIG_DIR"
if [[ ! -f "$CONFIG_DIR/moodle_backup.conf" ]]; then
    cp moodle_backup.conf.example "$CONFIG_DIR/moodle_backup.conf"
    chmod 600 "$CONFIG_DIR/moodle_backup.conf"
    echo "✅ Configuración creada: $CONFIG_DIR/moodle_backup.conf"
else
    echo "⚠️ Configuración existente encontrada, no sobrescribiendo"
fi

# Configurar aliases
BASHRC_FILE="$HOME/.bashrc"
if [[ "$GLOBAL_INSTALL" == true ]]; then
    BASHRC_FILE="/etc/bash.bashrc"
fi

echo "🔧 Configurando aliases en: $BASHRC_FILE"
cat >> "$BASHRC_FILE" << 'EOF'

# Moodle Backup V3 - Aliases
alias mb='moodle-backup'
alias mb-config='moodle-backup --show-config'
alias mb-test='moodle-backup --test-rclone'
alias mb-help='moodle-backup --help'
alias mb-diag='moodle-backup --diagnose'
EOF

# Agregar al PATH si es instalación local
if [[ "$GLOBAL_INSTALL" == false ]]; then
    if ! grep -q 'export PATH="$HOME/bin:$PATH"' "$HOME/.bashrc"; then
        echo 'export PATH="$HOME/bin:$PATH"' >> "$HOME/.bashrc"
    fi
fi

echo ""
echo "✅ INSTALACIÓN COMPLETADA"
echo ""
echo "PRÓXIMOS PASOS:"
echo "1. Recargar configuración: source ~/.bashrc"
echo "2. Editar configuración: nano $CONFIG_DIR/moodle_backup.conf"
echo "3. Ver configuración: mb-config"
echo "4. Ejecutar backup: mb"
echo ""
echo "COMANDOS DISPONIBLES:"
echo "  mb           - Ejecutar backup"
echo "  mb-config    - Ver configuración"
echo "  mb-test      - Probar Google Drive"
echo "  mb-help      - Ver ayuda"
echo "  mb-diag      - Diagnóstico"
```

## 5. EJEMPLOS DE USO POR ENTORNO

### Hosting Compartido (cPanel):
```bash
# Instalación
bash install.sh
source ~/.bashrc

# Configuración mínima
nano ~/moodle_backup.conf
# CLIENT_NAME=mi_cliente
# PANEL_TYPE=cpanel
# REQUIRE_CONFIG=false  # Para permitir auto-detección

# Uso
mb-config  # Verificar configuración
mb         # Ejecutar backup
```

### VPS/Dedicado (Plesk):
```bash
# Instalación como root
sudo bash install.sh
source /etc/bash.bashrc

# Configuración global
sudo nano /etc/moodle_backup.conf
# CLIENT_NAME=servidor_plesk
# PANEL_TYPE=plesk
# DOMAIN_NAME=midominio.com

# Uso desde cualquier usuario
mb-config
mb
```

### Servidor Manual:
```bash
# Instalación
sudo bash install.sh

# Configuración
sudo nano /etc/moodle_backup.conf
# CLIENT_NAME=servidor_manual
# PANEL_TYPE=manual
# AUTO_DETECT_AGGRESSIVE=true
# WWW_DIR=/var/www/html/moodle
# MOODLEDATA_DIR=/var/moodledata

# Uso
mb-config
mb
```

## 6. CRON JOBS CON ALIASES

### Crontab del usuario:
```bash
# Ejecutar backup diario a las 2 AM
0 2 * * * source ~/.bashrc && mb 2>&1 | logger -t moodle-backup

# Verificar configuración semanalmente
0 1 * * 0 source ~/.bashrc && mb-config 2>&1 | logger -t moodle-backup-config
```

### Crontab global (/etc/crontab):
```bash
# Backup diario como root
0 2 * * * root /usr/local/bin/moodle-backup 2>&1 | logger -t moodle-backup
```

## RESUMEN DE MEJORES PRÁCTICAS

✅ **Instalación Global**: VPS/Dedicados con acceso root
✅ **Instalación Local**: Hosting compartido
✅ **Aliases Cortos**: `mb`, `mb-config`, `mb-test`
✅ **Script de Instalación**: Automatizar el proceso
✅ **Configuración Segura**: Permisos 600 en archivos config
✅ **Logging**: Usar logger para cron jobs
✅ **Testing**: Siempre usar `mb-config` antes del primer backup
