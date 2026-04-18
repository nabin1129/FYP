import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:netracare/models/consultation/consultation_model.dart';
import 'package:netracare/models/consultation/doctor_model.dart';
import 'package:netracare/models/consultation/doctor_slot_model.dart';
import 'package:netracare/widgets/consultation/booking_request_dialog.dart';

Doctor _buildDoctor() {
  return const Doctor(
    id: '1',
    name: 'Dr. Test Doctor',
    qualification: 'MBBS',
    specialization: 'Ophthalmology',
    image: '',
    rating: 4.9,
    experience: '10 years',
    workingPlace: 'Test Clinic',
    address: 'Test Address',
    nhpcNumber: 'NHPC-TEST-1',
    contactPhone: '+9779800000000',
    contactEmail: 'doctor@test.com',
    availability: 'Available Today',
    nextSlot: '10:00 AM',
  );
}

void main() {
  group('BookingRequestDialog', () {
    testWidgets(
      'blocks physical booking when no assigned slot is selected',
      (tester) async {
        int submitCalls = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: BookingRequestDialog(
                doctor: _buildDoctor(),
                loadDoctorSlots: (_) async => const [],
                submitBooking: ({
                  required int doctorId,
                  required ConsultationType type,
                  int? doctorSlotId,
                }) async {
                  submitCalls += 1;
                },
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        await tester.tap(find.byType(DropdownButtonFormField<ConsultationType>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Physical Consultation').last);
        await tester.pumpAndSettle();

        await tester.tap(find.text('Confirm Booking'));
        await tester.pumpAndSettle();

        expect(
          find.text('Please choose a doctor-assigned date and time slot'),
          findsOneWidget,
        );
        expect(submitCalls, 0);
      },
    );

    testWidgets('submits physical booking with selected slot', (tester) async {
      final selected = <String, dynamic>{};
      final slots = [
        DoctorSlot(
          id: 100,
          doctorId: 1,
          slotStartAt: DateTime.utc(2026, 5, 20, 9, 0),
          location: 'Test Clinic',
          isActive: true,
          isBooked: false,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BookingRequestDialog(
              doctor: _buildDoctor(),
              loadDoctorSlots: (_) async => slots,
              submitBooking: ({
                required int doctorId,
                required ConsultationType type,
                int? doctorSlotId,
              }) async {
                selected['doctorId'] = doctorId;
                selected['type'] = type;
                selected['doctorSlotId'] = doctorSlotId;
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<ConsultationType>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Physical Consultation').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('UTC').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Confirm Booking'));
      await tester.pumpAndSettle();

      expect(selected['doctorId'], 1);
      expect(selected['type'], ConsultationType.physical);
      expect(selected['doctorSlotId'], 100);
    });
  });
}
