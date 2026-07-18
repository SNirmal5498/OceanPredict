import 'package:flutter/material.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  String? _selectedFileName;

  void _pickFile() {
    // Placeholder for now — real file picking (file_picker package) comes later
    setState(() {
      _selectedFileName = 'argo_sample_data.csv';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upload Dataset')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DottedBorderBox(
              onTap: _pickFile,
              fileName: _selectedFileName,
            ),
            const SizedBox(height: 24),
            if (_selectedFileName != null) ...[
              Card(
                child: ListTile(
                  leading: const Icon(Icons.insert_drive_file_outlined),
                  title: Text(_selectedFileName!),
                  subtitle: const Text('Ready to upload • 1,240 records detected'),
                  trailing: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => _selectedFileName = null),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Upload started (placeholder)')),
                  );
                },
                icon: const Icon(Icons.cloud_upload_outlined),
                label: const Text('Upload & Process'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyan.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class DottedBorderBox extends StatelessWidget {
  final VoidCallback onTap;
  final String? fileName;

  const DottedBorderBox({super.key, required this.onTap, this.fileName});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.cyan.shade200, width: 2),
          borderRadius: BorderRadius.circular(12),
          color: Colors.cyan.shade50,
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.upload_file, size: 48, color: Colors.cyan.shade700),
              const SizedBox(height: 12),
              const Text('Tap to select CSV file'),
            ],
          ),
        ),
      ),
    );
  }
}