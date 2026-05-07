#!/usr/bin/env python3
"""
Convierte archivos .txt de resultados en CSV para abrir en Excel.

Soporta, según el contenido del archivo:
1) `resultados.txt` (formato con separadores `|`)
   Tamaño: 400 | Ejecución 1 | Tiempo: 0.123456s
   CSV: tamano;ejecucion;tiempo_seg

2) `2resultados.txt` (bloques por tamaño para un número fijo de hilos)
   RESULTADOS CON 2 HILOS
   TAMANO 400
   Ejecucion 1 ... Tiempo paralelo: 0.052000 segundos
   CSV: hilos;tamano;ejecucion;tiempo_paralelo_seg;speedup;eficiencia
"""

import argparse
import re
from pathlib import Path

PIPE_FORMAT_LINE = re.compile(
    r"Tamaño:\s*(\d+)\s*\|\s*Ejecución\s*(\d+)\s*\|\s*Tiempo:\s*([\d.]+)s"
)

HILOS_HEADER = re.compile(r"RESULTADOS CON\s*(\d+)\s*HILOS")
HILOS_SIZE = re.compile(r"^TAMANO\s*(\d+)\s*$")
HILOS_EJECUCION = re.compile(r"^Ejecucion\s*(\d+)\s*$")
HILOS_TIEMPO_PARALELO = re.compile(r"^Tiempo paralelo:\s*([\d.]+)\s*segundos")
HILOS_SPEEDUP = re.compile(r"^Speedup:\s*([\d.]+)")
HILOS_EFICIENCIA = re.compile(r"^Eficiencia:\s*([\d.]+)")

PROCESOS_HEADER = re.compile(r"n\s*=\s*(\d+)\s*,\s*procesos\s*=\s*(\d+)")
PROCESOS_EJECUCION = re.compile(
    r"^Ejecuci[oó]n\s*(\d+)\s*\(n=(\d+),\s*procesos=(\d+)\)"
)
# Buscar en toda la línea: el .txt de procesos mezcla prompts de scanf con la salida.
PROCESOS_TIEMPO_SECUENCIAL = re.compile(r"Tiempo secuencial:\s*([\d.]+)\s*segundos")
PROCESOS_TIEMPO_PARALELO = re.compile(r"Tiempo paralelo:\s*([\d.]+)\s*segundos")
PROCESOS_SPEEDUP = re.compile(r"Speedup:\s*([\d.]+)")
PROCESOS_EFICIENCIA = re.compile(r"Eficiencia:\s*([\d.]+)")

def detect_format(text: str) -> str:
    if "RESULTADOS CON" in text:
        return "hilos"
    if "procesos" in text and "Tiempo secuencial" in text:
        return "procesos"
    return "pipe"

def parse_pipe(text: str) -> tuple[list[dict[str, str]], list[str]]:
    rows: list[dict[str, str]] = []
    for raw in text.splitlines():
        line = raw.strip()
        if not line:
            continue
        m = PIPE_FORMAT_LINE.search(line)
        if not m:
            continue
        tamano, ejecucion, tiempo_seg = m.groups()
        rows.append({"tamano": tamano, "ejecucion": ejecucion, "tiempo_seg": tiempo_seg})
    header = ["tamano", "ejecucion", "tiempo_seg"]
    return rows, header

def parse_hilos(text: str) -> tuple[list[dict[str, str]], list[str]]:
    m_hilos = HILOS_HEADER.search(text)
    hilos = m_hilos.group(1) if m_hilos else ""

    rows: list[dict[str, str]] = []
    current_size: str | None = None
    current_exec: str | None = None
    current: dict[str, str] = {}

    for raw in text.splitlines():
        line = raw.strip()
        if not line:
            continue

        m = HILOS_SIZE.match(line)
        if m:
            current_size = m.group(1)
            continue

        m = HILOS_EJECUCION.match(line)
        if m:
            current_exec = m.group(1)
            current = {"hilos": hilos, "tamano": current_size or "", "ejecucion": current_exec}
            continue

        if current_exec is None:
            continue

        m = HILOS_TIEMPO_PARALELO.match(line)
        if m:
            current["tiempo_paralelo_seg"] = m.group(1)
            continue

        m = HILOS_SPEEDUP.match(line)
        if m:
            current["speedup"] = m.group(1)
            continue

        m = HILOS_EFICIENCIA.match(line)
        if m:
            current["eficiencia"] = m.group(1)
            rows.append(current)
            current_exec = None
            current = {}
            continue

    header = ["hilos", "tamano", "ejecucion", "tiempo_paralelo_seg", "speedup", "eficiencia"]
    return rows, header

def parse_procesos(text: str) -> tuple[list[dict[str, str]], list[str]]:
    rows: list[dict[str, str]] = []
    current_size: str | None = None
    current_procesos: str | None = None
    current_exec: str | None = None

    current: dict[str, str] = {}

    for raw in text.splitlines():
        line = raw.strip()
        if not line:
            continue

        m = PROCESOS_HEADER.match(line)
        if m:
            current_size = m.group(1)
            current_procesos = m.group(2)
            continue

        m = PROCESOS_EJECUCION.match(line)
        if m:
            current_exec = m.group(1)
            current = {
                "procesos": m.group(3) if m.group(3) else (current_procesos or ""),
                "tamano": m.group(2) if m.group(2) else (current_size or ""),
                "ejecucion": current_exec,
            }
            current.pop("tiempo_secuencial_seg", None)
            current.pop("tiempo_paralelo_seg", None)
            current.pop("speedup", None)
            current.pop("eficiencia", None)
            continue

        if current_exec is None:
            continue

        m = PROCESOS_TIEMPO_SECUENCIAL.search(line)
        if m and "tiempo_secuencial_seg" not in current:
            current["tiempo_secuencial_seg"] = m.group(1)
            continue

        m = PROCESOS_TIEMPO_PARALELO.search(line)
        if m:
            current["tiempo_paralelo_seg"] = m.group(1)
            continue

        m = PROCESOS_SPEEDUP.search(line)
        if m:
            current["speedup"] = m.group(1)
            continue

        m = PROCESOS_EFICIENCIA.search(line)
        if m:
            current["eficiencia"] = m.group(1)
            rows.append(current)
            current_exec = None
            current = {}
            continue

    header = [
        "procesos",
        "tamano",
        "ejecucion",
        "tiempo_secuencial_seg",
        "tiempo_paralelo_seg",
        "speedup",
        "eficiencia",
    ]
    return rows, header

def parse_hilos_v2(text: str) -> tuple[list[dict[str, str]], list[str]]:
    rows: list[dict[str, str]] = []
    current_size: str | None = None
    current_hilos: str | None = None
    current_exec: str | None = None
    current: dict[str, str] = {}

    hilos_header = re.compile(r"n\s*=\s*(\d+)\s*,\s*hilos\s*=\s*(\d+)")
    hilos_ejecucion = re.compile(r"^Ejecuci[oó]n\s*(\d+)\s*\(n=(\d+),\s*hilos=(\d+)\)")

    tiempo_secuencial = re.compile(r"Tiempo secuencial:\s*([\d.]+)\s*segundos")
    tiempo_paralelo = PROCESOS_TIEMPO_PARALELO
    speedup = PROCESOS_SPEEDUP
    eficiencia = PROCESOS_EFICIENCIA

    for raw in text.splitlines():
        line = raw.strip()
        if not line:
            continue

        m = hilos_header.match(line)
        if m:
            current_size = m.group(1)
            current_hilos = m.group(2)
            continue

        m = hilos_ejecucion.match(line)
        if m:
            current_exec = m.group(1)
            current = {
                "hilos": m.group(3) if m.group(3) else (current_hilos or ""),
                "tamano": m.group(2) if m.group(2) else (current_size or ""),
                "ejecucion": current_exec,
            }
            current.pop("tiempo_secuencial_seg", None)
            current.pop("tiempo_paralelo_seg", None)
            current.pop("speedup", None)
            current.pop("eficiencia", None)
            continue

        if current_exec is None:
            continue

        m = tiempo_secuencial.search(line)
        if m and "tiempo_secuencial_seg" not in current:
            current["tiempo_secuencial_seg"] = m.group(1)
            continue

        m = tiempo_paralelo.search(line)
        if m:
            current["tiempo_paralelo_seg"] = m.group(1)
            continue

        m = speedup.search(line)
        if m:
            current["speedup"] = m.group(1)
            continue

        m = eficiencia.search(line)
        if m:
            current["eficiencia"] = m.group(1)
            rows.append(current)
            current_exec = None
            current = {}
            continue

    header = [
        "hilos",
        "tamano",
        "ejecucion",
        "tiempo_secuencial_seg",
        "tiempo_paralelo_seg",
        "speedup",
        "eficiencia",
    ]
    return rows, header

def write_csv(output_csv: Path, rows: list[dict[str, str]], header: list[str]) -> None:
    output_csv.parent.mkdir(parents=True, exist_ok=True)
    with output_csv.open("w", encoding="utf-8") as out:
        out.write(";".join(header) + "\n")
        for r in rows:
            out.write(";".join(r.get(k, "") for k in header) + "\n")


def convert_txt_to_csv(input_path: Path, output_path: Path | None = None) -> tuple[Path, int]:
    input_path = input_path.resolve()
    out = output_path.resolve() if output_path else input_path.with_suffix(".csv")
    text = input_path.read_text(encoding="utf-8", errors="replace")
    fmt = detect_format(text)
    if fmt == "hilos":
        rows, header = parse_hilos(text)
    elif fmt == "procesos":
        rows, header = parse_procesos(text)
    elif fmt == "hilos_v2":
        rows, header = parse_hilos_v2(text)
    else:
        rows, header = parse_pipe(text)
    write_csv(out, rows, header)
    return out, len(rows)


def main() -> None:
    parser = argparse.ArgumentParser(description="Convierte .txt de resultados a CSV para Excel.")
    parser.add_argument("input_file", nargs="?", default="resultados.txt", help="Archivo .txt de entrada")
    parser.add_argument(
        "output_csv",
        nargs="?",
        default=None,
        help="Archivo .csv de salida (por defecto: <input_file>.csv)",
    )
    args = parser.parse_args()

    input_path = Path(args.input_file)
    output_path = Path(args.output_csv) if args.output_csv else None
    out, n = convert_txt_to_csv(input_path, output_path)
    print(f"Listo. Se generó {out.name} con {n} filas.")
    print("Abre el archivo en Excel (separador: punto y coma ;)")


if __name__ == "__main__":
    main()
