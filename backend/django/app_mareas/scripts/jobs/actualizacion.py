"""
===============================================================
Actualización y caché de mareas + pronóstico (pieza central)
===============================================================

Resumen (para reclutadores)
- Integra dos fuentes públicas: hidrometría del INA (Instituto Nacional del Agua) y pronóstico del SMN (Servicio Meteorológico Nacional).
- Calcula métricas por hora (mín/ prom/ máx) de altura de marea y las enriquece
  con clima (temperatura, viento —con rumbo cardinal— y precipitación).
- Deja un JSON por estación listo para que el frontend lo consuma en tiempo real.
- Diseñado para correr en un job/cron y no depender de base de datos.

Fuentes de datos
- INA (API JSON): serie de alturas por estación en una ventana [hoy 00:00, +3 días].
- SMN (ZIP TXT “pron5d”): pronóstico de 5 días por localidades; se decodifica,
  se detectan bloques por estación y se parsean filas por fecha/hora.

Entradas y configuración
- marea/scripts/data/estaciones.json → define por estación: series_id, site_code, cal_id y pronostico_id.
- Entorno: detecta Railway para escribir en /app/marea/cache; en local usa marea/cache/.

Salida (por estación)
- Archivo: marea/cache/marea_<estacion>.json
- Estructura:
  {
    "datos": [
      {
        "fecha": "YYYY-MM-DD",
        "hora": "HH:MM:SS",
        "altura_minima": float,
        "altura_promedio": float,
        "altura_maxima": float,
        "temperatura": float | null,
        "viento_direccion": float | null,              # grados crudos
        "viento_direccion_abreviatura": "NE" | ...,
        "viento_direccion_nombre": "Nordeste" | ...,
        "viento_direccion_grados": 45.0 | ...,        # ángulo base del sector
        "viento_km_h": int | null,
        "precipitacion_mm": float | null
      },
      ...
    ]
  }

Flujo 
- Carga catálogo de estaciones desde JSON.
- Descarga y parsea el pronóstico del SMN UNA vez por ejecución:
   -- Abre el ZIP, prueba varias codificaciones (latin1/utf-8/cp1252/utf-16*),
   -- Detecta encabezados por estación (línea + “====”),
   -- Extrae filas (fecha, hora, temp, viento, precipitación),
   -- Mapea viento en 16 rumbos (N, NNE, NE, …) con abreviatura/nombre/ángulo.
   -- Guarda artefactos de depuración (ZIP y TXT decodificado).
- Por cada estación:
   -- Llama al endpoint del INA para la ventana temporal,
   -- Agrupa por (fecha, hora) y calcula mín/prom/máx,
   -- Inserta una fila “23:59” cuando hay “00:00” (transición de día),
   -- Fusiona por (fecha, hora) con el pronóstico si corresponde,
   -- Persiste el JSON de caché.

Robustez y trazabilidad
- Manejo explícito de errores HTTP/JSON y logs legibles (con emojis).
- Decodificación tolerante del TXT del SMN (múltiples encodings).
- Zona horaria fija: America/Argentina/Buenos_Aires.
- Falla suave si una estación no tiene pronóstico (campos nulos en clima).

Rendimiento
- Una sola descarga/parseo del pronóstico por corrida; merges por estación.
- Operaciones vectorizadas con pandas (groupby/merge) para volumen diario.

Ejecución (CLI)
- Todas las estaciones:  python actualizacion.py --todas
- Estación puntual:      python actualizacion.py <estacion_id>

"""


import re
import io
import zipfile
import django
import requests
import pandas as pd
import os
import json
import sys
from datetime import datetime, timedelta
from pathlib import Path
import pytz

# ============================================================
# Configurar entorno Django
# ============================================================
# Definir BASE_DIR del proyecto y registrar en sys.path
BASE_DIR = Path(__file__).resolve().parents[3]
sys.path.append(str(BASE_DIR))

# Establecer módulo de settings y preparar Django
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "chipap.settings")
django.setup()

# ============================================================
# Catálogo de direcciones de viento
# ============================================================
# Definir rosa de vientos con abreviatura, nombre y ángulo base
DIRECCIONES_VIENTO = [
    ("N", "Norte", 0.0), ("NNE", "Nornoreste", 22.5), ("NE", "Nordeste", 45.0),
    ("ENE", "E-Noreste", 67.5), ("E", "Este", 90.0), ("ESE", "E-Sureste", 112.5),
    ("SE", "Sudeste", 135.0), ("SSE", "S-Sudeste", 157.5), ("S", "Sur", 180.0),
    ("SSO", "S-Suroeste", 202.5), ("SO", "Suroeste", 225.0),
    ("OSO", "O-Suroeste", 247.5), ("O", "Oeste", 270.0),
    ("ONO", "O-Noroeste", 292.5), ("NO", "Noroeste", 315.0),
    ("NNO", "N-Noroeste", 337.5),
]


def convertir_direccion(grados: float):
    """Calcular sector de viento más cercano y devolver (abrev, nombre, ang_base)."""
    for abrev, nombre, ang in DIRECCIONES_VIENTO:
        rango_min = (ang - 11.25) % 360
        rango_max = (ang + 11.25) % 360
        if rango_min < rango_max:
            if rango_min <= grados < rango_max:
                return abrev, nombre, ang
        else:
            if grados >= rango_min or grados < rango_max:
                return abrev, nombre, ang
    return "N", "Norte", 0.0


# ============================================================
# Cargar estaciones desde JSON de configuración
# ============================================================
ESTACIONES = {}
try:
    estaciones_path = BASE_DIR / "marea" / "scripts" / "data" / "estaciones.json"
    with open(estaciones_path, "r", encoding="utf-8") as f:
        estaciones_data = json.load(f)
        for est in estaciones_data:
            ESTACIONES[est["id"]] = {
                "series_id": est["series_id"],
                "site_code": est["site_code"],
                "cal_id": est["cal_id"],
                "pronostico_id": est.get("pronostico_id"),
            }
except Exception as e:
    print(f"❌ Error cargando estaciones.json: {e}")

# ============================================================
# Utilidad: extraer bloque de una estación dentro del TXT del SMN
# ============================================================


def extraer_bloque_estacion(contenido: str, estacion: str):
    """Extraer bloque de texto correspondiente a la estación indicada."""
    patron = re.compile(rf"{estacion}\n=+\n(.*?)(?=\n[A-Z0-9_]+\n=+|\Z)", re.S)
    match = patron.search(contenido)
    return match.group(1) if match else None

# ============================================================
# Descargar y parsear pronóstico del SMN
# ============================================================


def descargar_y_parsear_pronostico() -> pd.DataFrame:
    """Descargar ZIP del SMN, parsear TXT y devolver DataFrame normalizado (con trazas)."""
    url = "https://ssl.smn.gob.ar/dpd/zipopendata.php?dato=pron5d"
    headers = {"User-Agent": "Mozilla/5.0"}
    response = requests.get(url, headers=headers)
    if response.status_code != 200:
        print(f"❌ Error al descargar pronóstico: {response.status_code}")
        return pd.DataFrame()

    # Leer archivo TXT interno
    zip_bytes = io.BytesIO(response.content)

    with zipfile.ZipFile(zip_bytes, "r") as zip_ref:
        candidatos = [n for n in zip_ref.namelist()
                      if n.lower().endswith(".txt")]
        if not candidatos:
            print("❌ ZIP sin TXT interno")
            return pd.DataFrame()
        txt_name = candidatos[0]
        print(f"📄 TXT dentro del ZIP: {txt_name}")

        raw = zip_ref.read(txt_name)
        print(f"🗜️ Tamaño TXT (bytes): {len(raw)}")

        # Guardar artefactos de depuración
        debug_dir = (BASE_DIR / "marea" / "cache")
        debug_dir.mkdir(parents=True, exist_ok=True)
        with open(debug_dir / "debug_pron.zip", "wb") as f:
            f.write(zip_bytes.getvalue())
        with open(debug_dir / "debug_pron_raw.bin", "wb") as f:
            f.write(raw)

        # Intentar múltiples codificaciones y quedarnos con la primera que tenga líneas
        contenido = None
        for enc in ["latin1", "utf-8", "cp1252", "utf-16", "utf-16le", "utf-16be"]:
            try:
                tmp = raw.decode(enc, errors="ignore")
                nlineas = len(tmp.splitlines())
                print(f"🔤 Decodificado como {enc}: {nlineas} líneas")
                if nlineas > 0:
                    contenido = tmp
                    # Dump para inspección rápida
                    with open(debug_dir / f"debug_pron_{enc}.txt", "w", encoding="utf-8") as f:
                        f.write(contenido)
                    break
            except Exception as e:
                print(f"⚠️ Error decodificando {enc}: {e}")

        if not contenido:
            print(
                "❌ No se pudo decodificar el contenido del TXT (0 líneas en todos los intentos)")
            return pd.DataFrame()

    lineas = contenido.splitlines()
    print(f"🧾 Líneas totales en TXT: {len(lineas)}")

    # Normalizar para comparar títulos de estación de forma robusta
    def _norm(s: str) -> str:
        return re.sub(r'[^A-Z0-9]+', '_', s.upper()).strip('_')

    # Detectar encabezados (línea cuyo siguiente renglón es ======)
    headers_detectados = []
    for i, linea in enumerate(lineas[:-1]):
        if re.fullmatch(r"\s*=+\s*", lineas[i + 1] or ""):
            headers_detectados.append((_norm(linea), linea, i))
    print(f"🔎 Encabezados detectados: {len(headers_detectados)}")
    for h in headers_detectados[:10]:
        print(f"   • raw='{h[1]}' | norm='{h[0]}' | idx={h[2]}")

    datos = []

    # Definir patrón de filas de datos
    pattern_datos = re.compile(
        r"(\d{2}/[A-Z]{3}/\d{4})\s+(\d{2})Hs\.\s+([-]?\d+(?:\.\d+)?)"
        r"\s+([A-Z]{1,3}|\d+)\s*\|\s*(\d+)\s+([\d\.]+)"
    )

    # Cargar estaciones de pronóstico (una sola vez)
    with open(BASE_DIR / "marea" / "scripts" / "data" / "estaciones.json", encoding="utf-8") as f:
        estaciones_pronostico = [cfg["pronostico_id"] for cfg in json.load(f)]

    # Set normalizado para corte de bloque
    estaciones_norm_set = {_norm(e) for e in estaciones_pronostico}

    for estacion in estaciones_pronostico:
        est_norm = _norm(estacion)
        print(f"🔎 Buscando estación: {estacion} (norm='{est_norm}')...")
        encontrada = False

        # Ubicar índice del encabezado exacto por forma normalizada
        idx_header = None
        for norm_name, raw_name, idx in headers_detectados:
            if norm_name == est_norm:
                idx_header = idx
                print(f"✅ Encontrada '{raw_name}' en línea {idx}")
                encontrada = True
                break

        if not encontrada:
            print(f"⚠️ No se encontró {estacion} en el archivo")
            continue

        # Construir bloque desde la línea posterior a ====== hasta el próximo encabezado
        inicio_bloque = idx_header + 2  # saltar título y la línea de ======
        bloque_lineas = []
        for l_idx in range(inicio_bloque, len(lineas)):
            l = lineas[l_idx]
            # si aparece otro encabezado, cortar
            if l_idx + 1 < len(lineas) and re.fullmatch(r"\s*=+\s*", lineas[l_idx + 1] or ""):
                # confirmar que es un encabezado de estación conocida (opcional)
                if _norm(l) in estaciones_norm_set and _norm(l) != est_norm:
                    break
            # omitir encabezados internos y vacíos
            if any(k in l for k in ["FECHA", "TEMPERATURA", "VIENTO", "PRECIPITACION"]) or not l.strip():
                continue
            bloque_lineas.append(l)

        print(f"📦 Bloque '{estacion}': {len(bloque_lineas)} líneas crudas")

        filas = pattern_datos.findall("\n".join(bloque_lineas))
        print(f"📄 {estacion}: {len(filas)} filas extraídas")

        for fecha, hora, temp, viento_dir, viento_vel, prec in filas:
            try:
                fecha_dt = datetime.strptime(fecha, "%d/%b/%Y").date()
            except ValueError:
                continue

            try:
                grados = float(viento_dir)
            except ValueError:
                grados = 0.0

            abrev, nombre, grados_base = convertir_direccion(grados)

            datos.append({
                "estacion_pronostico": estacion,
                "fecha": fecha_dt.isoformat(),
                "hora": f"{hora}:00:00",
                "temperatura": float(temp),
                "viento_direccion": grados,
                "viento_direccion_abreviatura": abrev,
                "viento_direccion_nombre": nombre,
                "viento_direccion_grados": grados_base,
                "viento_km_h": int(viento_vel),
                "precipitacion_mm": float(prec),
            })

    df_pronostico = pd.DataFrame(datos)
    print(f"✅ Pronóstico procesado: {len(df_pronostico)} registros.")
    if not df_pronostico.empty:
        print(df_pronostico.head(5))
    return df_pronostico


# ============================================================
# Actualizar datos de marea y persistir cache JSON por estación
# ============================================================


def actualizar_datos_marea(estacion_id: str, series_id: int, site_code: str, cal_id: int):
    """Consultar INA, agregar métricas y fusionar con pronóstico si existe."""
    argentina = pytz.timezone("America/Argentina/Buenos_Aires")
    ahora = datetime.now(argentina)

    try:
        # Definir ventana [00:00 hoy, 23:59 + 3 días]
        inicio = ahora.replace(hour=0, minute=0, second=0,
                               microsecond=0, tzinfo=None)
        fin = inicio + timedelta(days=3, seconds=86399)

        # Construir URL al endpoint del INA (mantener forma actual)
        url = (
            f"https://alerta.ina.gob.ar/pub/datos/datosProno"
            f"&timeStart={inicio.strftime('%Y-%m-%d')}"
            f"&timeEnd={fin.strftime('%Y-%m-%d')}"
            f"&seriesId={series_id}&calId={cal_id}&all=false&siteCode={site_code}&varId=2&format=json"
        )

        headers = {"User-Agent": "Mozilla/5.0"}
        response = requests.get(url, headers=headers)
        if response.status_code != 200:
            print(f"❌ Error HTTP para {estacion_id}: {response.status_code}")
            return

        # Parsear JSON del INA
        try:
            data = response.json().get("data", [])
        except json.JSONDecodeError as e:
            print(f"❌ Error al parsear JSON para {estacion_id}: {e}")
            return

        if not data:
            print(f"⚠️ No hay datos nuevos para {estacion_id}.")
            return

        # Normalizar a DataFrame y derivar fecha/hora
        df = pd.DataFrame(data)
        df["timestart_dt"] = pd.to_datetime(df["timestart"])
        df["fecha"] = df["timestart_dt"].dt.date.astype(str)
        df["hora"] = df["timestart_dt"].dt.time.astype(str)

        # Filtrar ventana temporal útil
        df = df[df["timestart_dt"] >= inicio]
        df = df[df["timestart_dt"] < inicio + timedelta(days=4)]
        if df.empty:
            print(f"⚠️ Datos vacíos para {estacion_id} después de filtrar.")
            return

        # Agregar métricas por (fecha, hora)
        df_ag = (
            df.groupby(["fecha", "hora"])
            .agg(
                altura_minima=("valor", "min"),
                altura_maxima=("valor", "max"),
                altura_promedio=("valor", "mean"),
            )
            .reset_index()
        )

        # Agregar fila 23:59 cuando hay valor en 00:00
        df_ag["datetime"] = pd.to_datetime(
            df_ag["fecha"] + " " + df_ag["hora"])
        nuevas_filas = []
        for _, row in df_ag.iterrows():
            if row["hora"] == "00:00:00" and row["datetime"] > inicio:
                nueva_fila = row.copy()
                nueva_fila["datetime"] = row["datetime"] - timedelta(minutes=1)
                nueva_fila["fecha"] = nueva_fila["datetime"].date().isoformat()
                nueva_fila["hora"] = nueva_fila["datetime"].time().isoformat()
                nuevas_filas.append(nueva_fila)

        df_ag = pd.concat(
            [df_ag, pd.DataFrame(nuevas_filas)], ignore_index=True)
        df_ag = df_ag.drop(columns=["datetime"]).sort_values(
            by=["fecha", "hora"])

        # Fusionar con pronóstico si corresponde
        pronostico_id = ESTACIONES[estacion_id].get("pronostico_id")
        if pronostico_id and not df_pronostico_global.empty:
            df_pron = df_pronostico_global[df_pronostico_global["estacion_pronostico"] == pronostico_id]
            if not df_pron.empty:
                df_ag = df_ag.merge(
                    df_pron[
                        [
                            "fecha",
                            "hora",
                            "temperatura",
                            "viento_direccion",
                            "viento_direccion_abreviatura",
                            "viento_direccion_nombre",
                            "viento_direccion_grados",
                            "viento_km_h",
                            "precipitacion_mm",
                        ]
                    ],
                    on=["fecha", "hora"],
                    how="left",
                )
            else:
                for col in [
                    "temperatura",
                    "viento_direccion",
                    "viento_direccion_abreviatura",
                    "viento_direccion_nombre",
                    "viento_direccion_grados",
                    "viento_km_h",
                    "precipitacion_mm",
                ]:
                    df_ag[col] = None
        else:
            for col in [
                "temperatura",
                "viento_direccion",
                "viento_direccion_abreviatura",
                "viento_direccion_nombre",
                "viento_direccion_grados",
                "viento_km_h",
                "precipitacion_mm",
            ]:
                df_ag[col] = None

        print(
            f"🔗 Merge completado para {estacion_id}, filas finales: {len(df_ag)}")

        # Definir directorio de cache según entorno (Railway vs local)
        cache_dir = Path("/app/marea/cache") if os.environ.get(
            "RAILWAY_ENVIRONMENT") else BASE_DIR / "marea" / "cache"
        cache_dir.mkdir(parents=True, exist_ok=True)

        # Persistir JSON por estación
        salida = {"datos": df_ag.to_dict(orient="records")}
        with open(cache_dir / f"marea_{estacion_id}.json", "w", encoding="utf-8") as f:
            json.dump(salida, f, indent=2)

        print(f"✅ Datos guardados para {estacion_id}")

    except Exception as e:
        # Registrar cualquier error inesperado y continuar con el resto
        print(f"❌ Error inesperado en {estacion_id}: {e}")


# ============================================================
# Punto de entrada del script
# ============================================================
# Descargar pronóstico global una única vez
df_pronostico_global = descargar_y_parsear_pronostico()

print("📊 Pronóstico global (primeras filas):")
print(df_pronostico_global.head(10))

if __name__ == "__main__":
    # Ejecutar para una estación específica: python actualizacion.py <estacion>
    # Ejecutar para todas: python actualizacion.py  (o con --todas)
    if len(sys.argv) > 1 and sys.argv[1] != "--todas":
        est = sys.argv[1]
        config = ESTACIONES.get(est)
        if not config:
            print(f"❌ Estación '{est}' no definida.")
        else:
            actualizar_datos_marea(
                est, config["series_id"], config["site_code"], config["cal_id"])
    else:
        for est, config in ESTACIONES.items():
            actualizar_datos_marea(
                est, config["series_id"], config["site_code"], config["cal_id"])
