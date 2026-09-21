import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/report_service.dart';

// ============================================================
// Data Models & Exceptions
// ============================================================
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

class ReportGenerationException implements Exception {
  final String message;
  ReportGenerationException(this.message);

  @override
  String toString() => message;
}

// ============================================================
// Main Screen Widget
// ============================================================
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

enum _DatasetState { loading, error, ready }
enum _GenState { idle, generating }

class _ReportsScreenState extends State<ReportsScreen> {
  _DatasetState _datasetState = _DatasetState.loading;
  Map<String, dynamic>? _stats;
  List<Map<String, dynamic>> _records = [];
  List<String> _floatIds = [];
  bool _timestampAvailable = false;
  String? _minTimestampStr;
  String? _maxTimestampStr;
  DateTime? _maxTimestamp;

  String _reportType = 'Complete Ocean Report';
  String _dateRange = 'All Data';
  String _selectedFloat = 'all';

  final Map<String, bool> _sections = {
    'Dataset Summary': true,
    'Temperature Analysis': true,
    'Salinity Analysis': true,
    'Pressure / Depth Analysis': false,
    'Ocean Map Summary': false,
    'Float Tracking Summary': false,
    'Ocean Health Score': false,
    'Anomaly Detection': false,
    'AI Insights': false,
    'Prediction Results': false,
  };

  _GenState _genState = _GenState.idle;
  String? _generatingFormat;
  GeneratedReportInfo? _lastSuccess;
  String? _lastError;

  final List<GeneratedReportInfo> _history = [];

  @override
  void initState() {
    super.initState();
    _loadDatasetInfo();
  }

  Future<void> _loadDatasetInfo() async {
    setState(() => _datasetState = _DatasetState.loading);

    final statsResult = await ApiService.getDashboardStats();
    final reportDataResult = await ApiService.getReportData();

    if (!mounted) return;

    if (statsResult['statusCode'] != 200 || reportDataResult['statusCode'] != 200) {
      setState(() => _datasetState = _DatasetState.error);
      return;
    }

    final statsBody = statsResult['body'] as Map<String, dynamic>;
    final reportBody = reportDataResult['body'] as Map<String, dynamic>;

    final rawRecords = (reportBody['records'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    final tsAvail = reportBody['timestamp_available'] == true;
    final minTsStr = reportBody['min_timestamp'] as String?;
    final maxTsStr = reportBody['max_timestamp'] as String?;
    DateTime? parsedMaxTs;
    if (maxTsStr != null) {
      try {
        parsedMaxTs = DateTime.parse(maxTsStr);
      } catch (_) {}
    }

    final rawFloatIds = (reportBody['float_ids'] as List? ?? statsBody['float_ids'] as List? ?? []);
    final floatIdsList = rawFloatIds.map((e) => '$e').toList();

    setState(() {
      _stats = statsBody;
      _records = rawRecords;
      _floatIds = floatIdsList;
      _timestampAvailable = tsAvail;
      _minTimestampStr = minTsStr;
      _maxTimestampStr = maxTsStr;
      _maxTimestamp = parsedMaxTs;
      _datasetState = _DatasetState.ready;
    });
  }

  List<Map<String, dynamic>> _getFilteredRecords() {
    List<Map<String, dynamic>> list = _records;

    if (_selectedFloat != 'all') {
      list = list.where((r) => '${r['float_id']}' == _selectedFloat).toList();
    }

    if (_timestampAvailable && _maxTimestamp != null && _dateRange != 'All Data') {
      DateTime cutoff;
      if (_dateRange == 'Last 7 Days') {
        cutoff = _maxTimestamp!.subtract(const Duration(days: 7));
      } else if (_dateRange == 'Last 30 Days') {
        cutoff = _maxTimestamp!.subtract(const Duration(days: 30));
      } else if (_dateRange == 'Last 6 Months') {
        cutoff = _maxTimestamp!.subtract(const Duration(days: 180));
      } else {
        cutoff = DateTime.fromMillisecondsSinceEpoch(0);
      }

      list = list.where((r) {
        final tsStr = r['timestamp'] as String?;
        if (tsStr == null) return false;
        try {
          final dt = DateTime.parse(tsStr);
          return dt.isAfter(cutoff) || dt.isAtSameMomentAs(cutoff);
        } catch (_) {
          return false;
        }
      }).toList();
    }

    return list;
  }

  Future<void> _generate(String format) async {
    if (_genState == _GenState.generating) return;

    final filtered = _getFilteredRecords();
    if (filtered.isEmpty) {
      setState(() {
        _lastError = 'No records matching the selected float and date range filters.';
      });
      return;
    }

    final selectedSections = _sections.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();

    if (selectedSections.isEmpty) {
      setState(() {
        _lastError = 'Please select at least one report section to include.';
      });
      return;
    }

    setState(() {
      _genState = _GenState.generating;
      _generatingFormat = format;
      _lastSuccess = null;
      _lastError = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Generating $format report...'),
        duration: const Duration(seconds: 1),
      ),
    );

    try {
      final datasetName = _stats?['dataset_name'] ?? 'Combined Dataset';
      final floatLabel = _selectedFloat == 'all' ? 'All Floats' : _selectedFloat;
      final dateLabel = _timestampAvailable ? _dateRange : 'All Data (Timestamp N/A)';

      switch (format) {
        case 'CSV':
          await ReportService.generateAndDownloadCsv(
            reportTitle: _reportType,
            floatSelection: floatLabel,
            dateRange: dateLabel,
            datasetName: datasetName,
            selectedSections: selectedSections,
            filteredRecords: filtered,
          );
          break;

        case 'PDF':
          await ReportService.generateAndDownloadPdf(
            reportTitle: _reportType,
            floatSelection: floatLabel,
            dateRange: dateLabel,
            datasetName: datasetName,
            selectedSections: selectedSections,
            filteredRecords: filtered,
          );
          break;

        case 'Excel':
        default:
          await ReportService.generateAndDownloadExcel(
            reportTitle: _reportType,
            floatSelection: floatLabel,
            dateRange: dateLabel,
            datasetName: datasetName,
            selectedSections: selectedSections,
            filteredRecords: filtered,
          );
          break;
      }

      final sanitizedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final sanitizedTitle = _reportType.replaceAll(' ', '_');
      final ext = format == 'Excel' ? 'xlsx' : format.toLowerCase();
      final fileName = 'OceanPredict_${sanitizedTitle}_$sanitizedDate.$ext';

      final info = GeneratedReportInfo(
        fileName: fileName,
        format: format,
        generatedAt: DateTime.now(),
        recordCount: filtered.length,
      );

      if (!mounted) return;
      setState(() {
        _lastSuccess = info;
        _genState = _GenState.idle;
        _history.insert(0, info);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$format report generated successfully.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _lastError = 'Unable to generate $format report: ${e.toString().replaceAll('Exception: ', '')}';
        _genState = _GenState.idle;
      });
    }
  }

  void _showHistoryDetails(GeneratedReportInfo info) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(info.fileName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const Divider(height: 24),
            _row('Format', info.format),
            _row('Generated', _formatDate(info.generatedAt)),
            _row('Records', '${info.recordCount}'),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('This file was already downloaded when generated.')),
                      );
                    },
                    child: const Text('Download'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _confirmDelete(info);
                    },
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('Delete'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(GeneratedReportInfo info) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this report?'),
        content: const Text('This removes it from your report history for this session.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              setState(() => _history.remove(info));
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.day}/${d.month}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5)),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3FAFC),
      appBar: AppBar(title: const Text('Reports')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_datasetState == _DatasetState.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_datasetState == _DatasetState.error) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            const Text('Unable to load dataset', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _loadDatasetInfo, child: const Text('Try Again')),
          ],
        ),
      );
    }

    final width = MediaQuery.of(context).size.width;
    final isWide = width >= 900;
    final includedSections = _sections.entries.where((e) => e.value).map((e) => e.key).toList();
    final filteredRecords = _getFilteredRecords();

    final header = _Header();
    final datasetSummary = _DatasetSummaryCard(
      stats: _stats!,
      timestampAvailable: _timestampAvailable,
      minTimestamp: _minTimestampStr,
      maxTimestamp: _maxTimestampStr,
    );
    final config = _ReportConfigCard(
      reportType: _reportType,
      dateRange: _dateRange,
      selectedFloat: _selectedFloat,
      floatIds: _floatIds,
      timestampAvailable: _timestampAvailable,
      minTimestamp: _minTimestampStr,
      maxTimestamp: _maxTimestampStr,
      onTypeChanged: (v) => setState(() => _reportType = v),
      onDateRangeChanged: (v) => setState(() => _dateRange = v),
      onFloatChanged: (v) => setState(() => _selectedFloat = v),
    );
    final content = _ReportContentCard(
      sections: _sections,
      onToggle: (key, value) => setState(() => _sections[key] = value),
    );
    final preview = _ReportPreviewCard(
      reportType: _reportType,
      selectedFloat: _selectedFloat,
      dateRange: _dateRange,
      totalRecords: _stats!['total_records'] ?? _records.length,
      filteredCount: filteredRecords.length,
      sections: includedSections,
    );
    final generateSection = _GenerateSection(
      genState: _genState,
      generatingFormat: _generatingFormat,
      lastSuccess: _lastSuccess,
      lastError: _lastError,
      onGenerate: _generate,
    );
    final history = _ReportHistorySection(history: _history, onTap: _showHistoryDetails);

    if (isWide) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Column(children: [config, const SizedBox(height: 16), content])),
                const SizedBox(width: 16),
                Expanded(child: Column(children: [datasetSummary, const SizedBox(height: 16), preview])),
              ],
            ),
            const SizedBox(height: 16),
            generateSection,
            const SizedBox(height: 16),
            history,
            const SizedBox(height: 20),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          const SizedBox(height: 16),
          datasetSummary,
          const SizedBox(height: 16),
          config,
          const SizedBox(height: 16),
          content,
          const SizedBox(height: 16),
          preview,
          const SizedBox(height: 16),
          generateSection,
          const SizedBox(height: 16),
          history,
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ============================================================
// UI Components
// ============================================================
class _SoftCard extends StatelessWidget {
  final Widget child;
  const _SoftCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 14, offset: const Offset(0, 5))],
      ),
      child: child,
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(colors: [Colors.cyan.shade700, Colors.cyan.shade900]),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Reports', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          SizedBox(height: 4),
          Text('Generate and download ocean data analysis reports',
              style: TextStyle(color: Colors.white70, fontSize: 12.5)),
        ],
      ),
    );
  }
}

class _DatasetSummaryCard extends StatelessWidget {
  final Map<String, dynamic> stats;
  final bool timestampAvailable;
  final String? minTimestamp;
  final String? maxTimestamp;

  const _DatasetSummaryCard({
    required this.stats,
    required this.timestampAvailable,
    this.minTimestamp,
    this.maxTimestamp,
  });

  @override
  Widget build(BuildContext context) {
    final dateRangeText = timestampAvailable && minTimestamp != null && maxTimestamp != null
        ? '${minTimestamp!.split(' ').first} to ${maxTimestamp!.split(' ').first}'
        : 'Date filtering unavailable';

    return _SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Dataset Summary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const Divider(height: 20),
          _row('Dataset Name', stats['dataset_name'] ?? 'Combined Dataset (all uploads)'),
          _row('Total Records', '${stats['total_records']}'),
          _row('Total Floats', '${stats['active_floats']}'),
          _row('Date Range', dateRangeText),
          if (!timestampAvailable)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Active dataset contains no timestamp entries.',
                  style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500, fontStyle: FontStyle.italic)),
            ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5)),
            Flexible(
                child: Text(value,
                    textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5))),
          ],
        ),
      );
}

class _ReportConfigCard extends StatelessWidget {
  final String reportType;
  final String dateRange;
  final String selectedFloat;
  final List<String> floatIds;
  final bool timestampAvailable;
  final String? minTimestamp;
  final String? maxTimestamp;
  final ValueChanged<String> onTypeChanged;
  final ValueChanged<String> onDateRangeChanged;
  final ValueChanged<String> onFloatChanged;

  const _ReportConfigCard({
    required this.reportType,
    required this.dateRange,
    required this.selectedFloat,
    required this.floatIds,
    required this.timestampAvailable,
    this.minTimestamp,
    this.maxTimestamp,
    required this.onTypeChanged,
    required this.onDateRangeChanged,
    required this.onFloatChanged,
  });

  static const _reportTypes = [
    'Complete Ocean Report',
    'Temperature Analysis',
    'Salinity Analysis',
    'Float Report',
    'Analytics Summary',
    'Prediction Report',
  ];

  @override
  Widget build(BuildContext context) {
    final minDate = minTimestamp != null ? minTimestamp!.split(' ').first : '';
    final maxDate = maxTimestamp != null ? maxTimestamp!.split(' ').first : '';

    return _SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Generate New Report', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: reportType,
            decoration: const InputDecoration(labelText: 'Report Type', border: OutlineInputBorder(), isDense: true),
            items: _reportTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
            onChanged: (v) => v != null ? onTypeChanged(v) : null,
          ),
          const SizedBox(height: 12),
          Opacity(
            opacity: timestampAvailable ? 1.0 : 0.6,
            child: DropdownButtonFormField<String>(
              initialValue: dateRange,
              decoration: const InputDecoration(labelText: 'Date Range', border: OutlineInputBorder(), isDense: true),
              items: [
                const DropdownMenuItem(value: 'All Data', child: Text('All Data')),
                DropdownMenuItem(
                    value: 'Last 7 Days',
                    child: Text(timestampAvailable ? 'Last 7 Days' : 'Last 7 Days (unavailable)')),
                DropdownMenuItem(
                    value: 'Last 30 Days',
                    child: Text(timestampAvailable ? 'Last 30 Days' : 'Last 30 Days (unavailable)')),
                DropdownMenuItem(
                    value: 'Last 6 Months',
                    child: Text(timestampAvailable ? 'Last 6 Months' : 'Last 6 Months (unavailable)')),
              ],
              onChanged: timestampAvailable ? (v) => v != null ? onDateRangeChanged(v) : null : null,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              timestampAvailable
                  ? 'Filtering by dataset timestamps ($minDate to $maxDate)'
                  : 'Date filtering unavailable — dataset has no timestamp field yet.',
              style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: selectedFloat,
            decoration: const InputDecoration(labelText: 'Float', border: OutlineInputBorder(), isDense: true),
            items: [
              const DropdownMenuItem(value: 'all', child: Text('All Floats')),
              ...floatIds.map((id) => DropdownMenuItem(value: id, child: Text(id))),
            ],
            onChanged: (v) => v != null ? onFloatChanged(v) : null,
          ),
        ],
      ),
    );
  }
}

class _ReportContentCard extends StatelessWidget {
  final Map<String, bool> sections;
  final void Function(String key, bool value) onToggle;

  const _ReportContentCard({required this.sections, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return _SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Include in Report', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 4),
          ...sections.entries.map((e) => CheckboxListTile(
                value: e.value,
                onChanged: (v) => onToggle(e.key, v ?? false),
                title: Text(e.key, style: const TextStyle(fontSize: 13)),
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: Colors.cyan.shade700,
              )),
        ],
      ),
    );
  }
}

class _ReportPreviewCard extends StatelessWidget {
  final String reportType;
  final String selectedFloat;
  final String dateRange;
  final int totalRecords;
  final int filteredCount;
  final List<String> sections;

  const _ReportPreviewCard({
    required this.reportType,
    required this.selectedFloat,
    required this.dateRange,
    required this.totalRecords,
    required this.filteredCount,
    required this.sections,
  });

  @override
  Widget build(BuildContext context) {
    return _SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Report Preview', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const Divider(height: 20),
          _row('Report', reportType),
          _row('Float', selectedFloat == 'all' ? 'All Floats' : selectedFloat),
          _row('Date Range', dateRange),
          _row('Records', '$filteredCount of $totalRecords dataset records'),
          const SizedBox(height: 6),
          Text('Sections', style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5)),
          const SizedBox(height: 4),
          sections.isEmpty
              ? Text('None selected', style: TextStyle(fontSize: 12.5, color: Colors.grey.shade500))
              : Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: sections
                      .map((s) => Chip(
                            label: Text(s, style: const TextStyle(fontSize: 11)),
                            backgroundColor: Colors.cyan.shade50,
                            visualDensity: VisualDensity.compact,
                          ))
                      .toList(),
                ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5)),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: Text(value,
                  textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
            ),
          ],
        ),
      );
}

class _GenerateSection extends StatelessWidget {
  final _GenState genState;
  final String? generatingFormat;
  final GeneratedReportInfo? lastSuccess;
  final String? lastError;
  final void Function(String format) onGenerate;

  const _GenerateSection({
    required this.genState,
    required this.generatingFormat,
    required this.lastSuccess,
    required this.lastError,
    required this.onGenerate,
  });

  @override
  Widget build(BuildContext context) {
    final busy = genState == _GenState.generating;

    Widget button(String format, IconData icon) => Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ElevatedButton.icon(
              onPressed: busy ? null : () => onGenerate(format),
              icon: busy && generatingFormat == format
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Icon(icon, size: 18),
              label: Text(format),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.cyan.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (busy)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text('Generating report...', style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5)),
          ),
        Row(
          children: [
            button('PDF', Icons.picture_as_pdf_outlined),
            button('CSV', Icons.table_chart_outlined),
            button('Excel', Icons.grid_on_outlined),
          ],
        ),
        if (lastSuccess != null) ...[
          const SizedBox(height: 12),
          _SoftCard(
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Report Generated Successfully', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      Text('${lastSuccess!.fileName} • ${lastSuccess!.recordCount} records',
                          style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        if (lastError != null) ...[
          const SizedBox(height: 12),
          _SoftCard(
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(lastError!, style: const TextStyle(fontSize: 12.5))),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _ReportHistorySection extends StatelessWidget {
  final List<GeneratedReportInfo> history;
  final void Function(GeneratedReportInfo) onTap;

  const _ReportHistorySection({required this.history, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Report History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 10),
          if (history.isEmpty)
            Text('No reports generated yet.', style: TextStyle(color: Colors.grey.shade600, fontSize: 13))
          else
            ...history.map((h) => InkWell(
                  onTap: () => onTap(h),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      children: [
                        Icon(Icons.description_outlined, color: Colors.cyan.shade700),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(h.fileName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              Text(
                                '${h.format} • Generated ${h.generatedAt.day}/${h.generatedAt.month}/${h.generatedAt.year} • ${h.recordCount} records',
                                style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right, color: Colors.grey.shade400),
                      ],
                    ),
                  ),
                )),
        ],
      ),
    );
  }
}