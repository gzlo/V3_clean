# 🚀 Moodle Backup V3 - Sistema Universal de Backups

[![Version](https://img.shields.io/badge/version-3.0.1-blue.svg)](https://github.com/tu-usuario/moodle-backup-v3)
[![Shell](https://img.shields.io/badge/shell-bash-green.svg)](https://www.gnu.org/software/bash/)
[![License](https://img.shields.io/badge/license-MIT-orange.svg)](LICENSE)
[![Panel Support](https://img.shields.io/badge/panels-cPanel%20%7C%20Plesk%20%7C%20DirectAdmin%20%7C%20VestaCP%20%7C%20Manual-blue.svg)](#-paneles-soportados)

Sistema avanzado de backup para Moodle con soporte multi-panel, auto-detección inteligente, sincronización con Google Drive y configuración universal. Diseñado para funcionar en cualquier entorno: desde hosting compartido hasta VPS dedicados.

## ⚡ Instalación Rápida (1 línea)

```bash
# Instalación automática desde GitHub (recomendado)
curl -fsSL https://raw.githubusercontent.com/tu-usuario/moodle-backup-v3/main/web-install.sh | bash

# O usando wget
wget -qO- https://raw.githubusercontent.com/tu-usuario/moodle-backup-v3/main/web-install.sh | bash
```

### 🔧 Instalación con Opciones

```bash
# Instalación completamente automática (sin preguntas)
curl -fsSL https://raw.githubusercontent.com/tu-usuario/moodle-backup-v3/main/web-install.sh | bash -s -- --auto

# Instalación interactiva personalizada
curl -fsSL https://raw.githubusercontent.com/tu-usuario/moodle-backup-v3/main/web-install.sh | bash -s -- --interactive

# Instalación omitiendo ciertas configuraciones
curl -fsSL https://raw.githubusercontent.com/tu-usuario/moodle-backup-v3/main/web-install.sh | bash -s -- --auto --skip-rclone --skip-cron
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

Después de la instalación, el sistema se maneja con comandos simples:

```bash
# Ejecutar backup inmediato
mb

# Probar configuración
mb --test

# Ver configuración actual
mb --show-config

# Ver ayuda completa
mb --help

# Ejecutar diagnósticos
mb --diagnose

# Ver logs en tiempo real
mb --follow-log
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

## 🚨 Solución de Problemas

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
moodle-backup-v3/
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
CPANEL_USER="usuario"            # Usuario del panel (si aplica)

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
- ✅ **Postponer configuración** con instrucciones detalladas
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

- **Issues**: [GitHub Issues](https://github.com/tu-usuario/moodle-backup-v3/issues)
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

📧 **¿Necesitas soporte?** Abre un [Issue en GitHub](https://github.com/tu-usuario/moodle-backup-v3/issues) o consulta la documentación.
