import 'api_service.dart';
import 'csv_download.dart';

class ReportGenerationException implements Exception {
  final String message;
  ReportGenerationException(this.message);
}

class GeneratedReportInfo {
  final String fileName;
  final String format;
  final DateTime generatedAt;
  final int recordCount;

  GeneratedReportInfo({
    required this.fileName,
    required this.format,
    required this.generatedAt,
    required this.recordCount,
  });
}

/// Report generation logic — kept separate from UI. Reuses the existing
/// ApiService rather than duplicating network code.
class ReportService {
  static String _escapeCsv(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  /// Builds a real CSV from actual FloatData records for the given float
  /// filter ('all' or a specific float ID). No fabricated rows.
  static Future<GeneratedReportInfo> generateCsv({required String floatFilter}) async {
    final idsResult = await ApiService.getFloatIds();
    if (idsResult['statusCode'] != 200) {
      throw ReportGenerationException('Unable to load dataset for report generation.');
    }

    final allIds = List<String>.from(idsResult['body']['float_ids']);
    final targetIds = floatFilter == 'all' ? allIds : [floatFilter];

    final rows = <List<String>>[];
    for (final id in targetIds) {
      final historyResult = await ApiService.getFloatHistory(id);
      if (historyResult['statusCode'] != 200) continue;
      final history = historyResult['body']['history'] as List<dynamic>;
      for (final h in history) {
        rows.add([
          id,
          '${h['latitude'] ?? ''}',
          '${h['longitude'] ?? ''}',
          '${h['temperature'] ?? ''}',
          '${h['salinity'] ?? ''}',
          '${h['pressure'] ?? ''}',
          'N/A', // timestamp not populated by backend yet — honest, not fabricated
          '${h['cycle_number'] ?? ''}',
        ]);
      }
    }

    if (rows.isEmpty) {
      throw ReportGenerationException('No records available for the selected filter.');
    }

    final buffer = StringBuffer();
    buffer.writeln('Float ID,Latitude,Longitude,Temperature,Salinity,Pressure,Timestamp,Cycle Number');
    for (final row in rows) {
      buffer.writeln(row.map(_escapeCsv).join(','));
    }

    final fileName =
        'OceanPredict_Report_${DateTime.now().millisecondsSinceEpoch}.csv';

    if (canDownloadInBrowser) {
      downloadCsv(fileName, buffer.toString());
    } else {
      throw ReportGenerationException(
        'CSV was generated (${rows.length} records) but file download is only supported on the web build right now.',
      );
    }

    return GeneratedReportInfo(
      fileName: fileName,
      format: 'CSV',
      generatedAt: DateTime.now(),
      recordCount: rows.length,
    );
  }

  static Future<GeneratedReportInfo> generatePdf({required String floatFilter}) async {
    throw ReportGenerationException('PDF generation service is not available yet.');
  }

  static Future<GeneratedReportInfo> generateExcel({required String floatFilter}) async {
    throw ReportGenerationException('Excel generation service is not available yet.');
  }
}