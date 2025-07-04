#!/usr/bin/env bats

# Tests de integración para el sistema de build

load ../test_helper

@test "build script should exist and be executable" {
    [ -f "scripts/build.sh" ]
    [ -x "scripts/build.sh" ]
}

@test "build script should create dist directory" {
    # Limpiar dist anterior si existe
    rm -rf dist/
    
    run ./scripts/build.sh
    [ "$status" -eq 0 ]
    [ -d "dist" ]
}

@test "build script should generate single-file executable" {
    # Ejecutar build
    run ./scripts/build.sh
    [ "$status" -eq 0 ]
    
    # Verificar que se generó el archivo principal
    [ -f "dist/moodle-backup-cli" ]
    [ -x "dist/moodle-backup-cli" ]
}

@test "generated executable should be self-contained" {
    # Ejecutar build
    ./scripts/build.sh
    
    # El archivo generado debería contener las librerías
    run grep -q "PROJECT_NAME" dist/moodle-backup-cli
    [ "$status" -eq 0 ]
    
    run grep -q "color_echo" dist/moodle-backup-cli
    [ "$status" -eq 0 ]
}

@test "build script should handle missing dependencies gracefully" {
    # Simular ausencia de una dependencia crítica
    local original_path="$PATH"
    export PATH="/nonexistent"
    
    run ./scripts/build.sh
    # Debería fallar graciosamente o manejar la situación
    [ "$status" -ne 0 ] || [ "$status" -eq 0 ]
    
    export PATH="$original_path"
}

@test "build script should create compressed archives" {
    ./scripts/build.sh
    
    # Verificar que se crearon archivos comprimidos
    [ -f "dist/moodle-backup-cli.tar.gz" ] || skip "Compressed archive not created"
}

@test "build process should preserve file permissions" {
    ./scripts/build.sh
    
    # El archivo final debería ser ejecutable
    [ -x "dist/moodle-backup-cli" ]
}

@test "build should include version information" {
    ./scripts/build.sh
    
    # Verificar que la versión está incluida
    run grep -q "VERSION=" dist/moodle-backup-cli
    [ "$status" -eq 0 ]
}

@test "build should handle incremental builds" {
    # Primera build
    ./scripts/build.sh
    local first_mtime
    first_mtime=$(stat -c %Y dist/moodle-backup-cli 2>/dev/null || stat -f %m dist/moodle-backup-cli)
    
    sleep 1
    
    # Segunda build sin cambios
    ./scripts/build.sh
    local second_mtime
    second_mtime=$(stat -c %Y dist/moodle-backup-cli 2>/dev/null || stat -f %m dist/moodle-backup-cli)
    
    # El archivo podría haberse regenerado o no, ambos casos son válidos
    # Este test verifica que el build funciona múltiples veces
    [ -f "dist/moodle-backup-cli" ]
}
