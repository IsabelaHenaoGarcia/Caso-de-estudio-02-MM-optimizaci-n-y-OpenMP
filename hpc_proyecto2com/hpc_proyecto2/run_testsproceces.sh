#!/bin/bash

# Compilar el programa (sin -fopenmp, ya no se usa)
gcc matrizprocces.c -o matrizprocces || { echo "Error al compilar"; exit 1; }

# Tamaños de matriz
sizes=(400 600 800 1600 3000 3200)

# Número de PROCESOS
processes=(2 4 16)

# Archivo de salida
out="resultados_procesos2416.txt"
> "$out"

for n in "${sizes[@]}"; do
  for p in "${processes[@]}"; do
    echo "===============================" | tee -a "$out"
    echo "n = $n, procesos = $p" | tee -a "$out"
    echo "===============================" | tee -a "$out"
    for run in {1..10}; do
      echo "Ejecución $run (n=$n, procesos=$p)" | tee -a "$out"
      printf "%d\n%d\n" "$n" "$p" | ./matrizprocces >> "$out"
      echo "" >> "$out"
    done
    echo "" >> "$out"
  done
done

echo "Pruebas finalizadas. Resultados en $out"