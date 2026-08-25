import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_service.dart';
import '../models/prediction_result.dart';

enum PredictionErrorType { insufficientData, serviceUnavailable, invalidInput, unknown }

class PredictionException implements Exception {
  final PredictionErrorType type;
  final String message;
  PredictionException(this.type, this.message);
}

/// Thin domain layer over ApiService — parses real backend responses into
/// typed models and classifies failures honestly. Never fabricates a result.
class PredictionService {
  static Future<PredictionResult> predict({
    required String model,
    required String target,
    required String floatId,
    required int horizon,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/api/predictions'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'model': model,
          'target': target,
          'float_id': floatId,
          'horizon': horizon,
        }),
      );

      if (response.statusCode == 200) {
        return PredictionResult.fromJson(jsonDecode(response.body));
      }

      if (response.statusCode == 404) {
        throw PredictionException(
          PredictionErrorType.serviceUnavailable,
          'Prediction service is not available yet.',
        );
      }

      final body = jsonDecode(response.body);
      final msg = body['message'] ?? 'Prediction request failed.';

      if (response.statusCode == 400 && '$msg'.toLowerCase().contains('insufficient')) {
        final available = body['available_records'];
        final required = body['required_minimum'];
        throw PredictionException(
          PredictionErrorType.insufficientData,
          available != null && required != null
              ? '$msg ($available of $required required records available)'
              : '$msg',
        );
      }

      throw PredictionException(PredictionErrorType.invalidInput, '$msg');
    } on PredictionException {
      rethrow;
    } catch (e) {
      throw PredictionException(
        PredictionErrorType.serviceUnavailable,
        'Unable to connect to prediction server.',
      );
    }
  }
}
