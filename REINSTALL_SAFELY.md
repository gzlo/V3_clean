# 🛡️ GUÍA PARA REINSTALAR SIN PERDER CONFIGURACIONES

## ⚠️ IMPORTANTE: Los scripts de instalación SOBRESCRIBEN archivos

Cuando reinstales Moodle Backup V3, los siguientes archivos **SE SOBRESCRIBEN SIN AVISO**:

- ✅ **`moodle_backup.sh`** - Script principal
- ✅ **`mb`** - Wrapper de comandos  
- ✅ **`moodle_backup.conf.example`** - Archivo de ejemplo

### 🔒 Archivos que SÍ se preservan:

- ✅ **`moodle_backup.conf`** - Tu configuración real
- ✅ **Configuración de rclone** - Solo pregunta si reconfigurar
- ✅ **Alias de bash** - Solo agrega si no existe

---

## 📋 PROCESO SEGURO DE REINSTALACIÓN

### 1️⃣ **ANTES de reinstalar - Hacer Backup**

```bash
# Ejecutar script de backup automático
./backup-before-reinstall.sh
```

Este script:
- 🗂️ Hace backup de todas tus configuraciones
- 📁 Guarda archivos modificados recientemente
- ⏰ Preserva tareas cron
- 🔧 Incluye configuración de rclone
- 🔄 Crea script de restauración automática

### 2️⃣ **Reinstalar normalmente**

```bash
# Cualquiera de estos métodos
curl -fsSL https://raw.githubusercontent.com/tu-usuario/moodle-backup/main/install.sh | bash
wget -qO- https://raw.githubusercontent.com/tu-usuario/moodle-backup/main/install.sh | bash
```

### 3️⃣ **DESPUÉS de reinstalar - Restaurar**

```bash
# El script de backup te dirá la ubicación exacta
~/moodle-backup-personal-XXXXXXXX/restore.sh
```

---

## 🔍 VERIFICACIÓN POST-REINSTALACIÓN

Después de restaurar, verificar que todo funciona:

```bash
# Verificar configuración
mb config

# Probar conectividad
mb test

# Ver versión (debe ser 3.0.3 o superior)
mb version

# Hacer prueba de backup
mb --test-rclone
```

---

## 🚨 SI ALGO SALE MAL

Si tienes problemas después de la reinstalación:

1. **Revisar logs**: `mb logs`
2. **Diagnóstico completo**: `mb diagnose`
3. **Verificar permisos**: Los archivos deben ser ejecutables
4. **Revisar el backup**: Todos tus archivos están en el directorio de backup

---

## 💡 CONSEJOS IMPORTANTES

- ✅ **Siempre haz backup antes de reinstalar**
- ✅ **Mantén una copia de tus configuraciones en otro lugar**
- ✅ **Documenta tus modificaciones personales**
- ✅ **Prueba el backup/restore en un entorno de prueba primero**

---

## 📞 RESOLUCIÓN DE PROBLEMAS

Si el script de backup no encuentra tus archivos:

```bash
# Buscar manualmente dónde están instalados
find /usr -name "moodle_backup.sh" 2>/dev/null
find /home -name "moodle_backup.conf" 2>/dev/null
which mb
```

Luego ajustar las rutas en el script de backup si es necesario.
