# 📋 Aviso de Migración: CPANEL_USER → PANEL_USER

## 🔄 Cambio de Nomenclatura

Para hacer el script más universal y menos confuso, hemos cambiado el nombre de la variable:

**ANTES:**
```bash
CPANEL_USER=dev4hc
```

**AHORA:**
```bash
PANEL_USER=dev4hc
```

## ✅ Compatibilidad Hacia Atrás

**No necesitas cambiar nada inmediatamente.** El script sigue funcionando con `CPANEL_USER` por compatibilidad.

## 🎯 ¿Por Qué Este Cambio?

- **Claridad**: `PANEL_USER` es más descriptivo para todos los paneles
- **Universalidad**: Funciona con cPanel, Plesk, DirectAdmin, VestaCP, etc.
- **Menos Confusión**: No sugiere que solo funciona con cPanel

## 📝 Cómo Actualizar Tu Configuración

### Opción 1: Actualizar gradualmente
El script detecta automáticamente `CPANEL_USER` y lo usa como `PANEL_USER`.

### Opción 2: Actualizar ahora
Cambiar en tu archivo `/etc/moodle_backup.conf`:
```bash
# ANTES
CPANEL_USER=dev4hc
WWW_DIR="/home/${CPANEL_USER}/public_html/"
MOODLEDATA_DIR="/home/${CPANEL_USER}/moodledata"

# DESPUÉS  
PANEL_USER=dev4hc
WWW_DIR="/home/${PANEL_USER}/public_html/"
MOODLEDATA_DIR="/home/${PANEL_USER}/moodledata"
```

## 🛡️ Sin Riesgo de Interrupción

- ✅ Las configuraciones existentes siguen funcionando
- ✅ No hay cambios en funcionalidad
- ✅ Solo cambia el nombre de la variable
- ✅ La migración es opcional y gradual

## 📚 Recursos

- Ver ejemplos actualizados en `moodle_backup.conf.example`
- El script muestra mensajes informativos sobre la compatibilidad
- Logs indican cuándo se usa compatibilidad hacia atrás
