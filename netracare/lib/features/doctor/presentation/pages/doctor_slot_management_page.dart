import 'package:flutter/material.dart';
import 'package:netracare/config/app_theme.dart';
import 'package:netracare/models/consultation/doctor_slot_model.dart';
import 'package:netracare/services/doctor_api_service.dart';

class DoctorSlotManagementPage extends StatefulWidget {
  const DoctorSlotManagementPage({super.key});

  @override
  State<DoctorSlotManagementPage> createState() =>
      _DoctorSlotManagementPageState();
}

class _DoctorSlotManagementPageState extends State<DoctorSlotManagementPage> {
  bool _loading = true;
  List<DoctorSlot> _slots = const [];

  @override
  void initState() {
    super.initState();
    _loadSlots();
  }

  Future<void> _loadSlots() async {
    setState(() {
      _loading = true;
    });

    try {
      final slots = await DoctorApiService.getDoctorSlots();
      if (!mounted) return;
      setState(() {
        _slots = slots;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load slots: $e'),
          backgroundColor: AppTheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _showCreateOrEditDialog({DoctorSlot? slot}) async {
    final messenger = ScaffoldMessenger.of(context);
    final initialUtc = slot?.slotStartAt.toUtc() ?? DateTime.now().toUtc();
    DateTime selectedDate = DateTime.utc(
      initialUtc.year,
      initialUtc.month,
      initialUtc.day,
    );
    TimeOfDay selectedTime = TimeOfDay(
      hour: initialUtc.hour,
      minute: initialUtc.minute,
    );
    final locationController = TextEditingController(
      text: slot?.location ?? '',
    );
    bool isActive = slot?.isActive ?? true;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(slot == null ? 'Create Slot' : 'Edit Slot'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Date (UTC)'),
                    subtitle: Text(
                      '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}',
                    ),
                    trailing: const Icon(Icons.calendar_month),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate.toLocal(),
                        firstDate: DateTime.now().subtract(
                          const Duration(days: 1),
                        ),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setDialogState(() {
                          selectedDate = DateTime.utc(
                            picked.year,
                            picked.month,
                            picked.day,
                          );
                        });
                      }
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Time (UTC)'),
                    subtitle: Text(
                      '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}',
                    ),
                    trailing: const Icon(Icons.access_time),
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: selectedTime,
                      );
                      if (picked != null) {
                        setDialogState(() {
                          selectedTime = picked;
                        });
                      }
                    },
                  ),
                  TextField(
                    controller: locationController,
                    decoration: const InputDecoration(labelText: 'Location'),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Active'),
                    value: isActive,
                    onChanged: (value) {
                      setDialogState(() {
                        isActive = value;
                      });
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final dt = DateTime.utc(
                    selectedDate.year,
                    selectedDate.month,
                    selectedDate.day,
                    selectedTime.hour,
                    selectedTime.minute,
                  );

                  try {
                    if (slot == null) {
                      await DoctorApiService.createDoctorSlot(
                        slotStartAtUtc: dt,
                        location: locationController.text.trim().isEmpty
                            ? null
                            : locationController.text.trim(),
                        isActive: isActive,
                      );
                    } else {
                      await DoctorApiService.updateDoctorSlot(
                        slotId: slot.id,
                        slotStartAtUtc: dt,
                        location: locationController.text.trim().isEmpty
                            ? null
                            : locationController.text.trim(),
                        isActive: isActive,
                      );
                    }

                    if (!context.mounted) return;
                    Navigator.pop(context, true);
                  } catch (e) {
                    if (!context.mounted) return;
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Failed to save slot: $e'),
                        backgroundColor: AppTheme.error,
                      ),
                    );
                  }
                },
                child: Text(slot == null ? 'Create' : 'Save'),
              ),
            ],
          ),
        );
      },
    );

    // Dispose after the dialog route is fully removed from the tree.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      locationController.dispose();
    });

    if (result == true) {
      await _loadSlots();
    }
  }

  Future<void> _deleteSlot(DoctorSlot slot) async {
    try {
      await DoctorApiService.deleteDoctorSlot(slot.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Slot deleted'),
          backgroundColor: AppTheme.success,
        ),
      );
      await _loadSlots();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete slot: $e'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assigned Physical Slots'),
        actions: [
          IconButton(
            onPressed: _loadSlots,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateOrEditDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Add Slot'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _slots.isEmpty
          ? const Center(
              child: Text(
                'No slots assigned yet. Create doctor-assigned slots for physical consultations.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadSlots,
              child: ListView.builder(
                padding: const EdgeInsets.all(AppTheme.spaceMD),
                itemCount: _slots.length,
                itemBuilder: (context, index) {
                  final slot = _slots[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: AppTheme.spaceSM),
                    child: ListTile(
                      leading: Icon(
                        slot.isBooked
                            ? Icons.event_busy
                            : Icons.event_available_outlined,
                        color: slot.isBooked
                            ? AppTheme.warning
                            : AppTheme.success,
                      ),
                      title: Text(
                        '${slot.displayDate}  ${slot.displayTime} UTC',
                      ),
                      subtitle: Text(
                        '${slot.location != null && slot.location!.isNotEmpty ? slot.location : 'No location set'}',
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) async {
                          if (value == 'edit') {
                            await _showCreateOrEditDialog(slot: slot);
                          } else if (value == 'delete') {
                            await _deleteSlot(slot);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Text('Edit'),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete'),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
