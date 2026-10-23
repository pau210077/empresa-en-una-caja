#!/usr/bin/env python3
"""Genera las imágenes del simulacro a partir de resultados/simulacro.json.

Todo sale de los datos reales de la ejecución: los tiempos, los nombres y los tamaños
vienen del JSON que escribe Invoke-Simulacro.ps1. Nada está dibujado a mano.

Salidas (en docs/img/simulacro/):
  - linea-de-tiempo.png        ataque y recuperación con los segundos reales
  - antes-durante-despues.png  tres vistas de la carpeta estilo explorador de Windows
  - simulacro.gif               las tres vistas animadas
"""
import json
import math
import os
import pathlib
from datetime import datetime

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402
from PIL import Image, ImageDraw, ImageFont  # noqa: E402

RAIZ = pathlib.Path(__file__).resolve().parent.parent
ENTRADA = pathlib.Path(os.environ.get("SIMULACRO_JSON", RAIZ / "resultados" / "simulacro.json"))
SALIDA = pathlib.Path(os.environ.get("SIMULACRO_SALIDA", RAIZ / "docs" / "img" / "simulacro"))

COLORES_FASE = {
    "ataque": "#c0392b",
    "deteccion": "#e67e22",
    "restauracion": "#2980b9",
    "verificacion": "#27ae60",
}
NOMBRES_FASE = {
    "ataque": "Ataque",
    "deteccion": "Detección",
    "restauracion": "Restauración",
    "verificacion": "Verificación",
}

ANCHO_VISTA = 700
ALTO_VISTA = 420
FILAS_VISIBLES = 13


def fuente(tamano, negrita=False):
    nombres = ["DejaVuSans-Bold.ttf" if negrita else "DejaVuSans.ttf", "Arial Bold.ttf" if negrita else "Arial.ttf"]
    for nombre in nombres:
        try:
            return ImageFont.truetype(nombre, tamano)
        except OSError:
            continue
    return ImageFont.load_default(size=tamano)


def linea_de_tiempo(datos, ruta):
    fig, ax = plt.subplots(figsize=(10, 3.4), dpi=150)
    for fase in datos["linea_de_tiempo"]:
        duracion = fase["fin_s"] - fase["inicio_s"]
        ax.barh(0, duracion, left=fase["inicio_s"], height=0.5, color=COLORES_FASE[fase["fase"]])
        etiqueta = f'{NOMBRES_FASE[fase["fase"]]}\n{duracion:.1f} s'
        ax.text(fase["inicio_s"] + duracion / 2, 0.38, etiqueta, ha="center", va="bottom", fontsize=9)
    ax.set_yticks([])
    ax.set_ylim(-0.6, 1.2)
    ax.set_xlabel("segundos desde el inicio del ataque")
    ax.spines[["top", "right", "left"]].set_visible(False)
    ax.set_title(
        f'Ataque y recuperación: {datos["recuperacion_minutos"]:.2f} min desde la detección '
        f'({datos["identicos"]}/{datos["archivos"]} ficheros idénticos)',
        fontsize=11,
        loc="left",
    )
    fig.tight_layout()
    fig.savefig(ruta)
    plt.close(fig)


def formatear_tamano(bytes_):
    if bytes_ < 1024:
        return f"{bytes_} bytes"
    return f"{math.ceil(bytes_ / 1024)} KB"


def tipo_archivo(nombre):
    if nombre.endswith(".bloqueado"):
        return "Archivo BLOQUEADO"
    if nombre == "LEEME_RESCATE.txt":
        return "Documento de texto"
    if nombre.endswith(".csv"):
        return "Hoja de cálculo CSV"
    return "Documento de texto"


def dibujar_explorador(filas, etiqueta, color_etiqueta, fecha, titulo):
    img = Image.new("RGB", (ANCHO_VISTA, ALTO_VISTA), (255, 255, 255))
    d = ImageDraw.Draw(img)
    f_normal = fuente(14)
    f_negrita = fuente(14, negrita=True)
    f_pequena = fuente(12)

    # Barra de título y etiqueta de fase
    d.rectangle([0, 0, ANCHO_VISTA, 40], fill=(243, 243, 243))
    d.text((12, 11), titulo, font=f_normal, fill=(30, 30, 30))
    d.rounded_rectangle([ANCHO_VISTA - 330, 8, ANCHO_VISTA - 10, 32], radius=8, fill=color_etiqueta)
    d.text((ANCHO_VISTA - 320, 12), etiqueta, font=f_negrita, fill=(255, 255, 255))

    # Cabecera de columnas
    y = 52
    columnas = [(14, "Nombre"), (330, "Fecha de modificación"), (500, "Tipo"), (630, "Tamaño")]
    for x, texto in columnas:
        d.text((x, y), texto, font=f_pequena, fill=(90, 90, 90))
    d.line([(10, y + 22), (ANCHO_VISTA - 10, y + 22)], fill=(220, 220, 220))

    # Filas
    y += 30
    for fila in filas[:FILAS_VISIBLES]:
        nombre = fila["nombre"]
        if nombre == "LEEME_RESCATE.txt":
            d.rectangle([8, y - 4, ANCHO_VISTA - 8, y + 20], fill=(255, 243, 205))
            fuente_fila = f_negrita
            color = (30, 30, 30)
        elif nombre.endswith(".bloqueado"):
            fuente_fila = f_normal
            color = (192, 57, 43)
        else:
            fuente_fila = f_normal
            color = (30, 30, 30)
        d.text((14, y), nombre, font=fuente_fila, fill=color)
        d.text((330, y), fecha, font=f_pequena, fill=(90, 90, 90))
        d.text((500, y), tipo_archivo(nombre), font=f_pequena, fill=(90, 90, 90))
        d.text((630, y), formatear_tamano(fila["tamanio"]), font=f_pequena, fill=(90, 90, 90))
        y += 24

    if len(filas) > FILAS_VISIBLES:
        d.text((14, y + 4), f"... y {len(filas) - FILAS_VISIBLES} elementos más", font=f_pequena, fill=(110, 110, 110))

    # Barra de estado
    d.rectangle([0, ALTO_VISTA - 26, ANCHO_VISTA, ALTO_VISTA], fill=(243, 243, 243))
    d.text((12, ALTO_VISTA - 20), f"{len(filas)} elementos", font=f_pequena, fill=(90, 90, 90))
    return img


def vistas(datos):
    vista = datos["vista"]
    fecha = datetime.fromisoformat(datos["fecha_inicio"]).strftime("%d/%m/%Y %H:%M")
    titulo = f'Z:\\{vista["carpeta"]}'
    return [
        (dibujar_explorador(vista["antes"], "ANTES", (39, 174, 96), fecha, titulo), "ANTES"),
        (dibujar_explorador(vista["durante"], "DURANTE EL ATAQUE", (192, 57, 43), fecha, titulo), "DURANTE"),
        (dibujar_explorador(vista["despues"], "DESPUÉS DE LA RECUPERACIÓN", (41, 128, 185), fecha, titulo), "DESPUÉS"),
    ]


def tres_fases(datos, ruta):
    frames = [img for img, _ in vistas(datos)]
    margen = 20
    lienzo = Image.new("RGB", (3 * ANCHO_VISTA + 4 * margen, ALTO_VISTA + 2 * margen), (250, 250, 250))
    for i, img in enumerate(frames):
        lienzo.paste(img, (margen + i * (ANCHO_VISTA + margen), margen))
    lienzo.save(ruta, optimize=True)


def gif(datos, ruta):
    frames = [img for img, _ in vistas(datos)]
    duraciones = [2500, 2500, 3500]
    frames[0].save(
        ruta,
        save_all=True,
        append_images=frames[1:],
        duration=duraciones,
        loop=0,
        optimize=True,
    )


def main():
    if not ENTRADA.exists():
        raise SystemExit(f"No existe {ENTRADA}. Ejecuta antes scripts/Invoke-Simulacro.ps1.")
    datos = json.loads(ENTRADA.read_text(encoding="utf-8"))
    SALIDA.mkdir(parents=True, exist_ok=True)
    linea_de_tiempo(datos, SALIDA / "linea-de-tiempo.png")
    tres_fases(datos, SALIDA / "antes-durante-despues.png")
    gif(datos, SALIDA / "simulacro.gif")
    print(f"Imágenes generadas en {SALIDA}")


if __name__ == "__main__":
    main()
