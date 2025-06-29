# 📋 Historial de Cambios - Moodle Backup V3

Todos los cambios importantes de este proyecto se documentan en este archivo.

El formato está basado en [Keep a Changelog](https://keepachangelog.com/es/1.0.0/),
y este proyecto se adhiere al [Versionado Semántico](https://semver.org/lang/es/).

## [3.0.1] - 2025-06-29

### 🔒 Seguridad y Configuración Mejorada

#### ✨ Nuevas Funcionalidades
- **Configuración de Contraseñas Inteligente**: Sistema avanzado de configuración de contraseñas de BD con múltiples opciones de seguridad
- **Archivo Protegido Automático**: Creación automática de `/etc/mysql/backup.pwd` con permisos 600
- **Variable de Entorno Interactiva**: Configuración automática de `MYSQL_PASSWORD` durante la instalación
- **Verificación de Estado**: Detección inteligente del método de configuración utilizado en el resumen final

#### 🛠️ Mejoras en el Instalador
- **4 Opciones de Configuración**:
  1. Texto plano en archivo config (menos seguro - para desarrollo)
  2. Archivo protegido automático (recomendado)
  3. Variable de entorno con configuración opcional inmediata
  4. Configuración postpone con instrucciones detalladas
- **Detección de Permisos**: Verificación automática de permisos sudo para crear archivos protegidos
- **Fallback Inteligente**: Si no hay permisos, muestra instrucciones manuales claras
- **Validación de Configuración**: Verifica permisos del archivo creado (600)

#### 📋 Documentación Mejorada
- **Instrucciones Claras**: Comandos específicos listos para copiar y pegar
- **Priorización de Seguridad**: Destaca métodos más seguros con indicadores visuales
- **Resumen Inteligente**: Detecta automáticamente qué configuraciones necesitan atención
- **Estado de Contraseñas**: Muestra el estado actual de todas las configuraciones de BD

#### 🎨 Experiencia de Usuario
- **Indicadores Visuales**: Emojis y colores para destacar información importante
- **Opciones por Defecto**: Opción segura (archivo protegido) como predeterminada
- **Confirmación Visual**: Mensajes de éxito/error claros para cada operación
- **Recordatorios Persistentes**: Información importante visible en múltiples lugares

### 🔧 Mejoras Técnicas
- **Limpieza de Memoria**: Variables temporales de contraseñas se limpian inmediatamente
- **Verificación de Integridad**: Comprueba que los archivos se crearon con permisos correctos
- **Compatibilidad Multiplataforma**: Comandos `stat` funcionan en diferentes sistemas
- **Manejo de Errores Robusto**: Gestión granular de errores en cada opción

## [3.0.0] - 2025-01-29

### 🎉 Características Principales (Versión V3)

#### ✨ Nuevas Funcionalidades
- **Archivos Independientes**: Compresión y subida separada de database.sql.gz, moodle_core.tar.zst y moodledata.tar.zst
- **Multi-Panel Universal**: Soporte automático para cPanel, Plesk, DirectAdmin, VestaCP/HestiaCP, ISPConfig y instalaciones manuales
- **Auto-detección Inteligente**: Detección automática de paneles, directorios, usuarios y configuración de base de datos
- **Configuración Externa Obligatoria**: Sistema de configuración modular con archivos .conf externos
- **Multi-Cliente**: Soporte para múltiples clientes Moodle en el mismo servidor
- **Wrapper 'mb'**: Comandos cortos y alias para facilitar el uso
- **Instalador Web**: Instalación con un solo comando desde GitHub
- **Instalador Interactivo**: Configuración guiada paso a paso
- **Validación de Email Obligatoria**: Requiere al menos un email válido para notificaciones

#### 🛠️ Mejoras Técnicas
- **Logging Avanzado**: Sistema de logging granular con rotación automática
- **Validación Robusta**: Validación exhaustiva de configuración y directorios
- **Recuperación Inteligente**: Manejo de fallos parciales y reintento granular
- **Verificación de Integridad**: Validación individual por archivo
- **Retención por Carpetas**: Gestión de backups por fecha en Google Drive
- **Configuración Dinámica**: Adaptación automática según horarios y recursos

#### 🔒 Seguridad y Privacidad
- **Sin Emails Hardcodeados**: Eliminación completa de emails por defecto en el código
- **Configuración Obligatoria**: Validación de que existe al menos un email de notificación
- **Repo Público Preparado**: Código listo para publicación sin datos sensibles

#### 📦 Sistema de Instalación
- **install.sh**: Instalador automático básico
- **web-install.sh**: Instalador web desde GitHub con detección de entorno
- **install-interactive.sh**: Instalador interactivo con configuración guiada
- **Detección de Dependencias**: Instalación automática de rclone, zstd, y dependencias
- **Configuración de Cron**: Setup automático de tareas programadas

#### 📚 Documentación Completa
- **README.md**: Documentación principal con ejemplos
- **INSTALACION_Y_USO.md**: Guía detallada de instalación y uso
- **GITHUB_SETUP.md**: Instrucciones para configurar el repositorio en GitHub
- **PROYECTO_COMPLETADO.md**: Resumen del proyecto y funcionalidades
- **Ejemplos Multi-Panel**: Archivos de configuración para cada tipo de panel

### 🔄 Cambios desde V2

#### Agregado
- Sistema de archivos independientes para subida secuencial
- Auto-detección universal de paneles de control
- Configuración externa obligatoria con validación
- Soporte multi-cliente en el mismo servidor
- Instaladores automáticos e interactivos
- Wrapper 'mb' para comandos cortos
- Validación obligatoria de email de notificación
- Documentación exhaustiva y ejemplos

#### Cambiado
- Arquitectura de backup: de archivo único a archivos independientes
- Sistema de configuración: de variables internas a archivos externos
- Estructura de directorios en Google Drive: por fecha y cliente
- Logging: sistema más granular y con rotación
- Validación: más robusta y específica por panel

#### Removido
- Emails hardcodeados del código fuente
- Dependencia de configuración manual específica por servidor
- Archivos de backup únicos (mantenido por compatibilidad)

### 🛠️ Correcciones

#### Seguridad
- Eliminación de emails por defecto del código
- Validación obligatoria de configuración de notificaciones
- Preparación para repositorio público

#### Robustez
- Mejor manejo de fallos en subida secuencial
- Recuperación granular ante errores parciales
- Validación exhaustiva de directorios y configuración

#### Compatibilidad
- Soporte universal para diferentes paneles de control
- Auto-detección de configuraciones no estándar
- Fallback inteligente para instalaciones manuales

## [2.0.0] - 2025-01-28

### Agregado
- Sistema de snapshots con hard links (V2)
- Recuperación inteligente ante fallos
- Validación de conectividad con Google Drive
- Logging avanzado con timestamps
- Verificación de cuota antes del backup
- Optimización por horarios
- Configuración de rendimiento dinámica

### Cambiado
- Arquitectura base usando snapshots para eficiencia
- Sistema de logging más robusto
- Manejo de errores mejorado

## [1.0.0] - 2025-01-27

### Agregado
- Funcionalidad básica de backup Moodle
- Compresión con zstd
- Subida a Google Drive con rclone
- Backup de base de datos MySQL
- Sistema básico de logging
- Configuración básica de variables

---

## 🎯 Próximas Versiones

### Planificado para v3.1.0
- Soporte para bases de datos PostgreSQL
- Backup incremental opcional
- Interfaz web de monitoreo
- Integración con webhooks
- Soporte para múltiples proveedores de almacenamiento

### En Consideración
- Backup de configuraciones de servidor
- Restauración automática desde backups
- Métricas y dashboards
- Integración con sistemas de monitoreo (Zabbix, Nagios)
- Soporte para Docker y Kubernetes

---

## 📝 Notas de Versión

### Compatibilidad
- **V3.x**: Compatible con todas las versiones de Moodle 3.9+
- **Paneles**: cPanel, Plesk, DirectAdmin, VestaCP, HestiaCP, ISPConfig
- **SO**: Ubuntu 18.04+, CentOS 7+, Debian 9+, RHEL 7+

### Migración desde Versiones Anteriores
- **V2 → V3**: Migración automática con `install.sh --upgrade`
- **V1 → V3**: Reconfiguración necesaria, usar `install-interactive.sh`

### Dependencias
- **Requeridas**: bash 4.0+, rclone 1.53+, zstd, mysql-client
- **Opcionales**: cpanel-cli, plesk-cli, directadmin-tools

---

**Nota**: Para ver cambios detallados de cada versión, revisar los commits en el repositorio de GitHub.
