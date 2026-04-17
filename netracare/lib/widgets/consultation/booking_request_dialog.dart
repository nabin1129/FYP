import 'package:flutter/material.dart';
import 'package:netracare/config/app_theme.dart';
import 'package:netracare/models/consultation/consultation_model.dart';
import 'package:netracare/models/consultation/doctor_model.dart';
import 'package:netracare/models/consultation/doctor_slot_model.dart';
import 'package:netracare/services/consultation_service.dart';
import 'package:netracare/services/doctor_api_service.dart';

typedef LoadDoctorSlots = Future<List<DoctorSlot>> Function(int doctorId);
typedef SubmitBooking = Future<void> Function({
  required int doctorId,
  required ConsultationType type,
  int? doctorSlotId,
});

class BookingRequestDialog extends StatefulWidget {
  final Doctor doctor;
  final VoidCallback? onConsultationRequested;
  final LoadDoctorSlots? loadDoctorSlots;
  final SubmitBooking? submitBooking;

  const BookingRequestDialog({
    super.key,
    required this.doctor,
    this.onConsultationRequested,
    this.loadDoctorSlots,
    this.submitBooking,
  });

  @override
  State<BookingRequestDialog> createState() => _BookingRequestDialogState();
}

class _BookingRequestDialogState extends State<BookingRequestDialog> {
  ConsultationType _selectedType = ConsultationType.videoCall;
  bool _loadingSlots = false;
  bool _submitting = false;
  List<DoctorSlot> _slots = const [];
  DoctorSlot? _selectedSlot;

  @override
  void initState() {
    super.initState();
    _fetchSlots();
  }

  Future<void> _fetchSlots() async {
    setState(() {
      _loadingSlots = true;
    });

    try {
      final slotLoader =
          widget.loadDoctorSlots ??
          (int doctorId) =>
              DoctorApiService.getAvailableDoctorSlots(doctorId: doctorId);
      final slots = await slotLoader(int.parse(widget.doctor.id));
      if (!mounted) return;
      setState(() {
        _slots = slots;
        if (_selectedSlot != null) {
          _selectedSlot = slots.where((s) => s.id == _selectedSlot!.id).isEmpty
              ? null
              : _selectedSlot;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _slots = const [];
        _selectedSlot = null;
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingSlots = false;
        });
      }
    }
  }

  Future<void> _submitBooking() async {
    if (_submitting) {
      return;
    }

    if (_selectedType == ConsultationType.physical && _selectedSlot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please choose a doctor-assigned date and time slot'),
          backgroundColor: AppTheme.warning,
        ),
      );
      return;
    }

    setState(() {
      _submitting = true;
    });

    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final submitter =
          widget.submitBooking ??
          ({required int doctorId, required ConsultationType type, int? doctorSlotId}) {
            final consultationService = ConsultationService();
            return consultationService.bookConsultationAsync(
              doctorId: doctorId,
              type: type,
              doctorSlotId: doctorSlotId,
              reason: type == ConsultationType.physical
                  ? 'Physical consultation booking request'
                  : 'Consultation booking request',
            );
          };

      await submitter(
        doctorId: int.parse(widget.doctor.id),
        type: _selectedType,
        doctorSlotId: _selectedSlot?.id,
      );

      if (!mounted) return;
      nav.pop();
      widget.onConsultationRequested?.call();

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            _selectedType == ConsultationType.physical
                ? 'Physical consultation booked successfully.'
                : 'Booking request sent successfully.',
          ),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Booking failed. Please try again.'),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      ),
      title: const Text(
        'Request Booking',
        style: TextStyle(fontSize: AppTheme.fontXL),
      ),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Doctor: ${widget.doctor.name}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: AppTheme.spaceSM),
              DropdownButtonFormField<ConsultationType>(
                initialValue: _selectedType,
                decoration: const InputDecoration(
                  labelText: 'Consultation Type',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: ConsultationType.videoCall,
                    child: Text('Video Call'),
                  ),
                  DropdownMenuItem(
                    value: ConsultationType.physical,
                    child: Text('Physical Consultation'),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _selectedType = value;
                  });
                },
              ),
              if (_selectedType == ConsultationType.physical) ...[
                const SizedBox(height: AppTheme.spaceMD),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Select Date & Time Assigned by Doctor',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _loadingSlots ? null : _fetchSlots,
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Refresh slots',
                    ),
                  ],
                ),
                if (_loadingSlots)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppTheme.spaceSM),
                    child: LinearProgressIndicator(),
                  ),
                if (!_loadingSlots && _slots.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(AppTheme.spaceSM),
                    decoration: BoxDecoration(
                      color: AppTheme.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                      border: Border.all(
                        color: AppTheme.warning.withValues(alpha: 0.25),
                      ),
                    ),
                    child: const Text(
                      'No assigned slots are available currently. Please try later.',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  ),
                if (_slots.isNotEmpty)
                  DropdownButtonFormField<int>(
                    initialValue: _selectedSlot?.id,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Assigned Slots',
                      border: OutlineInputBorder(),
                    ),
                    items: _slots
                        .map(
                          (slot) => DropdownMenuItem<int>(
                            value: slot.id,
                            child: Text(
                              '${slot.displayDate}  ${slot.displayTime} (UTC)',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (slotId) {
                      DoctorSlot? selected;
                      for (final slot in _slots) {
                        if (slot.id == slotId) {
                          selected = slot;
                          break;
                        }
                      }
                      setState(() {
                        _selectedSlot = selected;
                      });
                    },
                  ),
              ] else ...[
                const SizedBox(height: AppTheme.spaceMD),
                Container(
                  padding: const EdgeInsets.all(AppTheme.spaceSM),
                  decoration: BoxDecoration(
                    color: AppTheme.info.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                    border: Border.all(
                      color: AppTheme.info.withValues(alpha: 0.2),
                    ),
                  ),
                  child: const Text(
                    'Video booking requests need doctor approval before scheduling.',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submitting ? null : _submitBooking,
          child: _submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Confirm Booking'),
        ),
      ],
    );
  }
}
