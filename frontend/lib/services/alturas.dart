// ================================================================
// Cliente HTTP para obtener alturas de marea por estación desde el backend.
// Qué hace:
// - Construye la URL /marea/alturas/<estacion>/ usando `baseUrl` (inyectable).
// - Hace GET, parsea JSON y devuelve `List<dynamic>` en `data['datos']`.
// - Lanza Exception con detalle en errores HTTP, de red o parsing.
// Uso:
// - `AlturasService().obtenerAlturasPorEstacion('san_fernando')`.
// Testeo:
// - Inyectar `baseUrl` a un mock server para pruebas.
// Seguridad:
// - No guarda credenciales ni estado; solo lectura.
// ================================================================


import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/backend_config.dart'; 

class AlturasService {
  // Permitir inyectar baseUrl para pruebas o entornos.
  final String baseUrl;

  // Usar backendBaseUrl por defecto.
  AlturasService({this.baseUrl = backendBaseUrl});

  // Consultar alturas de una estación y devolver lista de registros.
  Future<List<dynamic>> obtenerAlturasPorEstacion(String estacionId) async {
    // Construir URL del recurso.
    final url = Uri.parse('$baseUrl/marea/alturas/$estacionId/');

    try {
      // Ejecutar GET al backend.
      final respuesta = await http.get(url);

      // Evaluar respuesta.
      if (respuesta.statusCode == 200) {
        // Parsear JSON y validar estructura esperada.
        final data = json.decode(respuesta.body);
        print('DEBUG: $data');

        if (data is Map && data['datos'] is List) {
          return data['datos']; // lista real de datos
        } else {
          return []; // estructura distinta o sin datos
        }
      } else {
        // Propagar detalle de error HTTP.
        throw Exception('Error ${respuesta.statusCode}: ${respuesta.body}');
      }
    } catch (e) {
      // Manejar errores de red o parsing.
      throw Exception('Error al conectar con el servidor: $e');
    }
  }
}
