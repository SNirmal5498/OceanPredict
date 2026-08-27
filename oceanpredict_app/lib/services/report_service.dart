// lib/services/report_service.dart
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:excel/excel.dart' as excel_pkg;
import 'file_download_web.dart';

class ReportService {

  // ==========================================
  // PDF GENERATION & DOWNLOAD
  // ==========================================
  static Future<void> generateAndDownloadPdf({
    required String reportTitle,
    required String floatSelection,
    required String dateRange,
    required int totalRecords,
    required Map<String, dynamic> datasetSummary,
    required Map<String, dynamic> temperatureAnalysis,
    required Map<String, dynamic> salinityAnalysis,
  }) async {
    final pdf = pw.Document();
    final generatedDate = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Header
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('OceanPredict',
                      style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue900)),
                  pw.Text('Report: $reportTitle',
                      style: const pw.TextStyle(
                          fontSize: 14, color: PdfColors.grey700)),
                ],
              ),
            ),
            pw.SizedBox(height: 16),

            // Report Metadata Card
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Report Configuration',
                      style: pw.TextStyle(
                          fontSize: 14, fontWeight: pw.FontWeight.bold)),
                  pw.Divider(),
                  pw.Row(children: [
                    pw.Expanded(child: pw.Text('Report Type: $reportTitle')),
                    pw.Expanded(child: pw.Text('Generation Date: $generatedDate')),
                  ]),
                  pw.SizedBox(height: 4),
                  pw.Row(children: [
                    pw.Expanded(child: pw.Text('Selected Float: $floatSelection')),
                    pw.Expanded(child: pw.Text('Date Range: $dateRange')),
                  ]),
                  pw.SizedBox(height: 4),
                  pw.Text('Total Records: $totalRecords'),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Section 1: Dataset Summary
            pw.Text('1. Dataset Summary',
                style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue800)),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headers: ['Metric', 'Value'],
              data: datasetSummary.entries
                  .map((e) => [e.key, e.value.toString()])
                  .toList(),
              headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration:
                  const pw.BoxDecoration(color: PdfColors.blue800),
            ),
            pw.SizedBox(height: 20),

            // Section 2: Temperature Analysis
            pw.Text('2. Temperature Analysis',
                style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue800)),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headers: ['Metric', 'Temperature (°C)'],
              data: temperatureAnalysis.entries
                  .map((e) => [e.key, e.value.toString()])
                  .toList(),
              headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration:
                  const pw.BoxDecoration(color: PdfColors.blue800),
            ),
            pw.SizedBox(height: 20),

            // Section 3: Salinity Analysis
            pw.Text('3. Salinity Analysis',
                style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue800)),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headers: ['Metric', 'Salinity (PSU)'],
              data: salinityAnalysis.entries
                  .map((e) => [e.key, e.value.toString()])
                  .toList(),
              headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration:
                  const pw.BoxDecoration(color: PdfColors.blue800),
            ),
          ];
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
  // EXCEL GENERATION & DOWNLOAD
  // ==========================================
  static Future<void> generateAndDownloadExcel({
    required String reportTitle,
    required String floatSelection,
    required String dateRange,
    required int totalRecords,
    required List<Map<String, dynamic>> rawDatasetRows,
    required Map<String, dynamic> temperatureAnalysis,
    required Map<String, dynamic> salinityAnalysis,
  }) async {
    final excel = excel_pkg.Excel.createExcel();

    // Sheet 1: Report Summary
    const String summarySheetName = 'Report Summary';
    excel.rename('Sheet1', summarySheetName);
    final excel_pkg.Sheet summarySheet = excel[summarySheetName];

    summarySheet.appendRow([excel_pkg.TextCellValue('Report Metadata')]);
    summarySheet.appendRow([excel_pkg.TextCellValue('Report Title'), excel_pkg.TextCellValue(reportTitle)]);
    summarySheet.appendRow([excel_pkg.TextCellValue('Selected Float'), excel_pkg.TextCellValue(floatSelection)]);
    summarySheet.appendRow([excel_pkg.TextCellValue('Date Range'), excel_pkg.TextCellValue(dateRange)]);
    summarySheet.appendRow([excel_pkg.TextCellValue('Total Records'), excel_pkg.IntCellValue(totalRecords)]);
    summarySheet.appendRow([
      excel_pkg.TextCellValue('Generated Date'),
      excel_pkg.TextCellValue(DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now()))
    ]);

    // Sheet 2: Dataset Data
    if (rawDatasetRows.isNotEmpty) {
      final excel_pkg.Sheet dataSheet = excel['Dataset Data'];
      final headers = rawDatasetRows.first.keys.toList();
      dataSheet.appendRow(headers.map((h) => excel_pkg.TextCellValue(h)).toList());

      for (var row in rawDatasetRows) {
        final rowValues = headers.map((key) {
          final val = row[key];
          if (val is int) return excel_pkg.IntCellValue(val);
          if (val is double) return excel_pkg.DoubleCellValue(val);
          return excel_pkg.TextCellValue(val?.toString() ?? '');
        }).toList();
        dataSheet.appendRow(rowValues);
      }
    }

    // Sheet 3: Temperature Analysis
    if (temperatureAnalysis.isNotEmpty) {
      final excel_pkg.Sheet tempSheet = excel['Temperature Analysis'];
      tempSheet.appendRow([excel_pkg.TextCellValue('Metric'), excel_pkg.TextCellValue('Value (°C)')]);
      temperatureAnalysis.forEach((key, val) {
        tempSheet.appendRow([excel_pkg.TextCellValue(key), excel_pkg.TextCellValue(val.toString())]);
      });
    }

    // Sheet 4: Salinity Analysis
    if (salinityAnalysis.isNotEmpty) {
      final excel_pkg.Sheet salSheet = excel['Salinity Analysis'];
      salSheet.appendRow([excel_pkg.TextCellValue('Metric'), excel_pkg.TextCellValue('Value (PSU)')]);
      salinityAnalysis.forEach((key, val) {
        salSheet.appendRow([excel_pkg.TextCellValue(key), excel_pkg.TextCellValue(val.toString())]);
      });
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