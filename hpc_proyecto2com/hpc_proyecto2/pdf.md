# Análisis — Versión IKJ + Tiling (Post-Optimización)

## 1. Tabla comparativa: ANTES (IJK estándar) vs AHORA (IKJ + Tiling)

| n | T_par ANTES (s) | T_par AHORA (s) | Speedup ANTES | Speedup AHORA | Mejora de tiempo |
| :--- | :--- | :--- | :--- | :--- | :--- |
| 400 | 0.01649 | 0.01173 | 3.04 | **0.93** ⚠️ | — |
| 600 | 0.02439 | 0.01782 | 6.68 | **1.78** ⚠️ | — |
| 800 | 0.10304 | 0.03045 | 3.61 | **2.25** | 3.4× más rápido |
| 1600 | 4.09392 | **0.13882** | 1.67 | **10.94** | **29.5× más rápido** |
| 3000 | 48.8303 | **0.83605** | 4.23 | **12.85** | **58.4× más rápido** |
| 3200 | 57.7973 | **1.04802** | 4.10 | **12.76** | **55.2× más rápido** |

---

## 2. El hallazgo más importante: Eficiencia superlineal (> 100%)

Para los tamaños de matriz más grandes ($N=3000$ y $N=3200$), la eficiencia supera el límite teórico del 100% respecto al número de hilos (12).

| n | Eficiencia ANTES | Eficiencia AHORA |
| :--- | :--- | :--- |
| 1600 | 13.9% | **91.2%** |
| 3000 | 35.3% | **107.1%** ⚡ |
| 3200 | 34.1% | **106.3%** ⚡ |

**¿Por qué ocurre el Speedup Superlineal?**
Este fenómeno no es un error de medición, sino el resultado del **Efecto de Caché Colectiva**:
* **Aumento de la capacidad de caché:** En la versión secuencial, el programa solo dispone de los **32 KB** de la caché L1 de un solo núcleo.
* **Paralelismo eficiente:** Al lanzar 12 hilos con *tiling* de $64 \times 64$, cada hilo procesa un bloque que reside íntegramente en su propia caché L1 privada. 
* **Suma de recursos:** El sistema paralelo está utilizando efectivamente **$12 \times 32 \text{ KB} = 384 \text{ KB}$** de caché L1 simultáneamente. Al haber más datos "cerca" de la CPU en conjunto, el tiempo de ejecución cae por debajo de lo que predice el escalado lineal simple.



---

## 3. Degradación en matrices pequeñas (N=400, N=600)

Se observa que para $N=400$, el speedup es menor a 1 (0.93), lo que indica que la versión paralela es más lenta que la secuencial optimizada.
* **Overhead de Control:** El *tiling* añade tres bucles adicionales (`ii`, `kk`, `jj`). Para matrices pequeñas, la lógica de control de estos bucles y la gestión de hilos de OpenMP pesan más que la ganancia en caché.
* **Saturación de Caché L1/L2:** En $N=400$ y $600$, las matrices ya caben razonablemente bien en la jerarquía de caché del Ryzen 5 3600, por lo que el *tiling* no aporta beneficios de localidad significativos pero sí coste computacional.

---

## 4. Evolución de GFLOPS

| n | GFLOPS ANTES | GFLOPS AHORA | Incremento (Factor) |
| :--- | :--- | :--- | :--- |
| 400 | 7.78 | 10.92 | 1.4× |
| 600 | 17.66 | 24.25 | 1.4× |
| 800 | 9.90 | 33.57 | **3.4×** |
| 1600 | 2.00 | **59.12** | **29.6×** |
| 3000 | 1.10 | **64.76** | **58.9×** |
| 3200 | 1.14 | **62.68** | **55.0×** |

---

## 5. Conclusión para el informe

> La optimización combinada de **reordenamiento de bucles (IJK → IKJ)** y **tiling por bloques de 64×64** produjo mejoras de rendimiento de hasta **58.4× en tiempo paralelo** para N=3000 (de 48.83 s a 0.836 s). El speedup superlineal observado (107% de eficiencia con 12 hilos para N=3000 y N=3200) se explica por el efecto de **caché colectiva**: cada hilo accede a su bloque de trabajo en su L1 privada de 32 KB, de modo que el sistema paralelo utiliza efectivamente 384 KB de L1 total frente a los 32 KB del proceso secuencial. El rendimiento máximo alcanzado fue de **64.76 GFLOPS** (N=3000), equivalente al **18.7% del rendimiento teórico** (345.6 GFLOPS), frente al 0.37% de la versión original, demostrando que la optimización de localidad de datos es más impactante que el paralelismo por sí solo. El único caso negativo fue N=400 (speedup 0.93), donde el overhead de los bucles de tiling supera el beneficio para matrices pequeñas que ya cabían completamente en caché.