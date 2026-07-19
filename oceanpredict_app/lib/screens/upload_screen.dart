import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/api_service.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  String? _selectedFileName;
  String? _selectedFilePath;
  bool _isUploading = false;

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['nc'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedFileName = result.files.single.name;
        _selectedFilePath = result.files.single.path;
      });
    }
  }

  Future<void> _uploadFile() async {
    if (_selectedFilePath == null || _selectedFileName == null) return;

    setState(() => _isUploading = true);

    final result = await ApiService.uploadFile(_selectedFilePath!, _selectedFileName!);

    if (!mounted) return;
    setState(() => _isUploading = false);

    if (result['statusCode'] == 201) {
      final body = result['body'];
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Uploaded! ${body['records_added']} records added.'),
          backgroundColor: Colors.green,
        ),
      );
      setState(() {
        _selectedFileName = null;
        _selectedFilePath = null;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['body']['message'] ?? 'Upload failed'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
            InkWell(
              onTap: _pickFile,
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
                      const Text('Tap to select NetCDF (.nc) file'),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (_selectedFileName != null) ...[
              Card(
                child: ListTile(
                  leading: const Icon(Icons.insert_drive_file_outlined),
                  title: Text(_selectedFileName!),
                  subtitle: const Text('Ready to upload'),
                  trailing: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() {
                      _selectedFileName = null;
                      _selectedFilePath = null;
                    }),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _isUploading ? null : _uploadFile,
                icon: _isUploading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.cloud_upload_outlined),
                label: Text(_isUploading ? 'Uploading...' : 'Upload & Process'),
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