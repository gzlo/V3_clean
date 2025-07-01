# 🚀 Moodle Backup V3 - Sistema Universal de Backups

[![Version](https://img.shields.io/badge/version-3.0.5-blue.svg)](https://github.com/gzlo/moodle-backup)
[![Shell](https://img.shields.io/badge/shell-bash-green.svg)](https://www.gnu.org/software/bash/)
[![License](https://img.shields.io/badge/license-MIT-orange.svg)](LICENSE)
[![Panel Support](https://img.shields.io/badge/panels-cPanel%20%7C%20Plesk%20%7C%20DirectAdmin%20%7C%20VestaCP%20%7C%20Manual-blue.svg)](#-paneles-soportados)

Sistema avanzado de backup para Moodle con soporte multi-panel, auto-detección inteligente, sincronización con Google Drive y configuración universal. Diseñado para funcionar en cualquier entorno: desde hosting compartido hasta VPS dedicados.

## ⚡ Instalación Rápida (1 línea)

```bash
# Instalación automática desde GitHub (recomendado)
curl -fsSL https://raw.githubusercontent.com/gzlo/moodle-backup/main/web-install.sh | bash

# O usando wget
wget -qO- https://raw.githubusercontent.com/gzlo/moodle-backup/main/web-install.sh | bash
```

### 🔧 Instalación con Opciones

```bash
# Instalación completamente automática (sin preguntas)
curl -fsSL https://raw.githubusercontent.com/gzlo/moodle-backup/main/web-install.sh | bash -s -- --auto

# Instalación interactiva personalizada
curl -fsSL https://raw.githubusercontent.com/gzlo/moodle-backup/main/web-install.sh | bash -s -- --interactive

# Instalación omitiendo ciertas configuraciones
curl -fsSL https://raw.githubusercontent.com/gzlo/moodle-backup/main/web-install.sh | bash -s -- --auto --skip-rclone --skip-cron
```

## 🎯 Características Principales

### ✨ **Auto-detección Inteligente**

- **Paneles de Control**: cPanel, Plesk, DirectAdmin, VestaCP, ISPConfig, Manual
- **Rutas de Moodle**: Detecta automáticamente www y moodledata
- **Configuración de BD**: Lee config.php para obtener credenciales
- **Sistema Operativo**: Soporta CentOS/RHEL, Ubuntu/Debian, Fedora, Rocky Linux

### 🚀 **Instalación Universal**

- **Un comando**: Instalación completa desde GitHub
- **Sin dependencias**: Instala automáticamente todo lo necesario
- **Multi-entorno**: VPS, hosting compartido, servidores dedicados
- **Verificación**: Comprueba la instalación y funcionalidad

### 🛡️ **Backup Inteligente**

- **Compresión avanzada**: zstd para máxima eficiencia
- **Multi-hilo**: Acelera significativamente el proceso
- **Verificación**: Comprueba integridad de archivos y BD
- **Limpieza automática**: Mantiene solo los backups necesarios

### ☁️ **Sincronización en la Nube**

- **Google Drive**: Configuración automática con rclone
- **Gestión inteligente**: Rotación automática de backups antiguos
- **Verificación**: Comprueba subida y integridad
- **Recuperación**: Descarga directa desde la nube

### 📊 **Monitoreo y Logging**

- **Logs detallados**: Registro completo de todas las operaciones
- **Notificaciones**: Email en caso de errores o éxito
- **Diagnósticos**: Herramientas de análisis y troubleshooting
- **Métricas**: Tiempo, tamaño, velocidad de transferencia

## 🖥️ Paneles Soportados

| Panel                | Auto-detección | Configuración |  Estado  |
| -------------------- | :------------: | :-----------: | :------: |
| **cPanel**           |       ✅        |       ✅       | Completo |
| **Plesk**            |       ✅        |       ✅       | Completo |
| **DirectAdmin**      |       ✅        |       ✅       | Completo |
| **VestaCP/HestiaCP** |       ✅        |       ✅       | Completo |
| **ISPConfig**        |       ✅        |       ✅       | Completo |
| **Manual**           |       ✅        |       ✅       | Completo |

## 📋 Uso Básico

Después de la instalación, el sistema se maneja con el wrapper `mb` (MoodleBackup):

### 🎮 Comandos Principales

```bash
# Ejecutar backup en segundo plano (recomendado)
mb

# Ejecutar backup en primer plano (modo interactivo)
mb interactive

# Ver configuración actual
mb config

# Probar conectividad y configuración
mb test

# Ver ayuda completa
mb help

# Ejecutar diagnósticos del sistema
mb diagnose

# Ver versión del sistema
mb version
```

### 🔄 **Nueva Funcionalidad V3.0.5: Ejecución en Segundo Plano**

Por defecto, `mb` ejecuta el backup en **segundo plano** usando `nohup`, permitiendo que continúe aunque cierre la sesión SSH:

```bash
# Backup desatendido (continúa sin SSH)
mb

# Monitorear progreso en tiempo real
mb logs
mb status

# Backup interactivo (requiere sesión SSH activa)
mb interactive
```

**Convención de comandos:**
- **Comandos simples** (sin dash): Para uso cotidiano - `mb config`, `mb test`, `mb help`
- **Opciones avanzadas** (con dash): Para compatibilidad completa - `mb --help`, `mb --diagnose`, `mb --show-config`

### 📊 Comandos de Monitoreo

```bash
# Ver logs recientes del último backup
mb logs

# Ver más líneas de log
mb logs 50

# Ver estado del último backup con información del proceso
mb status

# Seguimiento en tiempo real
tail -f /var/log/moodle_backup.log

# Limpiar archivos temporales antiguos
mb clean
```

### 🔧 Comandos Avanzados (Compatibilidad)

```bash
# Opciones avanzadas con dash (compatibilidad completa)
mb --help             # Ayuda completa con todas las opciones
mb --diagnose         # Diagnósticos avanzados del sistema
mb --test-rclone      # Prueba específica de Google Drive
mb --show-config      # Configuración con validación completa
```

## 🔄 Ejecución en Segundo Plano (V3.0.5)

### ✨ Funcionalidad Principal

El sistema V3.0.5 ejecuta backups de forma **desatendida**, independiente de la sesión SSH:

```bash
# Backup automático (continúa aunque cierre SSH)
mb

# El sistema muestra:
🚀 Iniciando backup de Moodle en segundo plano...
📋 Logs del proceso: /var/log/moodle_backup.log
📋 Logs de sesión: /tmp/moodle_backup_session_*.log

✅ Backup iniciado en segundo plano (PID: 12345)
🔍 El proceso continuará aunque cierre la sesión SSH

Comandos útiles:
  mb logs     # Ver progreso en tiempo real
  mb status   # Estado actual
  ps -p 12345 # Verificar si el proceso sigue ejecutándose
```

### 📊 Monitoreo del Proceso

```bash
# Ver estado detallado
mb status
# Muestra:
# - PID del proceso activo
# - Estado de ejecución
# - Último backup exitoso/error
# - Archivos temporales
# - Últimas líneas del log

# Seguimiento en tiempo real
mb logs
tail -f /var/log/moodle_backup.log

# Verificar proceso manualmente
ps aux | grep moodle_backup
```

### 🎯 Casos de Uso

**Para Producción (Recomendado):**
```bash
mb                    # Ejecución desatendida
```

**Para Desarrollo/Debug:**
```bash
mb interactive        # Ver salida en tiempo real
```

**Para Monitoreo:**
```bash
mb status && mb logs  # Estado + logs recientes
```

## ⚙️ Configuración Multi-Cliente

El sistema soporta múltiples instalaciones de Moodle con configuraciones independientes:

```bash
# Usar configuración específica
mb --config /etc/moodle_backup_cliente1.conf

# Crear nueva configuración
cp /etc/moodle_backup.conf.example /etc/moodle_backup_cliente2.conf
# Editar el archivo según necesidades
mb --config /etc/moodle_backup_cliente2.conf --test
```

## �️ Reinstalación Segura

### ⚠️ IMPORTANTE: Backup Antes de Reinstalar

Los scripts de instalación **sobrescriben archivos principales** sin aviso. Para evitar perder tus configuraciones:

```bash
# 1. ANTES de reinstalar - Hacer backup automático
./backup-before-reinstall.sh

# 2. Reinstalar normalmente
curl -fsSL https://raw.githubusercontent.com/gzlo/moodle-backup/main/install.sh | bash

# 3. DESPUÉS de reinstalar - Restaurar configuraciones
~/moodle-backup-personal-XXXXXXXX/restore.sh

# 4. Verificar que todo funciona
mb config && mb test
```

### 📋 ¿Qué se Sobrescribe vs. Qué se Preserva?

**Se SOBRESCRIBEN (sin aviso):**
- ❌ `moodle_backup.sh` - Script principal
- ❌ `mb` - Wrapper de comandos
- ❌ `moodle_backup.conf.example` - Archivo de ejemplo

**Se PRESERVAN:**
- ✅ `moodle_backup.conf` - Tu configuración real
- ✅ Configuración de rclone (solo pregunta si reconfigurar)
- ✅ Alias de bash (solo agrega si no existe)

📖 **Guía completa**: Ver `REINSTALL_SAFELY.md` para el proceso detallado.

## �🚨 Solución de Problemas

### Problemas Comunes

**Error: "mysql command not found"**

```bash
# CentOS/RHEL/Fedora
sudo yum install mysql -y

# Ubuntu/Debian
sudo apt-get install mysql-client -y
```

**Error: "rclone not configured"**

```bash
# Configurar Google Drive
rclone config
# Seguir las instrucciones para crear remote "gdrive"
```

**Error: "Permission denied"**

```bash
# Verificar permisos de archivos
ls -la /usr/local/bin/moodle_backup.sh
chmod +x /usr/local/bin/moodle_backup.sh

# Verificar configuración
ls -la /etc/moodle_backup.conf
```

### Diagnósticos Avanzados

```bash
# Ejecutar diagnósticos completos
mb --diagnose

# Ver configuración detectada
mb --show-config

# Probar solo rclone
mb --test-rclone

# Ver logs detallados
tail -f /var/log/moodle_backup*.log
```

## 📁 Estructura del Proyecto

```
moodle-backup/
├── moodle_backup.sh              # Script principal
├── mb                             # Wrapper para comandos cortos
├── moodle_backup.conf.example     # Configuración de ejemplo
├── install.sh                     # Instalador local
├── web-install.sh                 # Instalador web (desde GitHub)
├── README.md                      # Documentación principal
├── INSTALACION_Y_USO.md          # Guía detallada de instalación
└── docs/
    ├── CONFIGURACION_AVANZADA.md  # Configuración avanzada
    ├── TROUBLESHOOTING.md         # Solución de problemas
    └── EJEMPLOS.md                # Ejemplos de uso
```

## 🔧 Configuración Avanzada

### Variables de Entorno Principales

```bash
# Información del cliente
CLIENT_NAME="mi_cliente"
CLIENT_DESCRIPTION="Backup Moodle Cliente"

# Configuración del panel
PANEL_TYPE="cpanel"              # auto, cpanel, plesk, directadmin, vestacp, manual
PANEL_USER="usuario"             # Usuario del panel (si aplica)

# Rutas principales
WWW_DIR="/home/user/public_html"
MOODLEDATA_DIR="/home/user/moodledata"

# Google Drive
GDRIVE_REMOTE="gdrive:moodle_backups"
MAX_BACKUPS_GDRIVE=2

# Configuración avanzada
AUTO_DETECT_AGGRESSIVE="true"    # Auto-detección agresiva
FORCE_THREADS=4                  # Número de hilos para compresión
```

### 🔐 Configuración Segura de Contraseñas

El sistema ofrece **4 métodos** para configurar la contraseña de la base de datos, priorizando la seguridad:

#### Método 1: Archivo Protegido (Recomendado)

```bash
# Crear archivo con permisos restrictivos
sudo mkdir -p /etc/mysql
sudo echo 'tu_password_aquí' > /etc/mysql/backup.pwd
sudo chmod 600 /etc/mysql/backup.pwd
sudo chown root:root /etc/mysql/backup.pwd
```

#### Método 2: Variable de Entorno

```bash
# Para sesión actual
export MYSQL_PASSWORD='tu_password_aquí'

# Para hacer permanente
echo "export MYSQL_PASSWORD='tu_password_aquí'" >> ~/.bashrc
```

#### Método 3: En Archivo de Configuración (Desarrollo)

```bash
# En moodle_backup.conf (menos seguro)
DB_PASS="tu_password_aquí"
```

#### ⚡ Configuración Automática

Durante la instalación, el sistema te permite:

- ✅ **Crear archivo protegido automáticamente** con permisos correctos
- ✅ **Configurar variable de entorno** para la sesión actual
- ✅ **Postergar configuración** con instrucciones detalladas
- ✅ **Verificar estado** de todas las configuraciones

```bash
# El instalador detecta y configura automáticamente
# Simplemente elige la opción más segura para tu entorno
```

### 📋 Orden de Prioridad de Contraseñas

El script busca la contraseña en este orden:

1. **Variable `DB_PASS`** en archivo de configuración
2. **Variable de entorno `MYSQL_PASSWORD`**
3. **Archivo `/etc/mysql/backup.pwd`**
4. **Auto-detección** desde `config.php` de Moodle

### 🔍 Verificar Configuración

```bash
# Verificar qué método está usando
mb --test

# Ver estado de configuración de contraseñas
mb --show-config | grep -A 10 "CONTRASEÑA"
OPTIMIZED_HOURS="02-08"          # Horas de menor carga
```

### Configuración de Cron

```bash
# Diario a las 2:00 AM
0 2 * * * /usr/local/bin/moodle_backup.sh >/dev/null 2>&1

# Semanal los domingos a las 3:00 AM
0 3 * * 0 /usr/local/bin/moodle_backup.sh >/dev/null 2>&1

# Multi-cliente
0 2 * * * /usr/local/bin/moodle_backup.sh --config /etc/moodle_backup_cliente1.conf >/dev/null 2>&1
0 3 * * * /usr/local/bin/moodle_backup.sh --config /etc/moodle_backup_cliente2.conf >/dev/null 2>&1
```

## 🆕 Changelog V3

### ✨ Nuevas Características

- **Instalador web**: Instalación directa desde GitHub con un comando
- **Auto-detección mejorada**: Soporte para todos los paneles principales
- **Multi-panel inteligente**: Configuración automática según el entorno
- **Verificación post-instalación**: Comprueba que todo funcione correctamente
- **Configuración asistida**: Wizard interactivo para primera configuración
- **Gestión de dependencias**: Instalación automática de herramientas necesarias

### 🔧 Mejoras

- **Logging mejorado**: Más detallado y estructurado
- **Gestión de errores**: Mejor manejo y recuperación de errores
- **Performance**: Optimizaciones en compresión y transferencia
- **Compatibilidad**: Mejor soporte para diferentes distribuciones Linux

### 🐛 Correcciones

- Problemas de detección en hosting compartido
- Errores de permisos en instalaciones de usuario
- Compatibilidad con versiones antiguas de MySQL
- Manejo de rutas con espacios y caracteres especiales

## 📞 Soporte

### 🆘 Obtener Ayuda

- **Issues**: [GitHub Issues](https://github.com/gzlo/moodle-backup/issues)
- **Documentación**: Ver carpeta `docs/` para guías detalladas

### 🤝 Contribuir

1. Fork el repositorio
2. Crea una rama para tu feature (`git checkout -b feature/nueva-caracteristica`)
3. Commit tus cambios (`git commit -am 'Agrega nueva característica'`)
4. Push a la rama (`git push origin feature/nueva-caracteristica`)
5. Crea un Pull Request

## 📜 Licencia

Este proyecto está bajo la Licencia MIT - ver el archivo [LICENSE](LICENSE) para detalles.

## 🙏 Créditos

Desarrollado por **gzlo** - Especialista en infraestructura Moodle y hosting optimizado.

- **Autor**: gzlo
- **Versión**: 3.0.1
- **Última actualización**: 2025-06-29

---

⭐ **¿Te resulta útil?** ¡Dale una estrella al repositorio y compártelo!

📧 **¿Necesitas soporte?** Abre un [Issue en GitHub](https://github.com/gzlo/moodle-backup/issues) o consulta la documentación.
