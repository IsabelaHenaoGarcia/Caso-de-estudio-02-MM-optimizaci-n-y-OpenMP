#!/bin/bash

set -e

echo "Compilando matrizsecuencial.c con -O3..."
gcc -O3 matrizsecuencial.c -o matrizsecuencial || { echo "Error al compilar"; exit 1; }

sizes=(400 600 800 1600 3000 3200)
out="resultados.txt"
> "${out}"

echo "=== Pruebas por tamaño | matrizsecuencial.c | gcc -O3 ===" | tee -a "${out}"

for n in "${sizes[@]}"; do
    for run in $(seq 1 10); do
        result=$(echo "${n}" | ./matrizsecuencial)

        tiempo=$(echo "${result}" | grep -oP 'TIEMPO=\K[0-9.]+')

        line="Tamaño: ${n} | Ejecución ${run} | Tiempo: ${tiempo}s"
        echo "${line}" | tee -a "${out}"
    done
done

echo ""
echo "Pruebas finalizadas. Resultados en ${out}"
