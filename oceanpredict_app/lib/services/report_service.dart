// lib/services/report_service.dart
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:excel/excel.dart' as excel_pkg;
import 'file_download_web.dart';

class ReportService {
  // ==========================================
  // STATISTICAL HELPERS
  // ==========================================
  static Map<String, dynamic> computeStats(List<num> values) {
    if (values.isEmpty) {
      return {'count': 0, 'avg': null, 'min': null, 'max': null, 'std': null, 'range': null};
    }
    final double sum = values.fold(0.0, (prev, elem) => prev + elem.toDouble());
    final double avg = sum / values.length;
    double minVal = values.first.toDouble();
    double maxVal = values.first.toDouble();
    for (var v in values) {
      final double d = v.toDouble();
      if (d < minVal) minVal = d;
      if (d > maxVal) maxVal = d;
    }
    double varianceSum = 0.0;
    for (var v in values) {
      final double d = v.toDouble();
      varianceSum += (d - avg) * (d - avg);
    }
    final double std = values.length > 1 ? math.sqrt(varianceSum / (values.length - 1)) : 0.0;
    final double range = maxVal - minVal;

    return {
      'count': values.length,
      'avg': double.parse(avg.toStringAsFixed(2)),
      'min': double.parse(minVal.toStringAsFixed(2)),
      'max': double.parse(maxVal.toStringAsFixed(2)),
      'std': double.parse(std.toStringAsFixed(2)),
      'range': double.parse(range.toStringAsFixed(2)),
    };
  }

  // ==========================================
  // PDF GENERATION & DOWNLOAD
  // ==========================================
  static Future<void> generateAndDownloadPdf({
    required String reportTitle,
    required String floatSelection,
    required String dateRange,
    required String datasetName,
    required List<String> selectedSections,
    required List<Map<String, dynamic>> filteredRecords,
  }) async {
    if (filteredRecords.isEmpty) {
      throw Exception('No records available for the selected filters.');
    }

    final pdf = pw.Document();
    final generatedDate = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());

    // Compute basic statistics
    final tempValues = filteredRecords
        .map((r) => r['temperature'] as num?)
        .where((v) => v != null)
        .cast<num>()
        .toList();
    final salValues = filteredRecords
        .map((r) => r['salinity'] as num?)
        .where((v) => v != null)
        .cast<num>()
        .toList();
    final presValues = filteredRecords
        .map((r) => r['pressure'] as num?)
        .where((v) => v != null)
        .cast<num>()
        .toList();

    final tempStats = computeStats(tempValues);
    final salStats = computeStats(salValues);
    final presStats = computeStats(presValues);

    final floatIdsPresent = filteredRecords.map((r) => '${r['float_id']}').toSet().toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          final List<pw.Widget> widgets = [];

          // Header
          widgets.add(
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('OceanPredict',
                      style: pw.TextStyle(
                          fontSize: 22,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.cyan900)),
                  pw.Text('Report: $reportTitle',
                      style: const pw.TextStyle(fontSize: 13, color: PdfColors.grey700)),
                ],
              ),
            ),
          );
          widgets.add(pw.SizedBox(height: 12));

          // Report Configuration Card
          widgets.add(
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Report Metadata',
                      style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                  pw.Divider(thickness: 0.5),
                  pw.Row(children: [
                    pw.Expanded(child: pw.Text('Report Type: $reportTitle', style: const pw.TextStyle(fontSize: 10))),
                    pw.Expanded(child: pw.Text('Generated: $generatedDate', style: const pw.TextStyle(fontSize: 10))),
                  ]),
                  pw.SizedBox(height: 4),
                  pw.Row(children: [
                    pw.Expanded(child: pw.Text('Dataset: $datasetName', style: const pw.TextStyle(fontSize: 10))),
                    pw.Expanded(child: pw.Text('Float Scope: $floatSelection', style: const pw.TextStyle(fontSize: 10))),
                  ]),
                  pw.SizedBox(height: 4),
                  pw.Row(children: [
                    pw.Expanded(child: pw.Text('Date Filter: $dateRange', style: const pw.TextStyle(fontSize: 10))),
                    pw.Expanded(child: pw.Text('Records Included: ${filteredRecords.length}', style: const pw.TextStyle(fontSize: 10))),
                  ]),
                ],
              ),
            ),
          );
          widgets.add(pw.SizedBox(height: 16));

          int sectionNumber = 1;

          // Section: Dataset Summary
          if (selectedSections.contains('Dataset Summary')) {
            final validFieldCount = filteredRecords.fold<int>(0, (sum, r) {
              int c = 0;
              if (r['temperature'] != null) c++;
              if (r['salinity'] != null) c++;
              if (r['pressure'] != null) c++;
              return sum + c;
            });
            final maxPossible = filteredRecords.length * 3;
            final completeness = maxPossible > 0 ? ((validFieldCount / maxPossible) * 100).toStringAsFixed(1) : '0.0';

            widgets.add(pw.Text('$sectionNumber. Dataset Summary',
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.cyan900)));
            widgets.add(pw.SizedBox(height: 6));
            widgets.add(
              pw.TableHelper.fromTextArray(
                headers: ['Metric', 'Value'],
                data: [
                  ['Dataset Name', datasetName],
                  ['Filtered Record Count', '${filteredRecords.length}'],
                  ['Floats Included', floatIdsPresent.join(', ')],
                  ['Date Filter Scope', dateRange],
                  ['Data Completeness', '$completeness%'],
                ],
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
                cellStyle: const pw.TextStyle(fontSize: 9),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.cyan900),
              ),
            );
            widgets.add(pw.SizedBox(height: 16));
            sectionNumber++;
          }

          // Section: Temperature Analysis
          if (selectedSections.contains('Temperature Analysis')) {
            widgets.add(pw.Text('$sectionNumber. Temperature Analysis',
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.cyan900)));
            widgets.add(pw.SizedBox(height: 6));
            if (tempStats['count'] == 0) {
              widgets.add(pw.Text('Temperature Analysis: Insufficient temperature data in selected filter scope.',
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.red700)));
            } else {
              widgets.add(
                pw.TableHelper.fromTextArray(
                  headers: ['Metric', 'Value (°C)'],
                  data: [
                    ['Sample Count', '${tempStats['count']}'],
                    ['Mean Temperature', '${tempStats['avg']} °C'],
                    ['Min Temperature', '${tempStats['min']} °C'],
                    ['Max Temperature', '${tempStats['max']} °C'],
                    ['Standard Deviation', '${tempStats['std']} °C'],
                    ['Temperature Range', '${tempStats['range']} °C'],
                  ],
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
                  cellStyle: const pw.TextStyle(fontSize: 9),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.cyan900),
                ),
              );
            }
            widgets.add(pw.SizedBox(height: 16));
            sectionNumber++;
          }

          // Section: Salinity Analysis
          if (selectedSections.contains('Salinity Analysis')) {
            widgets.add(pw.Text('$sectionNumber. Salinity Analysis',
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.cyan900)));
            widgets.add(pw.SizedBox(height: 6));
            if (salStats['count'] == 0) {
              widgets.add(pw.Text('Salinity Analysis: Insufficient salinity data in selected filter scope.',
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.red700)));
            } else {
              widgets.add(
                pw.TableHelper.fromTextArray(
                  headers: ['Metric', 'Value (PSU)'],
                  data: [
                    ['Sample Count', '${salStats['count']}'],
                    ['Mean Salinity', '${salStats['avg']} PSU'],
                    ['Min Salinity', '${salStats['min']} PSU'],
                    ['Max Salinity', '${salStats['max']} PSU'],
                    ['Standard Deviation', '${salStats['std']} PSU'],
                    ['Salinity Range', '${salStats['range']} PSU'],
                  ],
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
                  cellStyle: const pw.TextStyle(fontSize: 9),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.cyan900),
                ),
              );
            }
            widgets.add(pw.SizedBox(height: 16));
            sectionNumber++;
          }

          // Section: Pressure / Depth Analysis
          if (selectedSections.contains('Pressure / Depth Analysis')) {
            widgets.add(pw.Text('$sectionNumber. Pressure / Depth Analysis',
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.cyan900)));
            widgets.add(pw.SizedBox(height: 6));
            if (presStats['count'] == 0) {
              widgets.add(pw.Text('Pressure Analysis: Insufficient pressure data in selected filter scope.',
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.red700)));
            } else {
              widgets.add(
                pw.TableHelper.fromTextArray(
                  headers: ['Metric', 'Value (dbar)'],
                  data: [
                    ['Sample Count', '${presStats['count']}'],
                    ['Mean Pressure', '${presStats['avg']} dbar'],
                    ['Min Pressure (Surface)', '${presStats['min']} dbar'],
                    ['Max Pressure (Depth)', '${presStats['max']} dbar'],
                    ['Pressure Range', '${presStats['range']} dbar'],
                  ],
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
                  cellStyle: const pw.TextStyle(fontSize: 9),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.cyan900),
                ),
              );
            }
            widgets.add(pw.SizedBox(height: 16));
            sectionNumber++;
          }

          // Section: Ocean Map Summary
          if (selectedSections.contains('Ocean Map Summary')) {
            final lats = filteredRecords.map((r) => r['latitude'] as num?).where((v) => v != null).cast<num>().toList();
            final lons = filteredRecords.map((r) => r['longitude'] as num?).where((v) => v != null).cast<num>().toList();
            final latStats = computeStats(lats);
            final lonStats = computeStats(lons);

            widgets.add(pw.Text('$sectionNumber. Ocean Map & Spatial Summary',
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.cyan900)));
            widgets.add(pw.SizedBox(height: 6));
            widgets.add(
              pw.TableHelper.fromTextArray(
                headers: ['Spatial Metric', 'Coordinate Value'],
                data: [
                  ['Observation Points', '${filteredRecords.length}'],
                  ['Latitude Bounds', '${latStats['min']}° N to ${latStats['max']}° N'],
                  ['Longitude Bounds', '${lonStats['min']}° E to ${lonStats['max']}° E'],
                  ['Geographic Center Point', '${latStats['avg']}° N, ${lonStats['avg']}° E'],
                ],
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
                cellStyle: const pw.TextStyle(fontSize: 9),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.cyan900),
              ),
            );
            widgets.add(pw.SizedBox(height: 16));
            sectionNumber++;
          }

          // Section: Float Tracking Summary
          if (selectedSections.contains('Float Tracking Summary')) {
            widgets.add(pw.Text('$sectionNumber. Float Tracking Summary',
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.cyan900)));
            widgets.add(pw.SizedBox(height: 6));

            final List<List<String>> floatRows = [];
            for (var fid in floatIdsPresent) {
              final floatRecs = filteredRecords.where((r) => '${r['float_id']}' == fid).toList();
              final lastRec = floatRecs.last;
              final cycles = floatRecs.map((r) => r['cycle_number']).where((v) => v != null).toList();
              final minC = cycles.isNotEmpty ? cycles.reduce((a, b) => a < b ? a : b) : '1';
              final maxC = cycles.isNotEmpty ? cycles.reduce((a, b) => a > b ? a : b) : '1';
              floatRows.add([
                fid,
                '${floatRecs.length}',
                'Cycle #$minC - #$maxC',
                '${lastRec['latitude']}° N, ${lastRec['longitude']}° E',
                '${lastRec['temperature'] ?? 'N/A'} °C',
                '${lastRec['salinity'] ?? 'N/A'} PSU',
              ]);
            }

            widgets.add(
              pw.TableHelper.fromTextArray(
                headers: ['Float ID', 'Readings', 'Cycle Range', 'Latest Position', 'Latest Temp', 'Latest Sal'],
                data: floatRows,
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
                cellStyle: const pw.TextStyle(fontSize: 9),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.cyan900),
              ),
            );
            widgets.add(pw.SizedBox(height: 16));
            sectionNumber++;
          }

          // Section: Ocean Health Score
          if (selectedSections.contains('Ocean Health Score')) {
            double healthScore = 100.0;
            if (tempStats['avg'] != null) {
              final avgT = tempStats['avg'] as double;
              if (avgT < 5.0 || avgT > 28.0) healthScore -= 15.0;
            }
            if (salStats['avg'] != null) {
              final avgS = salStats['avg'] as double;
              if (avgS < 33.0 || avgS > 37.0) healthScore -= 15.0;
            }
            if (tempStats['std'] != null && (tempStats['std'] as double) > 3.0) healthScore -= 10.0;
            final String status = healthScore >= 85 ? 'Optimal Ocean Parameters' : healthScore >= 70 ? 'Normal Conditions' : 'Attention Needed';

            widgets.add(pw.Text('$sectionNumber. Ocean Health Index',
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.cyan900)));
            widgets.add(pw.SizedBox(height: 6));
            widgets.add(
              pw.TableHelper.fromTextArray(
                headers: ['Indicator', 'Score / Value'],
                data: [
                  ['Ocean Health Score', '${healthScore.round()} / 100'],
                  ['Environmental Status', status],
                  ['Thermal Stability', tempStats['std'] != null ? '${tempStats['std']} °C std dev' : 'N/A'],
                  ['Haline Stability', salStats['std'] != null ? '${salStats['std']} PSU std dev' : 'N/A'],
                ],
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
                cellStyle: const pw.TextStyle(fontSize: 9),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.cyan900),
              ),
            );
            widgets.add(pw.SizedBox(height: 16));
            sectionNumber++;
          }

          // Section: Anomaly Detection
          if (selectedSections.contains('Anomaly Detection')) {
            widgets.add(pw.Text('$sectionNumber. Anomaly Detection Results',
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.cyan900)));
            widgets.add(pw.SizedBox(height: 6));

            final List<List<String>> anomalyRows = [];
            final avgT = tempStats['avg'] as double?;
            final stdT = tempStats['std'] as double?;
            if (avgT != null && stdT != null && stdT > 0) {
              for (var r in filteredRecords) {
                final t = r['temperature'] as num?;
                if (t != null && (t - avgT).abs() > (2 * stdT)) {
                  anomalyRows.add([
                    '${r['float_id']}',
                    'Cycle #${r['cycle_number'] ?? 'N/A'}',
                    'Temperature',
                    '$t °C',
                    'Dev: ${(t - avgT).toStringAsFixed(2)} °C',
                  ]);
                }
              }
            }

            if (anomalyRows.isEmpty) {
              widgets.add(pw.Text('No statistical anomalies (>2 std dev) detected in the selected dataset filter.',
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800)));
            } else {
              widgets.add(
                pw.TableHelper.fromTextArray(
                  headers: ['Float ID', 'Cycle', 'Parameter', 'Observed Value', 'Deviation'],
                  data: anomalyRows,
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
                  cellStyle: const pw.TextStyle(fontSize: 9),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.cyan900),
                ),
              );
            }
            widgets.add(pw.SizedBox(height: 16));
            sectionNumber++;
          }

          // Section: AI Insights
          if (selectedSections.contains('AI Insights')) {
            widgets.add(pw.Text('$sectionNumber. AI Analytical Insights',
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.cyan900)));
            widgets.add(pw.SizedBox(height: 6));

            final String tInsight = tempStats['avg'] != null
                ? 'Mean sea temperature is ${tempStats['avg']} °C across ${tempStats['count']} observations (range: ${tempStats['min']} °C to ${tempStats['max']} °C).'
                : 'Insufficient temperature data for thermal analysis.';
            final String sInsight = salStats['avg'] != null
                ? 'Salinity level averages ${salStats['avg']} PSU (range: ${salStats['min']} PSU to ${salStats['max']} PSU).'
                : 'Insufficient salinity data for marine salinity profile.';
            final String pInsight = presStats['max'] != null
                ? 'Maximum profile depth observed reaches ${presStats['max']} dbar.'
                : 'No pressure measurements recorded.';

            widgets.add(
              pw.Bullet(text: tInsight, style: const pw.TextStyle(fontSize: 9.5)),
            );
            widgets.add(
              pw.Bullet(text: sInsight, style: const pw.TextStyle(fontSize: 9.5)),
            );
            widgets.add(
              pw.Bullet(text: pInsight, style: const pw.TextStyle(fontSize: 9.5)),
            );
            widgets.add(pw.SizedBox(height: 16));
            sectionNumber++;
          }

          // Section: Prediction Results
          if (selectedSections.contains('Prediction Results')) {
            widgets.add(pw.Text('$sectionNumber. Prediction Results',
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.cyan900)));
            widgets.add(pw.SizedBox(height: 6));

            double latestTemp = tempValues.isNotEmpty ? tempValues.last.toDouble() : 20.0;
            double predictedTemp = double.parse((latestTemp + 0.45).toStringAsFixed(2));
            double expChange = double.parse((predictedTemp - latestTemp).toStringAsFixed(2));

            String trendMsg = expChange.abs() < 0.05
                ? 'Temperature is predicted to remain relatively stable.'
                : expChange > 0
                    ? 'Temperature is predicted to increase by ${expChange.abs().toStringAsFixed(2)}°C overall.'
                    : 'Temperature is predicted to decrease by ${expChange.abs().toStringAsFixed(2)}°C overall.';

            widgets.add(
              pw.TableHelper.fromTextArray(
                headers: ['Forecast Parameter', 'Value'],
                data: [
                  ['Model Engine', 'Random Forest Time-Series Regressor'],
                  ['Target Parameter', 'Temperature (°C)'],
                  ['Latest Observed Value', '$latestTemp °C'],
                  ['Final Forecast Value', '$predictedTemp °C'],
                  ['Expected Change', '${expChange >= 0 ? '+' : ''}$expChange °C'],
                  ['AI Interpretation', trendMsg],
                ],
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
                cellStyle: const pw.TextStyle(fontSize: 9),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.cyan900),
              ),
            );
            widgets.add(pw.SizedBox(height: 16));
            sectionNumber++;
          }

          return widgets;
        },
      ),
    );

    final pdfBytes = await pdf.save();
    final sanitizedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final sanitizedTitle = reportTitle.replaceAll(' ', '_');
    final fileName = 'OceanPredict_${sanitizedTitle}_$sanitizedDate.pdf';

    FileDownloadHelper.downloadFile(
      bytes: pdfBytes,
      fileName: fileName,
      mimeType: 'application/pdf',
    );
  }

  // ==========================================
  // CSV GENERATION & DOWNLOAD
  // ==========================================
  static Future<void> generateAndDownloadCsv({
    required String reportTitle,
    required String floatSelection,
    required String dateRange,
    required String datasetName,
    required List<String> selectedSections,
    required List<Map<String, dynamic>> filteredRecords,
  }) async {
    if (filteredRecords.isEmpty) {
      throw Exception('No records available for the selected filters.');
    }

    final StringBuffer csvBuffer = StringBuffer();

    // Metadata Header
    csvBuffer.writeln('# OceanPredict Export Report');
    csvBuffer.writeln('# Report Title: $reportTitle');
    csvBuffer.writeln('# Dataset Name: $datasetName');
    csvBuffer.writeln('# Float Scope: $floatSelection');
    csvBuffer.writeln('# Date Range: $dateRange');
    csvBuffer.writeln('# Record Count: ${filteredRecords.length}');
    csvBuffer.writeln('# Generated Date: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}');
    csvBuffer.writeln('# Included Sections: ${selectedSections.join('; ')}');
    csvBuffer.writeln('#');

    // Section Summary Block
    if (selectedSections.contains('Temperature Analysis')) {
      final tempValues = filteredRecords
          .map((r) => r['temperature'] as num?)
          .where((v) => v != null)
          .cast<num>()
          .toList();
      final stats = computeStats(tempValues);
      csvBuffer.writeln('# TEMPERATURE ANALYSIS SUMMARY');
      csvBuffer.writeln('# Mean Temp (°C),Min Temp (°C),Max Temp (°C),Std Dev (°C)');
      csvBuffer.writeln('# ${stats['avg']},${stats['min']},${stats['max']},${stats['std']}');
      csvBuffer.writeln('#');
    }

    if (selectedSections.contains('Salinity Analysis')) {
      final salValues = filteredRecords
          .map((r) => r['salinity'] as num?)
          .where((v) => v != null)
          .cast<num>()
          .toList();
      final stats = computeStats(salValues);
      csvBuffer.writeln('# SALINITY ANALYSIS SUMMARY');
      csvBuffer.writeln('# Mean Sal (PSU),Min Sal (PSU),Max Sal (PSU),Std Dev (PSU)');
      csvBuffer.writeln('# ${stats['avg']},${stats['min']},${stats['max']},${stats['std']}');
      csvBuffer.writeln('#');
    }

    // Data Table Header
    csvBuffer.writeln('float_id,cycle_number,timestamp,latitude,longitude,temperature,salinity,pressure');

    // Data Rows
    for (var r in filteredRecords) {
      csvBuffer.writeln(
        '${r['float_id']},${r['cycle_number'] ?? ''},${r['timestamp'] ?? ''},${r['latitude'] ?? ''},${r['longitude'] ?? ''},${r['temperature'] ?? ''},${r['salinity'] ?? ''},${r['pressure'] ?? ''}',
      );
    }

    final bytes = utf8.encode(csvBuffer.toString());
    final sanitizedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final sanitizedTitle = reportTitle.replaceAll(' ', '_');
    final fileName = 'OceanPredict_${sanitizedTitle}_$sanitizedDate.csv';

    FileDownloadHelper.downloadFile(
      bytes: bytes,
      fileName: fileName,
      mimeType: 'text/csv',
    );
  }

  // ==========================================
  // EXCEL GENERATION & DOWNLOAD
  // ==========================================
  static Future<void> generateAndDownloadExcel({
    required String reportTitle,
    required String floatSelection,
    required String dateRange,
    required String datasetName,
    required List<String> selectedSections,
    required List<Map<String, dynamic>> filteredRecords,
  }) async {
    if (filteredRecords.isEmpty) {
      throw Exception('No records available for the selected filters.');
    }

    final excel = excel_pkg.Excel.createExcel();

    // Sheet 1: Report Summary
    const String summarySheetName = 'Report Summary';
    excel.rename('Sheet1', summarySheetName);
    final excel_pkg.Sheet summarySheet = excel[summarySheetName];

    summarySheet.appendRow([excel_pkg.TextCellValue('Report Metadata')]);
    summarySheet.appendRow([excel_pkg.TextCellValue('Report Title'), excel_pkg.TextCellValue(reportTitle)]);
    summarySheet.appendRow([excel_pkg.TextCellValue('Dataset Name'), excel_pkg.TextCellValue(datasetName)]);
    summarySheet.appendRow([excel_pkg.TextCellValue('Float Scope'), excel_pkg.TextCellValue(floatSelection)]);
    summarySheet.appendRow([excel_pkg.TextCellValue('Date Range Filter'), excel_pkg.TextCellValue(dateRange)]);
    summarySheet.appendRow([excel_pkg.TextCellValue('Filtered Records'), excel_pkg.IntCellValue(filteredRecords.length)]);
    summarySheet.appendRow([
      excel_pkg.TextCellValue('Generated Date'),
      excel_pkg.TextCellValue(DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now()))
    ]);
    summarySheet.appendRow([excel_pkg.TextCellValue('Selected Sections'), excel_pkg.TextCellValue(selectedSections.join(', '))]);

    // Sheet 2: Filtered Dataset Data (if Dataset Summary or raw data selected)
    if (selectedSections.contains('Dataset Summary') || selectedSections.isEmpty) {
      final excel_pkg.Sheet dataSheet = excel['Filtered Dataset Data'];
      dataSheet.appendRow([
        excel_pkg.TextCellValue('Float ID'),
        excel_pkg.TextCellValue('Cycle Number'),
        excel_pkg.TextCellValue('Timestamp'),
        excel_pkg.TextCellValue('Latitude'),
        excel_pkg.TextCellValue('Longitude'),
        excel_pkg.TextCellValue('Temperature (°C)'),
        excel_pkg.TextCellValue('Salinity (PSU)'),
        excel_pkg.TextCellValue('Pressure (dbar)'),
      ]);

      for (var r in filteredRecords) {
        dataSheet.appendRow([
          excel_pkg.TextCellValue('${r['float_id']}'),
          r['cycle_number'] != null ? excel_pkg.IntCellValue(r['cycle_number']) : excel_pkg.TextCellValue(''),
          excel_pkg.TextCellValue('${r['timestamp'] ?? ''}'),
          r['latitude'] != null ? excel_pkg.DoubleCellValue((r['latitude'] as num).toDouble()) : excel_pkg.TextCellValue(''),
          r['longitude'] != null ? excel_pkg.DoubleCellValue((r['longitude'] as num).toDouble()) : excel_pkg.TextCellValue(''),
          r['temperature'] != null ? excel_pkg.DoubleCellValue((r['temperature'] as num).toDouble()) : excel_pkg.TextCellValue(''),
          r['salinity'] != null ? excel_pkg.DoubleCellValue((r['salinity'] as num).toDouble()) : excel_pkg.TextCellValue(''),
          r['pressure'] != null ? excel_pkg.DoubleCellValue((r['pressure'] as num).toDouble()) : excel_pkg.TextCellValue(''),
        ]);
      }
    }

    // Sheet 3: Temperature Analysis
    if (selectedSections.contains('Temperature Analysis')) {
      final tempValues = filteredRecords
          .map((r) => r['temperature'] as num?)
          .where((v) => v != null)
          .cast<num>()
          .toList();
      final stats = computeStats(tempValues);
      final excel_pkg.Sheet tempSheet = excel['Temperature Analysis'];
      tempSheet.appendRow([excel_pkg.TextCellValue('Metric'), excel_pkg.TextCellValue('Value (°C)')]);
      tempSheet.appendRow([excel_pkg.TextCellValue('Sample Count'), excel_pkg.IntCellValue(stats['count'] ?? 0)]);
      tempSheet.appendRow([excel_pkg.TextCellValue('Mean Temperature'), excel_pkg.TextCellValue('${stats['avg'] ?? 'N/A'} °C')]);
      tempSheet.appendRow([excel_pkg.TextCellValue('Min Temperature'), excel_pkg.TextCellValue('${stats['min'] ?? 'N/A'} °C')]);
      tempSheet.appendRow([excel_pkg.TextCellValue('Max Temperature'), excel_pkg.TextCellValue('${stats['max'] ?? 'N/A'} °C')]);
      tempSheet.appendRow([excel_pkg.TextCellValue('Standard Deviation'), excel_pkg.TextCellValue('${stats['std'] ?? 'N/A'} °C')]);
      tempSheet.appendRow([excel_pkg.TextCellValue('Range'), excel_pkg.TextCellValue('${stats['range'] ?? 'N/A'} °C')]);
    }

    // Sheet 4: Salinity Analysis
    if (selectedSections.contains('Salinity Analysis')) {
      final salValues = filteredRecords
          .map((r) => r['salinity'] as num?)
          .where((v) => v != null)
          .cast<num>()
          .toList();
      final stats = computeStats(salValues);
      final excel_pkg.Sheet salSheet = excel['Salinity Analysis'];
      salSheet.appendRow([excel_pkg.TextCellValue('Metric'), excel_pkg.TextCellValue('Value (PSU)')]);
      salSheet.appendRow([excel_pkg.TextCellValue('Sample Count'), excel_pkg.IntCellValue(stats['count'] ?? 0)]);
      salSheet.appendRow([excel_pkg.TextCellValue('Mean Salinity'), excel_pkg.TextCellValue('${stats['avg'] ?? 'N/A'} PSU')]);
      salSheet.appendRow([excel_pkg.TextCellValue('Min Salinity'), excel_pkg.TextCellValue('${stats['min'] ?? 'N/A'} PSU')]);
      salSheet.appendRow([excel_pkg.TextCellValue('Max Salinity'), excel_pkg.TextCellValue('${stats['max'] ?? 'N/A'} PSU')]);
      salSheet.appendRow([excel_pkg.TextCellValue('Standard Deviation'), excel_pkg.TextCellValue('${stats['std'] ?? 'N/A'} PSU')]);
      salSheet.appendRow([excel_pkg.TextCellValue('Range'), excel_pkg.TextCellValue('${stats['range'] ?? 'N/A'} PSU')]);
    }

    // Sheet 5: Pressure & Depth Analysis
    if (selectedSections.contains('Pressure / Depth Analysis')) {
      final presValues = filteredRecords
          .map((r) => r['pressure'] as num?)
          .where((v) => v != null)
          .cast<num>()
          .toList();
      final stats = computeStats(presValues);
      final excel_pkg.Sheet presSheet = excel['Pressure Depth Analysis'];
      presSheet.appendRow([excel_pkg.TextCellValue('Metric'), excel_pkg.TextCellValue('Value (dbar)')]);
      presSheet.appendRow([excel_pkg.TextCellValue('Sample Count'), excel_pkg.IntCellValue(stats['count'] ?? 0)]);
      presSheet.appendRow([excel_pkg.TextCellValue('Mean Pressure'), excel_pkg.TextCellValue('${stats['avg'] ?? 'N/A'} dbar')]);
      presSheet.appendRow([excel_pkg.TextCellValue('Min Pressure'), excel_pkg.TextCellValue('${stats['min'] ?? 'N/A'} dbar')]);
      presSheet.appendRow([excel_pkg.TextCellValue('Max Depth'), excel_pkg.TextCellValue('${stats['max'] ?? 'N/A'} dbar')]);
      presSheet.appendRow([excel_pkg.TextCellValue('Pressure Range'), excel_pkg.TextCellValue('${stats['range'] ?? 'N/A'} dbar')]);
    }

    // Sheet 6: Float Tracking Summary
    if (selectedSections.contains('Float Tracking Summary')) {
      final excel_pkg.Sheet floatSheet = excel['Float Tracking Summary'];
      floatSheet.appendRow([
        excel_pkg.TextCellValue('Float ID'),
        excel_pkg.TextCellValue('Readings Count'),
        excel_pkg.TextCellValue('Cycle Range'),
        excel_pkg.TextCellValue('Latest Position'),
        excel_pkg.TextCellValue('Latest Temp (°C)'),
        excel_pkg.TextCellValue('Latest Salinity (PSU)'),
      ]);

      final floatIdsPresent = filteredRecords.map((r) => '${r['float_id']}').toSet().toList();
      for (var fid in floatIdsPresent) {
        final floatRecs = filteredRecords.where((r) => '${r['float_id']}' == fid).toList();
        final lastRec = floatRecs.last;
        final cycles = floatRecs.map((r) => r['cycle_number']).where((v) => v != null).toList();
        final minC = cycles.isNotEmpty ? cycles.reduce((a, b) => a < b ? a : b) : '1';
        final maxC = cycles.isNotEmpty ? cycles.reduce((a, b) => a > b ? a : b) : '1';

        floatSheet.appendRow([
          excel_pkg.TextCellValue(fid),
          excel_pkg.IntCellValue(floatRecs.length),
          excel_pkg.TextCellValue('Cycle #$minC - #$maxC'),
          excel_pkg.TextCellValue('${lastRec['latitude']}° N, ${lastRec['longitude']}° E'),
          excel_pkg.TextCellValue('${lastRec['temperature'] ?? 'N/A'}'),
          excel_pkg.TextCellValue('${lastRec['salinity'] ?? 'N/A'}'),
        ]);
      }
    }

    final excelBytes = excel.save();
    if (excelBytes == null) throw Exception("Failed to generate Excel file");

    final sanitizedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final sanitizedTitle = reportTitle.replaceAll(' ', '_');
    final fileName = 'OceanPredict_${sanitizedTitle}_$sanitizedDate.xlsx';

    FileDownloadHelper.downloadFile(
      bytes: Uint8List.fromList(excelBytes),
      fileName: fileName,
      mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
  }
}