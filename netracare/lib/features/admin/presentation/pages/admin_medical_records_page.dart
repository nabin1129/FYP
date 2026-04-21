import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:netracare/config/app_theme.dart';
import 'package:netracare/features/shared/widgets/record_detail_sheet.dart';
import 'package:netracare/services/admin_service.dart';

class AdminMedicalRecordsPage extends StatefulWidget {
  const AdminMedicalRecordsPage({super.key});

  @override
  State<AdminMedicalRecordsPage> createState() =>
      _AdminMedicalRecordsPageState();
}

class _AdminMedicalRecordsPageState extends State<AdminMedicalRecordsPage> {
  final AdminService _service = AdminService();
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _records = [];
  bool _includeDeleted = false;
  bool _isLoading = true;
  String? _error;
  String _selectedStatus = 'all';
  String _selectedType = 'all';
  int _currentPage = 1;
  int _totalPages = 0;
  int _totalRecords = 0;
  static const int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRecords() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final payload = await _service.getMedicalRecordsPaged(
        includeDeleted: _includeDeleted,
        status: _selectedStatus == 'all' ? null : _selectedStatus,
        recordType: _selectedType == 'all' ? null : _selectedType,
        query: _searchController.text,
        page: _currentPage,
        perPage: _pageSize,
      );
      _records = List<Map<String, dynamic>>.from(
        payload['records'] ?? const [],
      );
      _totalPages = payload['total_pages'] as int? ?? 0;
      _totalRecords = payload['total'] as int? ?? 0;
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteRecord(int recordId) async {
    await _service.deleteMedicalRecord(recordId);
    await _loadRecords();
  }

  Future<void> _restoreRecord(int recordId) async {
    await _service.restoreMedicalRecord(recordId);
    await _loadRecords();
  }

  void _showDetails(Map<String, dynamic> record) {
    RecordDetailSheet.show(context, record);
  }

  /// Opens FilePicker, uploads to backend, returns metadata or null on cancel/failure.
  Future<Map<String, dynamic>?> _pickAndUploadFile(
    BuildContext dialogContext,
  ) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'pdf',
        'jpg',
        'jpeg',
        'png',
        'gif',
        'bmp',
        'tiff',
        'webp',
        'doc',
        'docx',
      ],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final picked = result.files.first;
    final bytes = picked.bytes;
    if (bytes == null) return null;
    try {
      return await _service.uploadRecordFile(
        bytes: bytes,
        fileName: picked.name,
      );
    } catch (e) {
      if (dialogContext.mounted) {
        ScaffoldMessenger.of(dialogContext).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
      return null;
    }
  }

  Future<void> _showCreateDialog() async {
    final formKey = GlobalKey<FormState>();
    final patientIdController = TextEditingController();
    final doctorIdController = TextEditingController();
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    String selectedType = 'scan_report';
    String? attachedFileName;
    String? attachedFileUrl;
    int? attachedFileSize;
    String? attachedMimeType;
    bool isUploading = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setStateDialog) {
            return AlertDialog(
              title: const Text('Create Medical Record'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: patientIdController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Patient ID',
                        ),
                        validator: (value) =>
                            (value == null || value.trim().isEmpty)
                            ? 'Required'
                            : null,
                      ),
                      TextFormField(
                        controller: doctorIdController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Doctor ID',
                        ),
                        validator: (value) =>
                            (value == null || value.trim().isEmpty)
                            ? 'Required'
                            : null,
                      ),
                      DropdownButtonFormField<String>(
                        initialValue: selectedType,
                        decoration: const InputDecoration(
                          labelText: 'Record Type',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'scan_report',
                            child: Text('Scan Report'),
                          ),
                          DropdownMenuItem(
                            value: 'prescription',
                            child: Text('Prescription'),
                          ),
                          DropdownMenuItem(
                            value: 'lab_report',
                            child: Text('Lab Report'),
                          ),
                          DropdownMenuItem(
                            value: 'clinical_note',
                            child: Text('Clinical Note'),
                          ),
                          DropdownMenuItem(
                            value: 'test_result',
                            child: Text('Test Result'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null)
                            setStateDialog(() => selectedType = value);
                        },
                      ),
                      TextFormField(
                        controller: titleController,
                        decoration: const InputDecoration(labelText: 'Title'),
                        validator: (value) =>
                            (value == null || value.trim().isEmpty)
                            ? 'Required'
                            : null,
                      ),
                      TextFormField(
                        controller: descriptionController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                        ),
                        validator: (value) =>
                            (value == null || value.trim().isEmpty)
                            ? 'Required'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      _buildFilePickerTile(
                        fileName: attachedFileName,
                        isUploading: isUploading,
                        onTap: () async {
                          setStateDialog(() => isUploading = true);
                          final meta = await _pickAndUploadFile(dialogContext);
                          setStateDialog(() {
                            isUploading = false;
                            if (meta != null) {
                              attachedFileUrl = meta['file_url'] as String?;
                              attachedFileName = meta['file_name'] as String?;
                              attachedFileSize = meta['file_size'] as int?;
                              attachedMimeType = meta['mime_type'] as String?;
                            }
                          });
                        },
                        onRemove: attachedFileName != null
                            ? () => setStateDialog(() {
                                attachedFileName = null;
                                attachedFileUrl = null;
                                attachedFileSize = null;
                                attachedMimeType = null;
                              })
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isUploading
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          try {
                            await _service.createMedicalRecord({
                              'patient_id': int.tryParse(
                                patientIdController.text.trim(),
                              ),
                              'doctor_id': int.tryParse(
                                doctorIdController.text.trim(),
                              ),
                              'record_type': selectedType,
                              'title': titleController.text.trim(),
                              'description': descriptionController.text.trim(),
                              'category': 'general',
                              if (attachedFileUrl != null)
                                'file_url': attachedFileUrl,
                              if (attachedFileName != null)
                                'file_name': attachedFileName,
                              if (attachedFileSize != null)
                                'file_size': attachedFileSize,
                              if (attachedMimeType != null)
                                'mime_type': attachedMimeType,
                            });
                            if (!mounted) return;
                            Navigator.of(context).pop();
                            await _loadRecords();
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(e.toString())),
                            );
                          }
                        },
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showEditDialog(Map<String, dynamic> record) async {
    final recordId = int.tryParse(record['id']?.toString() ?? '');
    if (recordId == null) return;

    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController(
      text: record['title']?.toString() ?? '',
    );
    final descriptionController = TextEditingController(
      text: record['description']?.toString() ?? '',
    );
    String status = record['status']?.toString() ?? 'active';
    String? attachedFileName =
        record['file_name']?.toString() ?? record['fileName']?.toString();
    String? attachedFileUrl = record['file_url']?.toString();
    int? attachedFileSize = record['file_size'] as int?;
    String? attachedMimeType = record['mime_type']?.toString();
    bool isUploading = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setStateDialog) {
            return AlertDialog(
              title: const Text('Edit Medical Record'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: titleController,
                        decoration: const InputDecoration(labelText: 'Title'),
                        validator: (value) =>
                            (value == null || value.trim().isEmpty)
                            ? 'Required'
                            : null,
                      ),
                      TextFormField(
                        controller: descriptionController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                        ),
                        validator: (value) =>
                            (value == null || value.trim().isEmpty)
                            ? 'Required'
                            : null,
                      ),
                      DropdownButtonFormField<String>(
                        initialValue: status,
                        decoration: const InputDecoration(labelText: 'Status'),
                        items: const [
                          DropdownMenuItem(
                            value: 'active',
                            child: Text('Active'),
                          ),
                          DropdownMenuItem(
                            value: 'archived',
                            child: Text('Archived'),
                          ),
                          DropdownMenuItem(
                            value: 'deleted',
                            child: Text('Deleted'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null)
                            setStateDialog(() => status = value);
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildFilePickerTile(
                        fileName: attachedFileName,
                        isUploading: isUploading,
                        onTap: () async {
                          setStateDialog(() => isUploading = true);
                          final meta = await _pickAndUploadFile(dialogContext);
                          setStateDialog(() {
                            isUploading = false;
                            if (meta != null) {
                              attachedFileUrl = meta['file_url'] as String?;
                              attachedFileName = meta['file_name'] as String?;
                              attachedFileSize = meta['file_size'] as int?;
                              attachedMimeType = meta['mime_type'] as String?;
                            }
                          });
                        },
                        onRemove: attachedFileName != null
                            ? () => setStateDialog(() {
                                attachedFileName = null;
                                attachedFileUrl = null;
                                attachedFileSize = null;
                                attachedMimeType = null;
                              })
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isUploading
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          try {
                            await _service.updateMedicalRecord(recordId, {
                              'title': titleController.text.trim(),
                              'description': descriptionController.text.trim(),
                              'status': status,
                              if (attachedFileUrl != null)
                                'file_url': attachedFileUrl,
                              if (attachedFileName != null)
                                'file_name': attachedFileName,
                              if (attachedFileSize != null)
                                'file_size': attachedFileSize,
                              if (attachedMimeType != null)
                                'mime_type': attachedMimeType,
                            });
                            if (!mounted) return;
                            Navigator.of(context).pop();
                            await _loadRecords();
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(e.toString())),
                            );
                          }
                        },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showReassignDialog(Map<String, dynamic> record) async {
    final recordId = int.tryParse(record['id']?.toString() ?? '');
    if (recordId == null) return;

    final doctorIdController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Reassign Doctor'),
          content: TextField(
            controller: doctorIdController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'New Doctor ID'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final doctorId = int.tryParse(doctorIdController.text.trim());
                if (doctorId == null) return;
                try {
                  await _service.reassignMedicalRecord(
                    recordId: recordId,
                    doctorId: doctorId,
                  );
                  if (!mounted) return;
                  Navigator.of(this.context).pop();
                  await _loadRecords();
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(
                    this.context,
                  ).showSnackBar(SnackBar(content: Text(e.toString())));
                }
              },
              child: const Text('Reassign'),
            ),
          ],
        );
      },
    );
  }

  /// Reusable file attachment row used in both create and edit dialogs.
  Widget _buildFilePickerTile({
    required String? fileName,
    required bool isUploading,
    required VoidCallback onTap,
    VoidCallback? onRemove,
  }) {
    return InkWell(
      onTap: isUploading ? null : onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(
            color: fileName != null
                ? AppTheme.success.withValues(alpha: 0.5)
                : AppTheme.border,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: isUploading
            ? const Row(
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 10),
                  Text('Uploading...', style: TextStyle(fontSize: 13)),
                ],
              )
            : Row(
                children: [
                  Icon(
                    fileName != null
                        ? Icons.attach_file
                        : Icons.cloud_upload_outlined,
                    size: 20,
                    color: fileName != null
                        ? AppTheme.success
                        : AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      fileName ?? 'Attach file (PDF, JPG, PNG…)',
                      style: TextStyle(
                        fontSize: 13,
                        color: fileName != null
                            ? AppTheme.textPrimary
                            : AppTheme.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (onRemove != null)
                    IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: onRemove,
                      color: AppTheme.error,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                ],
              ),
      ),
    );
  }

  Color _typeColor(String type) {
    switch (type.toLowerCase()) {
      case 'clinical_note':
        return const Color(0xFF8B5CF6);
      case 'test_result':
        return const Color(0xFF10B981);
      case 'prescription':
        return AppTheme.success;
      case 'lab_report':
        return const Color(0xFF06B6D4);
      default:
        return AppTheme.info;
    }
  }

  IconData _typeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'clinical_note':
        return Icons.assignment;
      case 'test_result':
        return Icons.science_outlined;
      case 'prescription':
        return Icons.medication;
      case 'lab_report':
        return Icons.biotech;
      default:
        return Icons.document_scanner;
    }
  }

  String? _resolveDetailLabel(Map<String, dynamic> record) {
    final source = (record['source'] ?? '').toString().toLowerCase();
    final category = (record['category'] ?? '').toString().toLowerCase();
    final type = (record['record_type'] ?? '').toString().toLowerCase();

    if (source == 'doctor_consultation') {
      if (category == 'diagnosis') return 'Diagnosis';
      if (type == 'prescription') return 'Prescription';
      return 'Consultation Note';
    }

    if (type == 'clinical_note') return 'Clinical Note';
    if (type == 'test_result') return 'Test Result';
    return null;
  }

  String _resolveSourceLabel(Map<String, dynamic> record) {
    final source = (record['source'] ?? '').toString().toLowerCase();
    if (source.startsWith('doctor')) return 'Doctor';
    if (source.startsWith('admin')) return 'Admin';
    return 'Patient';
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        title: const Text(
          'Medical Records',
          style: TextStyle(color: AppTheme.textPrimary),
        ),
        iconTheme: const IconThemeData(color: AppTheme.textPrimary),
        actions: [
          Row(
            children: [
              const Text(
                'Deleted',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
              Switch(
                value: _includeDeleted,
                onChanged: (value) {
                  setState(() {
                    _includeDeleted = value;
                    _currentPage = 1;
                  });
                  _loadRecords();
                },
              ),
            ],
          ),
          IconButton(onPressed: _loadRecords, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : RefreshIndicator(
              onRefresh: _loadRecords,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildFilterSection(),
                  const SizedBox(height: 12),
                  Text(
                    '$_totalRecords record(s) found',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._records.map((record) {
                    final type =
                        record['record_type']?.toString() ?? 'scan_report';
                    final title =
                        record['title']?.toString() ?? 'Medical Record';
                    final patientName =
                        record['patientName']?.toString() ?? 'Unknown patient';
                    final status = record['status']?.toString() ?? 'active';
                    final detailLabel = _resolveDetailLabel(record);
                    final sourceLabel = _resolveSourceLabel(record);
                    final typeColor = _typeColor(type);
                    final recordId = int.tryParse(
                      record['id']?.toString() ?? '',
                    );

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ListTile(
                          onTap: () => _showDetails(record),
                          leading: CircleAvatar(
                            backgroundColor: typeColor.withValues(alpha: 0.12),
                            child: Icon(_typeIcon(type), color: typeColor),
                          ),
                          title: Text(title),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('$patientName • $status'),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  _buildBadge(
                                    sourceLabel,
                                    const Color(0xFF0EA5E9),
                                  ),
                                  _buildBadge(
                                    type.replaceAll('_', ' ').toUpperCase(),
                                    typeColor,
                                  ),
                                  if (detailLabel != null)
                                    _buildBadge(
                                      detailLabel,
                                      const Color(0xFF6366F1),
                                    ),
                                ],
                              ),
                            ],
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) async {
                              if (recordId == null) return;
                              if (value == 'view') {
                                _showDetails(record);
                                return;
                              }
                              if (value == 'edit') {
                                await _showEditDialog(record);
                                return;
                              }
                              if (value == 'reassign') {
                                await _showReassignDialog(record);
                                return;
                              }
                              if (value == 'delete') {
                                await _deleteRecord(recordId);
                              }
                              if (value == 'restore') {
                                await _restoreRecord(recordId);
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'view',
                                child: Text('View details'),
                              ),
                              const PopupMenuItem(
                                value: 'edit',
                                child: Text('Edit'),
                              ),
                              const PopupMenuItem(
                                value: 'reassign',
                                child: Text('Reassign doctor'),
                              ),
                              if (status != 'deleted')
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Delete'),
                                ),
                              if (status == 'deleted')
                                const PopupMenuItem(
                                  value: 'restore',
                                  child: Text('Restore'),
                                ),
                            ],
                            icon: const Icon(Icons.more_vert),
                          ),
                        ),
                      ),
                    );
                  }),
                  _buildPaginationBar(),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateDialog,
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.add),
        label: const Text('Create'),
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by title, description, doctor, patient',
              suffixIcon: IconButton(
                icon: const Icon(Icons.search),
                onPressed: () {
                  setState(() => _currentPage = 1);
                  _loadRecords();
                },
              ),
            ),
            onSubmitted: (_) {
              setState(() => _currentPage = 1);
              _loadRecords();
            },
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedStatus,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Statuses')),
                    DropdownMenuItem(value: 'active', child: Text('Active')),
                    DropdownMenuItem(
                      value: 'archived',
                      child: Text('Archived'),
                    ),
                    DropdownMenuItem(value: 'deleted', child: Text('Deleted')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _selectedStatus = value;
                      _currentPage = 1;
                    });
                    _loadRecords();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedType,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Types')),
                    DropdownMenuItem(
                      value: 'scan_report',
                      child: Text('Scan Report'),
                    ),
                    DropdownMenuItem(
                      value: 'prescription',
                      child: Text('Prescription'),
                    ),
                    DropdownMenuItem(
                      value: 'lab_report',
                      child: Text('Lab Report'),
                    ),
                    DropdownMenuItem(
                      value: 'clinical_note',
                      child: Text('Clinical Note'),
                    ),
                    DropdownMenuItem(
                      value: 'test_result',
                      child: Text('Test Result'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _selectedType = value;
                      _currentPage = 1;
                    });
                    _loadRecords();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaginationBar() {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            _totalPages == 0
                ? 'Page 0 of 0'
                : 'Page $_currentPage of $_totalPages',
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
          Row(
            children: [
              IconButton(
                onPressed: (_currentPage > 1)
                    ? () {
                        setState(() => _currentPage -= 1);
                        _loadRecords();
                      }
                    : null,
                icon: const Icon(Icons.chevron_left),
              ),
              IconButton(
                onPressed: (_totalPages > 0 && _currentPage < _totalPages)
                    ? () {
                        setState(() => _currentPage += 1);
                        _loadRecords();
                      }
                    : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
