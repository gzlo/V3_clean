# 📋 Historial de Cambios - Moodle Backup V3

Todos los cambios importantes de este proyecto se documentan en este archivo.

El formato está basado en [Keep a Changelog](https://keepachangelog.com/es/1.0.0/),
y este proyecto se adhiere al [Versionado Semántico](https://semver.org/lang/es/).

## [3.2.0] - 2025-07-02

### 🐛 Correcciones Críticas

#### ✅ Errores Solucionados
- **Corregido error de tipeo**: `AUTO_DETECT_AGRESSIVE` → `AUTO_DETECT_AGGRESSIVE`
- **Solucionado problema de scope de variables**: Eliminadas declaraciones `local` que impedían asignación correcta
- **Arreglado script `mb`**: Eliminado contenido suelto que causaba loop infinito con error `COMANDOS: command not found`
- **Corregida detección de paneles**: Eliminado `log_step` de `detect_control_panel()` que contaminaba el output
- **Mejorada configuración de cron**: Agregadas validaciones para evitar formatos inválidos

#### 🔧 Mejoras de Estabilidad
- **Asignación dual de variables**: Método robusto usando `declare -g` + `eval` con verificación
- **Validación de parámetros**: Verificación de `CLIENT_NAME`, `CRON_FREQUENCY` y `CRON_HOUR` antes de configurar cron
- **Manejo de errores mejorado**: Mensajes más claros y descriptivos
- **Función `show_wrapper_help()`**: Agregada función faltante en script `mb`

#### 🧪 Verificaciones Agregadas
- **Validación de sintaxis**: Verificación automática con `bash -n`
- **Pruebas de asignación**: Script de prueba para verificar funcionamiento de variables
- **Verificación de éxito**: Comprobación de que las variables se asignan correctamente

#### 📋 Funcionalidad Corregida
- **Resumen de configuración**: Ahora muestra todos los valores correctamente
- **Archivos de configuración**: Se guardan con nombres válidos (CLIENT_NAME no vacío)
- **Comando `mb`**: Funciona sin loops ni errores de comandos no encontrados
- **Lista de configuraciones**: El comando `mb list` encuentra archivos correctamente

## [3.1.0] - 2025-07-01

### 🎯 Configuración Inteligente y Auto-Detección

#### ✨ Nuevas Funcionalidades
- **Auto-detección de paneles de control**: Detecta automáticamente cPanel, Plesk, DirectAdmin, VestaCP, ISPConfig
- **Lectura automática de config.php**: Extrae configuración de base de datos y moodledata automáticamente
- **Extracción automática de dominio**: Obtiene el dominio desde la configuración de Moodle
- **Ejemplos dinámicos de rutas**: Los ejemplos cambian según el panel detectado
- **Validación inteligente de campos**: Solo requiere campos obligatorios según el contexto

#### 🔧 Mejoras en la Experiencia de Usuario
- **Interfaz más limpia**: Reducción de emojis en preguntas para mejor legibilidad
- **Descripciones mejoradas**: Explicaciones más claras para cada campo
- **Campos opcionales**: Marcados claramente como no obligatorios
- **Valores predeterminados inteligentes**: Basados en configuración detectada automáticamente
- **Flujo optimizado**: Menos preguntas manuales gracias a la auto-detección

#### 🛠️ Funciones Técnicas Agregadas
- `detect_control_panel()`: Detecta automáticamente el tipo de panel de control
- `read_moodle_config()`: Lee y parsea config.php de Moodle
- `get_path_examples()`: Retorna ejemplos apropiados según el panel
- `extract_domain_from_url()`: Extrae dominio de URLs completas
- Parámetro `required` en `ask_with_default()` para campos opcionales

#### 📋 Mejoras Específicas
- **Dominio opcional**: Solo obligatorio para Plesk, opcional para otros paneles
- **Configuración de BD inteligente**: Usa valores detectados como predeterminados
- **Auto-detección de moodledata**: Se obtiene automáticamente desde config.php
- **Gestión de contraseñas mejorada**: Mejor integración con config.php detectado

## [3.0.0] - 2025-07-01

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
- **Validación Exhaustiva**: Validación exhaustiva de configuración y directorios
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

## Historial de Versiones Anteriores

### [2.x] - 2024-2025
- Sistema de backup básico multi-panel
- Configuración manual requerida
- Comando `mb` simple
- Auto-detección básica de entornos

### [1.x] - 2024
- Sistema inicial de backup para Moodle
- Configuración completamente manual
- Soporte limitado de paneles
- Scripts independientes

---

## 📝 Notas de Desarrollo

### Convenciones de Commit
Este proyecto utiliza [Conventional Commits](https://conventionalcommits.org/) en español:

- `feat(scope): nueva funcionalidad`
- `fix(scope): corrección de errores`
- `docs(scope): actualización de documentación`
- `refactor(scope): refactorización de código`
- `test(scope): pruebas`
- `chore(scope): tareas de mantenimiento`

### Versionado
- **MAJOR**: Cambios incompatibles en la API/interfaz
- **MINOR**: Nueva funcionalidad compatible hacia atrás
- **PATCH**: Correcciones de errores compatibles

### Roadmap
- [ ] Dashboard web para gestión visual
- [ ] Soporte para múltiples destinos de backup
- [ ] Sistema de restore automatizado
- [ ] Métricas y reportes avanzados
- [ ] API REST para integración externa

---

**¿Encontraste un bug o tienes una sugerencia?** 
[Abre un issue en GitHub](https://github.com/gzlo/moodle-backup/issues) 🐛

**¿Quieres contribuir?** 
[Lee nuestra guía de contribución](CONTRIBUTING.md) 🤝
