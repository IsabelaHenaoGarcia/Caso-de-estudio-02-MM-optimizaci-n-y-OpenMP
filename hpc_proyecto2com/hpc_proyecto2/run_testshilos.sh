#!/bin/bash

set -e

# Compilar versión paralela con OpenMP
gcc matriz2.c -o matriz2 -fopenmp || { echo "Error al compilar matriz2.c"; exit 1; }

sizes=(400 600 800 1600 3000 3200)
threads=(2 4 8 16)

out="resultados.txt"
> "${out}"

for h in "${threads[@]}"; do
    {
        echo "====================================="
        echo "RESULTADOS CON ${h} HILOS"
        echo "====================================="
        echo
    } >> "${out}"

        for n in "${sizes[@]}"; do
        {
            echo "==============================="
            echo "TAMANO ${n}"
            echo "==============================="
        } >> "${out}"

        for run in $(seq 1 10); do
            # Ejecutar matriz2 y capturar su salida
            result=$(printf "%d\n%d\n" "${n}" "${h}" | ./matriz2)

            # Guardar en resultados.txt con el formato esperado por resultados_a_excel.py
            {
                echo "Ejecucion ${run}"
                echo "${result}"
                echo
            } >> "${out}"

            # Mostrar cada ejecución en consola de forma resumida
            tiempo_par=$(echo "${result}" | grep -oP 'Tiempo paralelo:\s+\K[0-9.]+')
            speedup=$(echo "${result}"     | grep -oP 'Speedup:\s+\K[0-9.]+')
            eficiencia=$(echo "${result}"  | grep -oP 'Eficiencia:\s+\K[0-9.]+')

            echo "Tamaño: ${n} | Hilos: ${h} | Ejecución ${run} | TiempoParalelo: ${tiempo_par}s | Speedup: ${speedup} | Eficiencia: ${eficiencia}"
        done

        echo >> "${out}"
    done

    echo >> "${out}"
done

echo "Pruebas finalizadas. Resultados en ${out}"
