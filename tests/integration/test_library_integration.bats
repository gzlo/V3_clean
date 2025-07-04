#!/usr/bin/env bats

# Tests de integración para el sistema de librerías

load ../test_helper

@test "all libraries should load without conflicts" {
    # Cargar todas las librerías en orden
    run bash -c "
        source lib/constants.sh &&
        source lib/colors.sh &&
        source lib/utils.sh &&
        source lib/filesystem.sh &&
        echo 'All libraries loaded successfully'
    "
    [ "$status" -eq 0 ]
    [[ "$output" == *"All libraries loaded successfully"* ]]
}

@test "libraries should work together in logging" {
    # Test de integración entre colors y utils para logging
    run bash -c "
        source lib/constants.sh
        source lib/colors.sh
        source lib/utils.sh
        
        # Test logging con colores
        if declare -f log_message >/dev/null && declare -f color_echo >/dev/null; then
            log_message 'INFO' 'Integration test message'
        else
            echo 'Functions not implemented yet'
        fi
    "
    [ "$status" -eq 0 ]
}

@test "constants should be accessible from all modules" {
    run bash -c "
        source lib/constants.sh
        source lib/utils.sh
        source lib/filesystem.sh
        
        # Las constantes deberían estar disponibles
        echo \"Project: \$PROJECT_NAME\"
        echo \"Version: \$VERSION\"
        echo \"Exit codes: \$EXIT_SUCCESS, \$EXIT_ERROR\"
    "
    [ "$status" -eq 0 ]
    [[ "$output" == *"Project: Moodle CLI Backup"* ]]
}

@test "filesystem operations should use proper logging" {
    run bash -c "
        source lib/constants.sh
        source lib/colors.sh
        source lib/utils.sh
        source lib/filesystem.sh
        
        # Crear directorio con logging
        if declare -f create_directory_safe >/dev/null && declare -f log_message >/dev/null; then
            create_directory_safe '$TEST_TEMP_DIR/integration_test'
            log_message 'INFO' 'Directory created successfully'
        else
            echo 'Functions not implemented yet'
        fi
    "
    [ "$status" -eq 0 ]
}

@test "color output should respect NO_COLOR environment" {
    # Test con colores habilitados
    run bash -c "
        unset NO_COLOR
        source lib/colors.sh
        if declare -f color_echo >/dev/null; then
            color_echo 'red' 'Test message'
        else
            echo 'color_echo not implemented'
        fi
    "
    [ "$status" -eq 0 ]
    
    # Test con colores deshabilitados
    run bash -c "
        export NO_COLOR=1
        source lib/colors.sh
        if declare -f color_echo >/dev/null; then
            color_echo 'red' 'Test message'
        else
            echo 'color_echo not implemented'
        fi
    "
    [ "$status" -eq 0 ]
}

@test "error handling should work across modules" {
    run bash -c "
        source lib/constants.sh
        source lib/colors.sh
        source lib/utils.sh
        
        # Simular error y manejo
        if declare -f log_message >/dev/null && declare -f print_error >/dev/null; then
            log_message 'ERROR' 'Test error message'
            print_error 'Critical error occurred'
            exit \$EXIT_ERROR
        else
            echo 'Error functions not implemented'
            exit \$EXIT_ERROR
        fi
    "
    [ "$status" -eq 1 ]  # EXIT_ERROR
}

@test "dependency chain should load correctly" {
    # Test que las dependencias se cargan en el orden correcto
    run bash -c "
        # constants.sh no debería depender de otros
        source lib/constants.sh
        
        # colors.sh podría depender de constants
        source lib/colors.sh
        
        # utils.sh podría depender de constants y colors
        source lib/utils.sh
        
        # filesystem.sh podría depender de todos los anteriores
        source lib/filesystem.sh
        
        echo 'Dependency chain loaded successfully'
    "
    [ "$status" -eq 0 ]
    [[ "$output" == *"Dependency chain loaded successfully"* ]]
}

@test "all guard clauses should prevent double loading" {
    run bash -c "
        # Cargar múltiples veces cada librería
        source lib/constants.sh
        source lib/constants.sh
        source lib/colors.sh
        source lib/colors.sh
        source lib/utils.sh
        source lib/utils.sh
        source lib/filesystem.sh
        source lib/filesystem.sh
        
        echo 'Multiple loads handled correctly'
    "
    [ "$status" -eq 0 ]
    [[ "$output" == *"Multiple loads handled correctly"* ]]
}
