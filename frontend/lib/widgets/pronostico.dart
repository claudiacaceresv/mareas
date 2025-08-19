// frontend/mareas/lib/widgets/pronostico.dart
// UI minimal y 100% responsive
// - Selector de franja
// - Detalle por franja en 4 filas compactas
// - "Todo el día" en chips cortos con Wrap

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:app_mareas/theme/tema_visual.dart';

class PronosticoDashboard extends StatefulWidget {
  final List<dynamic> datos; // maps: fecha, hora, altura_promedio, temperatura, viento_km_h, viento_direccion_abreviatura, viento_direccion_grados, precipitacion_mm
  final DateTime fecha;
  final bool esMini;

    const PronosticoDashboard({
    super.key,
    required this.datos,
    required this.fecha,
    this.esMini = false, // <—
  });

  @override
  State<PronosticoDashboard> createState() => _PronosticoDashboardState();
}

class _PronosticoDashboardState extends State<PronosticoDashboard> {
  late final PageController _page;
  late int _sel;
  static const _labels = ['00–06h', '06–12h', '12–18h', '18–24h'];

  @override
  void initState() {
    super.initState();
    _sel = _bloqueDeHora(DateTime.now().hour);
    _page = PageController(initialPage: _sel);
  }

  @override
  void dispose() { _page.dispose(); super.dispose(); }

  // ---------------- Datos
  bool _isFinite(num? v) {
  if (v == null) return false;
  if (v is int) return true;      // enteros válidos (10, 12, 25)
  if (v is double) return v.isFinite;
  return false;
}

  int _bloqueDeHora(int h) { if (h < 6) return 0; if (h < 12) return 1; if (h < 18) return 2; return 3; }

  num? _toNum(dynamic x) {
    if (x == null) return null;
    if (x is num) return x;
    if (x is String) return double.tryParse(x.replaceAll(',', '.'));
    return null;
  }


  List<Map<String, dynamic>> _filtrarFecha(List datos) {
    final f = DateFormat('yyyy-MM-dd').format(widget.fecha);
    return datos
        .where((e) => e is Map && (e['fecha']?.toString() ?? '').startsWith(f))
        .map<Map<String, dynamic>>((e) {
          final m = Map<String, dynamic>.from(e as Map);
          // alias SMN
          m['temperatura'] ??= m['temp'];
          m['viento_km_h'] ??= (m['viento_vel_km_h'] ?? m['viento_kmh']);
          m['viento_direccion_grados'] ??= m['viento_direccion'];
          m['precipitacion_mm'] ??= m['precipitacion'];
          // abreviatura: si falta o viene vacía, usar nombre
          final abv = m['viento_direccion_abreviatura']?.toString().trim();
          if (abv == null || abv.isEmpty) {
            m['viento_direccion_abreviatura'] =
                m['viento_direccion_nombre']?.toString().trim();
          }
          return m;
        })
        .toList();
  }


  List<Map<String, dynamic>> _filtrarBloque(List<Map<String, dynamic>> datos, int b) {
    final ini = [0, 6, 12, 18][b], fin = [6, 12, 18, 24][b];
    return datos.where((e) {
      final h = int.tryParse((e['hora'] ?? '00:00').toString().split(':').first) ?? 0;
      return h >= ini && h < fin;
    }).toList();
  }

  double _mediaCircular(Iterable<num> grados) {
    final g = grados.where(_isFinite).map((v) => v.toDouble()).toList(); if (g.isEmpty) return 0;
    double sx = 0, sy = 0; for (final d in g) { final r = d * math.pi / 180; sx += math.cos(r); sy += math.sin(r); }
    final a = math.atan2(sy, sx) * 180 / math.pi; return (a + 360) % 360;
  }

  List<String> _dirsOrden(Iterable<dynamic> it) {
    final out = <String>[]; for (final v in it) { final s = v?.toString().trim(); if (s == null || s.isEmpty || s == 'NaN') continue; if (!out.contains(s)) out.add(s); } return out;
  }

  _Resumen _resumen(List<Map<String, dynamic>> datos) {
    double? altMin, altMax, tMin, tMax, vMin, vMax;
    double lluvia = 0;
    final grados = <num>[];
    final ab = <dynamic>[];

    for (final e in datos) {
      // Altura
      final ap = _toNum(e['altura_promedio']);
      if (_isFinite(ap)) {
        final v = ap!.toDouble();
        altMin = (altMin == null) ? v : math.min(altMin, v);
        altMax = (altMax == null) ? v : math.max(altMax, v);
      }

      // Temperatura (acepta int/double/string)
      final tRaw = _toNum(e['temperatura'] ?? e['temp']);

      if (_isFinite(tRaw)) {
        final t = tRaw!.toDouble();
        tMin = (tMin == null) ? t : math.min(tMin, t);
        tMax = (tMax == null) ? t : math.max(tMax, t);
      }

      // Viento velocidad
      final vk = _toNum(e['viento_km_h'] ?? e['viento_vel_km_h'] ?? e['viento_kmh']);

      if (_isFinite(vk)) {
        final v = vk!.toDouble();
        vMin = (vMin == null) ? v : math.min(vMin, v);
        vMax = (vMax == null) ? v : math.max(vMax, v);
      }

      // Viento dirección (en grados)
      final g = _toNum(e['viento_direccion_grados'] ?? e['viento_direccion']);
      if (_isFinite(g)) grados.add(g!.toDouble());


      // Abreviaturas de dirección
      final abv = (e['viento_direccion_abreviatura'] ?? e['viento_direccion_nombre'] ?? '').toString();
      if (abv.isNotEmpty) ab.add(abv);


      // Lluvia
      final mm = _toNum(e['precipitacion_mm'] ?? e['precipitacion']);

      if (_isFinite(mm)) lluvia += mm!;
    }

    return _Resumen(
      altMin: altMin,
      altMax: altMax,
      tempMin: tMin,
      tempMax: tMax,
      vientoMin: vMin,
      vientoMax: vMax,
      lluviaMm: lluvia,
      vientoDirPromGrados: _mediaCircular(grados),
      vientoDirAbrevs: _dirsOrden(ab),
    );
  }

  String _rango(num? a, num? b, {int dec = 1, String suf = ''}) {
    String f(num x) => x.toStringAsFixed(dec);
    if (a == null && b == null) return '-';
    if (a != null && b != null) return (a == b) ? '${f(a)}$suf' : '${f(a)}–${f(b)}$suf';
    return '${f(a ?? b!)}$suf';
}


  @override
  Widget build(BuildContext context) {
    final tema = obtenerTemaVisual(context);
    final mq = MediaQuery.of(context);
    final w = mq.size.width, h = mq.size.height;
    final escalaW = (w / 360).clamp(0.8, 1.15);
    final escalaH = (h / 720).clamp(0.85, 1.10);
    final escala = (escalaW * escalaH).clamp(0.8, 1.1);
    double fs(double b, {double min = 9, double max = 24}) => (b * escala).clamp(min, max).toDouble();

    final datosDia = _filtrarFecha(widget.datos); // fuente cruda

    int _scoreSmn(Map<String, dynamic> m) {
      int s = 0;
      if (_isFinite(_toNum(m['temperatura'] ?? m['temp']))) s++;
      if (_isFinite(_toNum(m['viento_km_h'] ?? m['viento_vel_km_h'] ?? m['viento_kmh']))) s++;
      if (_isFinite(_toNum(m['viento_direccion_grados'] ?? m['viento_direccion']))) s++;
      if (_isFinite(_toNum(m['precipitacion_mm'] ?? m['precipitacion']))) s++;
      final abv = (m['viento_direccion_abreviatura'] ?? m['viento_direccion_nombre'] ?? '').toString().trim();
      if (abv.isNotEmpty) s++;
      return s;
    }

    final byKey = <String, Map<String, dynamic>>{};
    for (final m in datosDia) {
      final key = '${m['fecha']}T${m['hora']}';
      final prev = byKey[key];
      if (prev == null || _scoreSmn(m) > _scoreSmn(prev)) {
        byKey[key] = m;
      }
    }
    final datosDiaDepurado = byKey.values.toList()
      ..sort((a,b) => ('${a['fecha']} ${a['hora']}').compareTo('${b['fecha']} ${b['hora']}'));

    debugPrint('SMN con datos: '
      '${datosDiaDepurado.where((m) => _isFinite(_toNum(m['temperatura'])) || _isFinite(_toNum(m['viento_km_h'])) || _isFinite(_toNum(m['precipitacion_mm']))).length}');


    final bloques = List.generate(4, (i) => _resumen(_filtrarBloque(datosDiaDepurado, i)));

    final rBloque = bloques[_sel];
    final rDia = _resumen(datosDiaDepurado);


    final content = LayoutBuilder(builder: (context, c) {
      final mq = MediaQuery.of(context);
      final bottomSpace = (mq.size.height * 0.02).clamp(8.0, 20.0);
      return Container(
        constraints: BoxConstraints(minHeight: c.maxHeight),
        decoration: BoxDecoration(
          color: tema.fondo,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: tema.borde),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        padding: EdgeInsets.fromLTRB(12 * escala, 12 * escala, 12 * escala,
        (mq.size.height * 0.04).clamp(12.0, 30.0)),


        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            // Parte superior que se expande
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!widget.esMini)
                    Center(
                      child: Text(
                        DateFormat('dd/MM/yyyy').format(widget.fecha),
                        style: TextStyle(
                          fontFamily: 'PressStart',
                          fontSize: 12 * escala,
                          fontWeight: FontWeight.w400,
                          color: tema.texto,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  if (!widget.esMini) SizedBox(height: 8 * escala),

                  // Chips franja
                    Row(
                      children: List.generate(4, (i) {
                        final sel = i == _sel;
                        return Expanded(
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () => setState(() => _sel = i),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                margin: EdgeInsets.symmetric(horizontal: 4 * escala),
                                padding: EdgeInsets.symmetric(vertical: 10 * escala),
                                decoration: BoxDecoration(
                                  color: sel ? tema.borde : tema.relleno.withOpacity(0.20),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: tema.linea.withOpacity(sel ? 0 : 0.12)),

                                ),
                                child: Text(
                                  _labels[i],
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: fs(14, min: 12, max: 16),
                                    fontWeight: FontWeight.w600,
                                    color: sel ? tema.texto : tema.texto,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),

                  SizedBox(height: 12 * escala),

                  // Detalle franja
                  _SeccionFilas(
                    tema: tema,
                    escala: escala,
                    filas: [
                      _FilaDato.temp(
                        label: 'Temperatura',
                        valor: _rango(rBloque.tempMin, rBloque.tempMax, dec: 0),
                        unidad: '°C',
                        fsValor: fs(18, min: 16, max: 20),
                        fsUnidad: fs(11, min: 10, max: 12),
                        vPad: 8 * escala,
                      ),
                      _FilaDato.viento(
                        label: 'Viento',
                        rangoVel: _rango(rBloque.vientoMin, rBloque.vientoMax, dec: 0),
                        unidad: 'km/h',
                        grados: rBloque.vientoDirPromGrados ?? 0,
                        dirs: rBloque.vientoDirAbrevs,
                        fsValor: fs(18, min: 16, max: 20),
                        fsUnidad: fs(11, min: 10, max: 12),
                        vPad: 8 * escala,
                      ),
                      _FilaDato.lluvia(
                        label: 'Lluvia',
                        valor: (rBloque.lluviaMm ?? 0).toStringAsFixed(1),
                        unidad: 'mm',
                        estado: _estadoLluvia(rBloque.lluviaMm, horas: 6),

                        fsValor: fs(18, min: 16, max: 20),
                        fsUnidad: fs(11, min: 10, max: 12),
                        vPad: 8 * escala,
                      ),
                      _FilaDato.altura(
                        label: 'Marea',
                        valor: _rango(rBloque.altMin, rBloque.altMax, dec: 2),
                        unidad: 'm',
                        fsValor: fs(18, min: 16, max: 20),
                        fsUnidad: fs(11, min: 10, max: 12),
                        vPad: 8 * escala,
                      ),
                    ],
                    fsLabel: fs(14, min: 12, max: 16),
                  ),
                ],
              ),
            ),

            // Bloque fijo abajo: Todo el día
            Divider(color: tema.borde.withOpacity(0.3)),
            SizedBox(height: 6 * escala),
            Center(
              child: Text(
                'Todo el día',
                style: TextStyle(fontSize: fs(14, min: 12, max: 16), fontWeight: FontWeight.w600, color: tema.texto),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(height: 6 * escala),
            _ResumenDiaCompacto(
              tema: tema,
              escala: escala,
              chips: [
                'Temp ${_rango(rDia.tempMin, rDia.tempMax, dec: 0)} °C',
                'Viento ${_rango(rDia.vientoMin, rDia.vientoMax, dec: 0)} km/h',
                'Lluvia ${(rDia.lluviaMm ?? 0).toStringAsFixed(1)} mm',
                'Marea ${_rango(rDia.altMin, rDia.altMax, dec: 2)} m',
              ],
              fsChip: fs(12, min: 10, max: 14),
              padV: 5 * escala,
              runSpace: 4 * escala,
            ),
          ],
        ),
      );
    });


    // Capo textScale para evitar overflow por accesibilidad del sistema.
    final capped = MediaQuery(data: mq.copyWith(textScaleFactor: mq.textScaleFactor.clamp(0.85, 1.0)), child: content);
    return capped;
  }

    String _estadoLluvia(double? mm, {int horas = 6}) {
      final total = (mm ?? 0).clamp(0, double.infinity);
      if (total == 0) return 'seco';
      final rate = total / (horas <= 0 ? 1 : horas); // mm/h (aprox)

      if (rate < 2.5) return 'leve';
      if (rate <= 7.6) return 'moderado';
      return 'abundante'; 
    }

  }

// ---------------- Modelo
class _Resumen {
  final double? altMin, altMax, tempMin, tempMax, vientoMin, vientoMax, lluviaMm, vientoDirPromGrados; final List<String> vientoDirAbrevs;
  const _Resumen({this.altMin, this.altMax, this.tempMin, this.tempMax, this.vientoMin, this.vientoMax, this.lluviaMm, this.vientoDirPromGrados, this.vientoDirAbrevs = const []});
}

// ---------------- Secciones y filas
class _SeccionFilas extends StatelessWidget {
  final TemaVisual tema; final double escala; final List<_FilaDato> filas; final double fsLabel;
  const _SeccionFilas({required this.tema, required this.escala, required this.filas, required this.fsLabel});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(filas.length * 2 - 1, (i) {
        if (i.isOdd) return Divider(height: 1, color: tema.borde);
        final idx = i ~/ 2; return filas[idx].build(context, tema, escala, fsLabel);
      }),
    );
  }
}

class _FilaDato {
  final IconData icon; final String label; final Widget right; final double vPad;
  final double? fsLabelOverride;
  const _FilaDato._(this.icon, this.label, this.right, this.vPad, {this.fsLabelOverride});

  static _FilaDato altura({required String label, required String valor, required String unidad, required double fsValor, required double fsUnidad, required double vPad}) {
    return _FilaDato._(Icons.straighten, label, _RightValor(rango: valor, unidad: unidad, fsValor: fsValor, fsUnidad: fsUnidad), vPad);
  }
  static _FilaDato temp({required String label, required String valor, required String unidad, required double fsValor, required double fsUnidad, required double vPad}) {
    return _FilaDato._(Icons.thermostat, label, _RightValor(rango: valor, unidad: unidad, fsValor: fsValor, fsUnidad: fsUnidad), vPad);
  }
  static _FilaDato viento({required String label, required String rangoVel, required String unidad, required double grados, required List<String> dirs, required double fsValor, required double fsUnidad, required double vPad}) {
    return _FilaDato._(Icons.navigation, label, _RightViento(rango: rangoVel, unidad: unidad, grados: grados, dirs: dirs, fsValor: fsValor, fsUnidad: fsUnidad), vPad);
  }
  static _FilaDato lluvia({required String label, required String valor, required String unidad, required String estado, required double fsValor, required double fsUnidad, required double vPad}) {
    return _FilaDato._(Icons.opacity, label, _RightLluvia(valor: valor, unidad: unidad, estado: estado, fsValor: fsValor, fsUnidad: fsUnidad), vPad);
  }

  Widget build(BuildContext context, TemaVisual tema, double escala, double fsLabel) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: vPad),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Transform.rotate(angle: icon == Icons.navigation ? 0 : 0, child: Icon(icon, size: 18 * escala, color: tema.texto.withOpacity(0.9))),
          SizedBox(width: 10 * escala),
          Expanded(child: Text(label, style: TextStyle(fontSize: fsLabel, color: tema.texto.withOpacity(0.85)), maxLines: 1, overflow: TextOverflow.ellipsis)),
          SizedBox(width: 10 * escala),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: right,
              ),
            ),
          ),


        ],
      ),
    );
  }
}

class _RightValor extends StatelessWidget {
  final String rango; final String unidad; final double fsValor; final double fsUnidad;
  const _RightValor({required this.rango, required this.unidad, required this.fsValor, required this.fsUnidad});
  @override
  Widget build(BuildContext context) {
    final tema = obtenerTemaVisual(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
      Text(rango, style: TextStyle(fontSize: fsValor, fontWeight: FontWeight.w600, color: tema.texto)),
      Text(unidad, style: TextStyle(fontSize: fsUnidad, color: tema.texto.withOpacity(0.7))),
    ]);
  }
}

class _RightViento extends StatelessWidget {
  final String rango; final String unidad; final double grados; final List<String> dirs; final double fsValor; final double fsUnidad;
  const _RightViento({required this.rango, required this.unidad, required this.grados, required this.dirs, required this.fsValor, required this.fsUnidad});
  @override
  Widget build(BuildContext context) {
    final tema = obtenerTemaVisual(context); final escala = MediaQuery.of(context).size.width / 360;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Transform.rotate(angle: grados * math.pi / 180, child: Icon(Icons.navigation, size: 19 * escala, color: tema.texto)),
      SizedBox(width: 8 * escala),
      Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
        Text(rango, style: TextStyle(fontSize: fsValor, fontWeight: FontWeight.w600, color: tema.texto)),
        Text('$unidad · ${dirs.isEmpty ? '—' : dirs.join('|')}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: fsUnidad, color: tema.texto.withOpacity(0.7))),
      ]),
    ]);
  }
}

class _RightLluvia extends StatelessWidget {
  final String valor; final String unidad; final String estado; final double fsValor; final double fsUnidad;
  const _RightLluvia({required this.valor, required this.unidad, required this.estado, required this.fsValor, required this.fsUnidad});
  @override
  Widget build(BuildContext context) {
    final tema = obtenerTemaVisual(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
      Text(valor, style: TextStyle(fontSize: fsValor, fontWeight: FontWeight.w600, color: tema.texto)),
      Text('$unidad · $estado', style: TextStyle(fontSize: fsUnidad, color: tema.texto.withOpacity(0.7))),
    ]);
  }
}

class _ResumenDiaCompacto extends StatelessWidget {
  final TemaVisual tema; final double escala; final List<String> chips; final double fsChip; final double padV; final double runSpace;
  const _ResumenDiaCompacto({required this.tema, required this.escala, required this.chips, required this.fsChip, required this.padV, required this.runSpace});
@override
Widget build(BuildContext context) {
  return LayoutBuilder(builder: (context, c) {
    final gap = 8 * escala;
    final esMuyAngosto = c.maxWidth < 300;
    final colW = esMuyAngosto ? c.maxWidth : (c.maxWidth - gap) / 2;
    return Wrap(
      alignment: WrapAlignment.center,
      runAlignment: WrapAlignment.center,
      spacing: gap,
      runSpacing: runSpace,
      children: chips.map((t) => SizedBox(
        width: colW,
        child: Container(
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(horizontal: 10 * escala, vertical: padV),
          decoration: BoxDecoration(
            color: tema.relleno.withOpacity(0.7),    
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: tema.borde),
          ),

          child: Text(t,
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(color: tema.texto, fontSize: fsChip),
            textAlign: TextAlign.center),
        ),
      )).toList(),
    );
  });
}

}
