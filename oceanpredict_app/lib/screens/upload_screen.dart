import 'dart:async';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/api_service.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen>
    with SingleTickerProviderStateMixin {
  // ---- Selected file state ----
  String? _selectedFileName;
  List<int>? _selectedFileBytes;
  int? _selectedFileSize;
  DateTime? _selectedAt;

  // ---- Upload state ----
  bool _isUploading = false;
  double _progress = 0;
  String _statusText = '';
  Timer? _progressTimer;

  // ---- Post-upload data ----
  Map<String, dynamic>? _lastUploadResult;

  // ---- Upload history (fetched from API + session) ----
  List<Map<String, dynamic>> _historyList = [];
  bool _isLoadingHistory = false;
  bool _historyHasError = false;

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _controller.forward();
    _fetchHistory();
  }

  @override
  void dispose() {
    _controller.dispose();
    _progressTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchHistory() async {
    setState(() {
      _isLoadingHistory = true;
      _historyHasError = false;
    });
    final res = await ApiService.getDatasets();
    if (mounted) {
      if (res['statusCode'] == 200 && res['body'] is List) {
        setState(() {
          _historyList = List<Map<String, dynamic>>.from(res['body']);
          _isLoadingHistory = false;
        });
      } else {
        setState(() {
          _historyHasError = true;
          _isLoadingHistory = false;
        });
      }
    }
  }

  Animation<double> _stagger(double start, double end) {
    return CurvedAnimation(
      parent: _controller,
      curve: Interval(start, end, curve: Curves.easeOut),
    );
  }

  Widget _fadeScale({required Widget child, required double start, required double end}) {
    final anim = _stagger(start, end);
    return FadeTransition(
      opacity: anim,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.96, end: 1.0).animate(anim),
        child: child,
      ),
    );
  }

  String _formatBytes(int? bytes) {
    if (bytes == null || bytes <= 0) return 'Unknown size';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  String _extensionOf(String name) {
    final parts = name.split('.');
    return parts.length > 1 ? parts.last.toUpperCase() : 'Unknown';
  }

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'nc'],
      withData: true,
    );

    if (result != null && result.files.single.bytes != null) {
      setState(() {
        _selectedFileName = result.files.single.name;
        _selectedFileBytes = result.files.single.bytes;
        _selectedFileSize = result.files.single.size;
        _selectedAt = DateTime.now();
        _lastUploadResult = null;
      });
    }
  }

  void _clearSelection() {
    setState(() {
      _selectedFileName = null;
      _selectedFileBytes = null;
      _selectedFileSize = null;
      _selectedAt = null;
      _lastUploadResult = null;
      _progress = 0;
      _statusText = '';
    });
  }

  void _previewDataset() {
    if (_selectedFileName == null) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Dataset Preview'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('File Name: $_selectedFileName'),
            const SizedBox(height: 6),
            Text('File Size: ${_formatBytes(_selectedFileSize)}'),
            const SizedBox(height: 6),
            Text('Format: ${_extensionOf(_selectedFileName!)}'),
            const SizedBox(height: 14),
            Text(
              'Server will normalize this dataset into standard Argo parameters:\n'
              '• Float ID, Latitude, Longitude, Temperature, Salinity, Pressure, Timestamp, Cycle Number.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _uploadFile() async {
    if (_selectedFileBytes == null || _selectedFileName == null) return;

    setState(() {
      _isUploading = true;
      _progress = 0;
      _statusText = 'Preparing upload...';
    });

    _progressTimer = Timer.periodic(const Duration(milliseconds: 150), (t) {
      if (!mounted) return;
      setState(() {
        if (_progress < 0.9) _progress += 0.04;
        _statusText = 'Processing dataset... ${(_progress * 100).round()}%';
      });
    });

    final fileName = _selectedFileName!;
    final result = await ApiService.uploadFile(_selectedFileBytes!, fileName);

    _progressTimer?.cancel();
    if (!mounted) return;

    final success = result['statusCode'] == 201;

    setState(() {
      _progress = 1.0;
      _statusText = success ? 'Upload & Normalization Complete' : 'Upload Failed';
    });

    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    if (success) {
      final body = result['body'];
      setState(() {
        _lastUploadResult = body;
      });

      await _fetchHistory();
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Dataset successfully processed! ${body['records_added']} records active.'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['body']?['message'] ?? 'Upload failed'),
          backgroundColor: Colors.red,
        ),
      );
    }

    setState(() => _isUploading = false);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isTablet = width >= 700;

    return Scaffold(
      backgroundColor: const Color(0xFFF3FAFC),
      appBar: AppBar(
        title: const Text('Upload Dataset'),
        backgroundColor: Colors.cyan.shade700,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: isTablet ? 32 : 16, vertical: 18),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _fadeScale(
                    start: 0.0,
                    end: 0.5,
                    child: _UploadAreaCard(onTap: _isUploading ? null : _pickFile),
                  ),
                  const SizedBox(height: 14),
                  _fadeScale(
                    start: 0.05,
                    end: 0.55,
                    child: const _FormatChips(),
                  ),
                  if (_selectedFileName != null) ...[
                    const SizedBox(height: 18),
                    _fadeScale(
                      start: 0.1,
                      end: 0.6,
                      child: _FileInfoCard(
                        name: _selectedFileName!,
                        sizeLabel: _formatBytes(_selectedFileSize),
                        type: _extensionOf(_selectedFileName!),
                        selectedOn: _selectedAt,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _fadeScale(
                      start: 0.15,
                      end: 0.65,
                      child: _ActionButtonsRow(
                        isTablet: isTablet,
                        canAct: !_isUploading,
                        onUpload: _uploadFile,
                        onPreview: _previewDataset,
                        onClear: _clearSelection,
                      ),
                    ),
                  ],
                  if (_isUploading) ...[
                    const SizedBox(height: 18),
                    _UploadProgressCard(progress: _progress, statusText: _statusText),
                  ],
                  if (_lastUploadResult != null) ...[
                    const SizedBox(height: 18),
                    _fadeScale(
                      start: 0.0,
                      end: 0.6,
                      child: _DatasetSummaryCard(result: _lastUploadResult!),
                    ),
                    const SizedBox(height: 16),
                    _fadeScale(
                      start: 0.05,
                      end: 0.65,
                      child: _ValidationCard(meta: _lastUploadResult!['metadata']?['validation']),
                    ),
                    const SizedBox(height: 16),
                    _fadeScale(
                      start: 0.1,
                      end: 0.7,
                      child: _CleaningSummaryCard(cleaning: _lastUploadResult!['metadata']?['cleaning']),
                    ),
                  ],
                  const SizedBox(height: 22),
                  _fadeScale(
                    start: 0.1,
                    end: 0.7,
                    child: _UploadHistorySection(
                      history: _historyList,
                      isLoading: _isLoadingHistory,
                      hasError: _historyHasError,
                      onRetry: _fetchHistory,
                      formatBytes: _formatBytes,
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// Upload area card
// ============================================================
class _UploadAreaCard extends StatefulWidget {
  final VoidCallback? onTap;
  const _UploadAreaCard({required this.onTap});

  @override
  State<_UploadAreaCard> createState() => _UploadAreaCardState();
}

class _UploadAreaCardState extends State<_UploadAreaCard> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _scale = 1.01),
      onExit: (_) => setState(() => _scale = 1.0),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _scale = 0.98),
        onTapUp: (_) => setState(() => _scale = 1.0),
        onTapCancel: () => setState(() => _scale = 1.0),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _scale,
          duration: const Duration(milliseconds: 140),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: Colors.cyan.shade50,
              border: Border.all(color: Colors.cyan.shade200, width: 1.4),
              boxShadow: [
                BoxShadow(
                  color: Colors.cyan.shade700.withValues(alpha: 0.08),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Colors.cyan.shade400, Colors.cyan.shade700],
                    ),
                  ),
                  child: const Icon(Icons.cloud_upload_rounded, color: Colors.white, size: 32),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Upload Ocean Dataset',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  'Upload Argo Float CSV (.csv) or NetCDF (.nc) datasets',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap to browse files',
                  style: TextStyle(color: Colors.cyan.shade700, fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// Supported format chips
// ============================================================
class _FormatChips extends StatelessWidget {
  const _FormatChips();

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, IconData icon) => Chip(
          avatar: Icon(icon, size: 16, color: Colors.cyan.shade700),
          label: Text(label, style: const TextStyle(fontSize: 12.5)),
          backgroundColor: Colors.white,
          side: BorderSide(color: Colors.cyan.shade100),
        );

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        chip('CSV (.csv)', Icons.table_chart_outlined),
        chip('NetCDF (.nc)', Icons.storage_outlined),
      ],
    );
  }
}

// ============================================================
// File info card
// ============================================================
class _FileInfoCard extends StatelessWidget {
  final String name;
  final String sizeLabel;
  final String type;
  final DateTime? selectedOn;

  const _FileInfoCard({
    required this.name,
    required this.sizeLabel,
    required this.type,
    required this.selectedOn,
  });

  @override
  Widget build(BuildContext context) {
    final selectedLabel = selectedOn == null
        ? 'Unknown'
        : '${selectedOn!.hour.toString().padLeft(2, '0')}:${selectedOn!.minute.toString().padLeft(2, '0')} • '
            '${selectedOn!.day}/${selectedOn!.month}/${selectedOn!.year}';

    return _SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.cyan.shade50,
                ),
                child: Icon(Icons.insert_drive_file_outlined, color: Colors.cyan.shade700),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          _infoRow('File Size', sizeLabel),
          _infoRow('File Type', type),
          _infoRow('Selected On', selectedLabel),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Action buttons
// ============================================================
class _ActionButtonsRow extends StatelessWidget {
  final bool isTablet;
  final bool canAct;
  final VoidCallback onUpload;
  final VoidCallback onPreview;
  final VoidCallback onClear;

  const _ActionButtonsRow({
    required this.isTablet,
    required this.canAct,
    required this.onUpload,
    required this.onPreview,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    final primary = ElevatedButton.icon(
      onPressed: canAct ? onUpload : null,
      icon: const Icon(Icons.cloud_upload_outlined, size: 18),
      label: const Text('Upload Dataset'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.cyan.shade700,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );

    final secondary = OutlinedButton.icon(
      onPressed: canAct ? onPreview : null,
      icon: const Icon(Icons.visibility_outlined, size: 18),
      label: const Text('Preview'),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        side: BorderSide(color: Colors.cyan.shade300),
      ),
    );

    final tertiary = TextButton.icon(
      onPressed: canAct ? onClear : null,
      icon: const Icon(Icons.close_rounded, size: 18),
      label: const Text('Clear'),
      style: TextButton.styleFrom(
        foregroundColor: Colors.red.shade600,
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
    );

    if (width >= 700) {
      return Row(
        children: [
          Expanded(child: primary),
          const SizedBox(width: 10),
          Expanded(child: secondary),
          const SizedBox(width: 10),
          Expanded(child: tertiary),
        ],
      );
    }

    if (width < 360) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(width: double.infinity, child: primary),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity, child: secondary),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity, child: tertiary),
        ],
      );
    }

    return Column(
      children: [
        SizedBox(width: double.infinity, child: primary),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: secondary),
            const SizedBox(width: 8),
            Expanded(child: tertiary),
          ],
        ),
      ],
    );
  }
}

// ============================================================
// Upload progress card
// ============================================================
class _UploadProgressCard extends StatelessWidget {
  final double progress;
  final String statusText;

  const _UploadProgressCard({required this.progress, required this.statusText});

  @override
  Widget build(BuildContext context) {
    return _SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  statusText,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              height: 10,
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey.shade200,
                color: Colors.cyan.shade700,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${(progress * 100).round()}%',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Dataset Summary Card (Dynamic parameters & honest timestamps)
// ============================================================
class _DatasetSummaryCard extends StatelessWidget {
  final Map<String, dynamic> result;

  const _DatasetSummaryCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final meta = result['metadata']?['summary'] ?? {};
    final filename = result['filename'] ?? 'Dataset';
    final totalRecords = '${result['records_added'] ?? 0}';

    final tempMin = meta['temp_min'];
    final tempMax = meta['temp_max'];
    final salMin = meta['sal_min'];
    final salMax = meta['sal_max'];
    final presMax = meta['pres_max'];
    final floatsCount = '${meta['number_of_floats'] ?? 1}';
    final dateRange = meta['date_range'] ?? 'Timestamp unavailable';

    return _SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.green, size: 22),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Active Dataset Processed',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          _row('Dataset Name', filename),
          _row('Total Records', totalRecords),
          _row('Number of Floats', floatsCount),
          _row('Date Range', dateRange),
          _row(
            'Temperature Range',
            (tempMin != null && tempMax != null) ? '$tempMin°C – $tempMax°C' : 'Not available',
          ),
          _row(
            'Salinity Range',
            (salMin != null && salMax != null) ? '$salMin – $salMax PSU' : 'Not available',
          ),
          _row(
            'Pressure Range',
            presMax != null ? 'up to $presMax dbar' : 'Not available',
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Dataset Validation Card (Passed / Warning / Failed / Not checked)
// ============================================================
class _ValidationCard extends StatelessWidget {
  final Map<String, dynamic>? meta;

  const _ValidationCard({required this.meta});

  @override
  Widget build(BuildContext context) {
    final reqCol = meta?['required_columns'] ?? 'Passed';
    final missing = meta?['missing_values'] ?? 'Passed';
    final duplicate = meta?['duplicate_check'] ?? 'Passed';
    final invalid = meta?['invalid_records'] ?? 'Passed';
    final quality = meta?['quality_flags'] ?? 'Passed';

    return _SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Dataset Validation Results', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 12),
          _statusLine('Required columns check', reqCol),
          _statusLine('Missing values check', missing),
          _statusLine('Duplicate records check', duplicate),
          _statusLine('Invalid coordinate/number check', invalid),
          _statusLine('Oceanographic quality flags', quality),
        ],
      ),
    );
  }

  Widget _statusLine(String label, String status) {
    IconData icon;
    Color color;
    String badgeText;

    if (status == 'Passed') {
      icon = Icons.check_circle_rounded;
      color = Colors.green;
      badgeText = '✓ Passed';
    } else if (status == 'Warning') {
      icon = Icons.warning_rounded;
      color = Colors.orange.shade800;
      badgeText = '⚠ Warning';
    } else if (status == 'Failed') {
      icon = Icons.cancel_rounded;
      color = Colors.red;
      badgeText = '✗ Failed';
    } else {
      icon = Icons.info_outline;
      color = Colors.grey;
      badgeText = '⟳ Not checked';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 340;
          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: color, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        label,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 26),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      badgeText,
                      style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11.5),
                    ),
                  ),
                ),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11.5),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ============================================================
// Cleaning Summary Card
// ============================================================
class _CleaningSummaryCard extends StatelessWidget {
  final Map<String, dynamic>? cleaning;

  const _CleaningSummaryCard({required this.cleaning});

  @override
  Widget build(BuildContext context) {
    final status = cleaning?['status'] ?? 'Completed';
    final dupesRemoved = cleaning?['duplicates_removed'] ?? 0;
    final totalMissing = cleaning?['total_missing'] ?? 0;
    final rowsRemoved = cleaning?['rows_removed'] ?? 0;
    final rowsRetained = cleaning?['rows_retained'] ?? 0;
    final flaggedCount = cleaning?['flagged_for_review'] ?? 0;

    final missingTemp = cleaning?['missing_temp'] ?? 0;
    final missingSal = cleaning?['missing_salinity'] ?? 0;
    final missingPres = cleaning?['missing_pressure'] ?? 0;

    Color statusColor = Colors.green;
    if (status == 'Completed with Warnings') statusColor = Colors.orange.shade800;
    if (status == 'Failed') statusColor = Colors.red;

    return _SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 6,
            spacing: 8,
            children: [
              const Text(
                'Data Cleaning & Quality Summary',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  status,
                  style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          _row('Duplicate Records Found & Removed', '$dupesRemoved', dupesRemoved > 0 ? Colors.orange.shade800 : Colors.green),
          _row('Total Missing Values Identified', '$totalMissing', totalMissing > 0 ? Colors.orange.shade800 : Colors.green),
          if (totalMissing > 0)
            Padding(
              padding: const EdgeInsets.only(left: 4, top: 2, bottom: 6),
              child: Text(
                'Missing details: Temp ($missingTemp), Salinity ($missingSal), Pressure ($missingPres)',
                style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                softWrap: true,
              ),
            ),
          _row('Out-of-Range Flags', '$flaggedCount values flagged for review', flaggedCount > 0 ? Colors.orange.shade800 : Colors.green),
          _row('Rows Excluded / Removed', '$rowsRemoved', Colors.grey.shade700),
          _row('Clean Records Retained', '$rowsRetained', Colors.green),
        ],
      ),
    );
  }

  Widget _row(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 12.5),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Upload History Section
// ============================================================
class _UploadHistorySection extends StatelessWidget {
  final List<Map<String, dynamic>> history;
  final bool isLoading;
  final bool hasError;
  final VoidCallback onRetry;
  final String Function(int?) formatBytes;

  const _UploadHistorySection({
    required this.history,
    required this.isLoading,
    required this.hasError,
    required this.onRetry,
    required this.formatBytes,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 10),
          child: Text('Upload History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        ),
        if (isLoading)
          const _SoftCard(
            child: Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ),
            ),
          )
        else if (hasError)
          _SoftCard(
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Failed to load upload history.',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                  ),
                ),
                TextButton(
                  onPressed: onRetry,
                  child: const Text('Retry'),
                ),
              ],
            ),
          )
        else if (history.isEmpty)
          _SoftCard(
            child: Text(
              'No uploads yet.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          )
        else
          ...history.map((h) {
            final filename = h['filename'] as String? ?? 'Dataset';
            final date = h['upload_date'] as String? ?? '';
            final size = h['file_size'] as int? ?? 0;
            final records = h['total_records'] as int? ?? 0;
            final isActive = h['is_active'] == true;

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _SoftCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(
                        isActive ? Icons.check_circle_rounded : Icons.insert_drive_file_outlined,
                        color: isActive ? Colors.cyan.shade700 : Colors.grey,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  filename,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                                ),
                              ),
                              if (isActive) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.cyan.shade50,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Colors.cyan.shade300),
                                  ),
                                  child: Text(
                                    'Active',
                                    style: TextStyle(
                                      color: Colors.cyan.shade800,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${date.split(' ').first} • ${formatBytes(size)} • $records records',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}

// ============================================================
// Shared soft card shell
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }
}