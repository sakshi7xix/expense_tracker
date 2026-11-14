import 'package:flutter_test/flutter_test.dart';
import 'package:stub/features/friends/friend_sheet.dart';

void main() {
  test('reminder text', () {
    expect(reminderText('Riya', 6000), 'Hi Riya! Just a reminder that you owe me ₹60. Thanks!');
    expect(reminderText('Aman', 6050), 'Hi Aman! Just a reminder that you owe me ₹60.50. Thanks!');
  });
}
