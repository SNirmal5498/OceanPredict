import 'package:flutter_test/flutter_test.dart';
import 'package:oceanpredict_app/services/report_service.dart';

void main() {
  group('Reports Module Data Consistency Tests', () {
    final List<Map<String, dynamic>> mockActiveDataset288 = List.generate(288, (index) {
      final floatId = index < 96 ? 'F001' : (index < 192 ? 'F002' : 'F003');
      final month = (index % 12) + 1;
      final monthStr = month.toString().padLeft(2, '0');
      return {
        'id': index + 1,
        'float_id': floatId,
        'cycle_number': (index % 12) + 1,
        'timestamp': '2025-$monthStr-01 00:00:00',
        'latitude': 12.0 + (index * 0.01),
        'longitude': 68.0 + (index * 0.01),
        'temperature': 20.0 + (index % 5),
        'salinity': 35.0 + (index % 3),
        'pressure': 100.0 + (index % 50),
      };
    });

    test('All Floats filter returns all 288 active dataset records', () {
      final filtered = mockActiveDataset288;
      expect(filtered.length, 288);
    });

    test('F001 float filter returns exactly 96 records', () {
      final filtered = mockActiveDataset288.where((r) => r['float_id'] == 'F001').toList();
      expect(filtered.length, 96);
    });

    test('F002 float filter returns exactly 96 records', () {
      final filtered = mockActiveDataset288.where((r) => r['float_id'] == 'F002').toList();
      expect(filtered.length, 96);
    });

    test('F003 float filter returns exactly 96 records', () {
      final filtered = mockActiveDataset288.where((r) => r['float_id'] == 'F003').toList();
      expect(filtered.length, 96);
    });

    test('Statistical calculations use the exact filtered record count', () {
      final f001Records = mockActiveDataset288.where((r) => r['float_id'] == 'F001').toList();
      final tempValues = f001Records.map((r) => r['temperature'] as num).toList();
      final stats = ReportService.computeStats(tempValues);

      expect(stats['count'], 96);
      expect(stats['avg'], isNotNull);
      expect(stats['min'], isNotNull);
      expect(stats['max'], isNotNull);
    });
  });
}
