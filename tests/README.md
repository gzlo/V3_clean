# 🧪 Directorio de Tests - Moodle Backup V3

Este directorio contiene todos los archivos relacionados con pruebas, desarrollo y validaciones del sistema Moodle Backup V3.

## 📁 Contenido

### 🔧 Scripts de Prueba
- **`run-tests.sh`** - Script principal de pruebas y validaciones
- **`test-config.conf`** - Configuración de prueba para desarrollo
- **`test-install.sh`** - Pruebas del proceso de instalación
- **`moodle_backup.conf.example`** - Archivo de configuración de ejemplo

### 🎯 Propósito

Este directorio está **excluido del repositorio de producción** mediante `.gitignore` para mantener el código limpio y profesional.

## 🚀 Uso

### Ejecutar Pruebas Completas
```bash
cd tests
chmod +x run-tests.sh
./run-tests.sh
```

### Verificaciones Incluidas
1. **Sintaxis de scripts** - Validación bash de todos los archivos principales
2. **Configuraciones** - Verificación de archivos de configuración
3. **Asignación de variables** - Prueba de funciones críticas corregidas
4. **Estructura de archivos** - Verificación de archivos requeridos
5. **Configuración de test** - Carga y validación de configuración de prueba

## 📋 Archivos de Test

### `test-config.conf`
Configuración mínima y segura para pruebas de desarrollo que no afecta sistemas de producción.

**Características:**
- Directorios temporales (`/tmp/`)
- Base de datos de test
- Un solo backup en Google Drive
- Logs en directorio temporal
- Email de prueba

## ⚠️ Importante

- **NO usar configuraciones de test en producción**
- Los archivos de este directorio no se suben al repositorio
- Mantener este directorio local para desarrollo y validaciones

## 🔒 Seguridad

Los archivos de configuración de test:
- Usan directorios temporales
- No contienen credenciales reales
- Están diseñados para no afectar sistemas productivos

## 📝 Desarrollo

Para agregar nuevas pruebas:
1. Crear archivos con prefijo `test-*`
2. Usar configuración de `test-config.conf`
3. Asegurar que no afecten producción
4. Actualizar `run-tests.sh` si es necesario
