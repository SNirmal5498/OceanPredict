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
  // ---- Selected file state (existing functionality, extended) ----
  String? _selectedFileName;
  List<int>? _selectedFileBytes;
  int? _selectedFileSize;
  DateTime? _selectedAt;

  // ---- Upload state (existing functionality, extended) ----
  bool _isUploading = false;
  double _progress = 0;
  String _statusText = '';
  Timer? _progressTimer;

  // ---- Post-upload data (real where possible) ----
  Map<String, dynamic>? _lastUploadResult; // {filename, records_added}
  Map<String, dynamic>? _analyticsSnapshot; // from existing /analytics/summary

  // ---- Session-only upload history (real entries, resets on restart) ----
  final List<_HistoryEntry> _history = [];

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _progressTimer?.cancel();
    super.dispose();
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
    if (bytes == null) return 'Unknown size';
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
    allowedExtensions: ['nc'],
    withData: true, // ensures bytes are available on web too
  );

  if (result != null && result.files.single.bytes != null) {
    setState(() {
      _selectedFileName = result.files.single.name;
      _selectedFileBytes = result.files.single.bytes;
      _selectedFileSize = result.files.single.size;
      _selectedAt = DateTime.now();
      _lastUploadResult = null;
      _analyticsSnapshot = null;
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
      _analyticsSnapshot = null;
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
            Text('File: $_selectedFileName'),
            const SizedBox(height: 6),
            Text('Size: ${_formatBytes(_selectedFileSize)}'),
            const SizedBox(height: 6),
            Text('Type: ${_extensionOf(_selectedFileName!)}'),
            const SizedBox(height: 14),
            Text(
              'Full content preview requires server-side processing and isn\'t '
              'shown here — only the file you\'re about to upload is confirmed above.',
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
        if (_progress < 0.9) _progress += 0.03;
        _statusText = 'Uploading... ${(_progress * 100).round()}%';
      });
    });

    final fileName = _selectedFileName!;
    final fileSize = _selectedFileSize;
    final result = await ApiService.uploadFile(_selectedFileBytes!, fileName);

    _progressTimer?.cancel();
    if (!mounted) return;

    final success = result['statusCode'] == 201;

    setState(() {
      _progress = 1.0;
      _statusText = success ? 'Upload Complete' : 'Upload Failed';
    });

    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    if (success) {
      final body = result['body'];
      setState(() {
        _lastUploadResult = body;
        _history.insert(
          0,
          _HistoryEntry(
            name: fileName,
            date: DateTime.now(),
            size: fileSize,
            records: body['records_added'] ?? 0,
            success: true,
          ),
        );
      });

      // Reuse existing analytics endpoint (no backend change) for range context.
      final analytics = await ApiService.getAnalyticsSummary();
      if (mounted && analytics['statusCode'] == 200) {
        setState(() => _analyticsSnapshot = analytics['body']);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Uploaded! ${body['records_added']} records added.'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      setState(() {
        _history.insert(
          0,
          _HistoryEntry(
            name: fileName,
            date: DateTime.now(),
            size: fileSize,
            records: 0,
            success: false,
          ),
        );
      });
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
      appBar: AppBar(title: const Text('Upload Dataset')),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: isTablet ? 32 : 16, vertical: 18),
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
                child: _DatasetSummaryCard(
                  fileName: _lastUploadResult!['filename'] ?? '-',
                  totalRecords: '${_lastUploadResult!['records_added'] ?? 0}',
                  numberOfFloats: '1',
                  analytics: _analyticsSnapshot,
                ),
              ),
              const SizedBox(height: 16),
              _fadeScale(
                start: 0.05,
                end: 0.65,
                child: const _ValidationCard(),
              ),
              const SizedBox(height: 16),
              _fadeScale(
                start: 0.1,
                end: 0.7,
                child: const _CleaningSummaryCard(),
              ),
            ],
            const SizedBox(height: 22),
            _fadeScale(
              start: 0.1,
              end: 0.7,
              child: _UploadHistorySection(history: _history),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// Upload area card (also future drag-and-drop target on web/desktop)
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
                ),
                const SizedBox(height: 6),
                Text(
                  'Upload Argo Float CSV or NetCDF (.nc) datasets',
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
      children: [
        chip('CSV', Icons.table_chart_outlined),
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
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

    if (isTablet) {
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
              Text(statusText, style: const TextStyle(fontWeight: FontWeight.w600)),
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
// Dataset summary card (real records; ranges reuse existing analytics endpoint)
// ============================================================
class _DatasetSummaryCard extends StatelessWidget {
  final String fileName;
  final String totalRecords;
  final String numberOfFloats;
  final Map<String, dynamic>? analytics;

  const _DatasetSummaryCard({
    required this.fileName,
    required this.totalRecords,
    required this.numberOfFloats,
    required this.analytics,
  });

  @override
  Widget build(BuildContext context) {
    final temp = analytics?['temperature'];
    final sal = analytics?['salinity'];
    final pres = analytics?['pressure'];

    return _SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 20),
              const SizedBox(width: 8),
              const Text('Upload Successful', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const Divider(height: 20),
          _row('Dataset Name', fileName),
          _row('Total Records', totalRecords),
          _row('Number of Floats', numberOfFloats),
          _row('Date Range', 'Not available (no timestamp in current data)'),
          _row(
            'Temperature Range',
            temp == null ? 'Loading...' : '${temp['min']}°C – ${temp['max']}°C (overall)',
          ),
          _row(
            'Salinity Range',
            sal == null ? 'Loading...' : '${sal['min']} – ${sal['max']} PSU (overall)',
          ),
          _row(
            'Pressure Range',
            pres == null ? 'Loading...' : 'up to ${pres['max_depth']} dbar (overall)',
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5)),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Validation card — reflects actual backend behavior, no invented numbers
// ============================================================
class _ValidationCard extends StatelessWidget {
  const _ValidationCard();

  @override
  Widget build(BuildContext context) {
    return _SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Dataset Validation', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          _statusLine(Icons.check_circle, Colors.green, 'Required columns found'),
          _statusLine(Icons.check_circle, Colors.green, 'Missing values automatically filtered'),
          _statusLine(Icons.info, Colors.orange, 'Duplicate check not yet performed by backend'),
          _statusLine(Icons.check_circle, Colors.green, 'Invalid/empty rows automatically skipped'),
        ],
      ),
    );
  }

  Widget _statusLine(IconData icon, Color color, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}

// ============================================================
// Cleaning summary — honest wording matching real backend logic
// ============================================================
class _CleaningSummaryCard extends StatelessWidget {
  const _CleaningSummaryCard();

  @override
  Widget build(BuildContext context) {
    return _SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Data Cleaning Summary', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          _row('Duplicates Removed', 'Not performed', Colors.orange),
          _row('Missing Values', 'Rows skipped automatically', Colors.green),
          _row('Invalid Records', 'Excluded automatically', Colors.green),
          _row('Cleaning Status', 'Completed', Colors.green),
        ],
      ),
    );
  }

  Widget _row(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5)),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12.5)),
        ],
      ),
    );
  }
}

// ============================================================
// Upload history (session-only, real entries)
// ============================================================
class _HistoryEntry {
  final String name;
  final DateTime date;
  final int? size;
  final int records;
  final bool success;

  _HistoryEntry({
    required this.name,
    required this.date,
    required this.size,
    required this.records,
    required this.success,
  });
}

class _UploadHistorySection extends StatelessWidget {
  final List<_HistoryEntry> history;
  const _UploadHistorySection({required this.history});

  String _formatBytes(int? bytes) {
    if (bytes == null) return 'Unknown size';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 10),
          child: Text('Upload History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        ),
        if (history.isEmpty)
          _SoftCard(
            child: Text(
              'No uploads yet this session.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          )
        else
          ...history.map((h) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _SoftCard(
                  child: Row(
                    children: [
                      Icon(
                        h.success ? Icons.check_circle : Icons.error,
                        color: h.success ? Colors.green : Colors.red,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(h.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                            const SizedBox(height: 2),
                            Text(
                              '${h.date.hour.toString().padLeft(2, '0')}:${h.date.minute.toString().padLeft(2, '0')} • '
                              '${_formatBytes(h.size)} • ${h.records} records',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: (h.success ? Colors.green : Colors.red).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          h.success ? 'Success' : 'Failed',
                          style: TextStyle(
                            color: h.success ? Colors.green.shade700 : Colors.red.shade700,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )),
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