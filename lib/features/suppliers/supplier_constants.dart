/// Indian States and GST State Codes
class IndianState {
  final String code;
  final String name;
  const IndianState(this.code, this.name);
}

const indianStates = <IndianState>[
  IndianState('01', 'Jammu and Kashmir'),
  IndianState('02', 'Himachal Pradesh'),
  IndianState('03', 'Punjab'),
  IndianState('04', 'Chandigarh'),
  IndianState('05', 'Uttarakhand'),
  IndianState('06', 'Haryana'),
  IndianState('07', 'Delhi'),
  IndianState('08', 'Rajasthan'),
  IndianState('09', 'Uttar Pradesh'),
  IndianState('10', 'Bihar'),
  IndianState('11', 'Sikkim'),
  IndianState('12', 'Arunachal Pradesh'),
  IndianState('13', 'Nagaland'),
  IndianState('14', 'Manipur'),
  IndianState('15', 'Mizoram'),
  IndianState('16', 'Tripura'),
  IndianState('17', 'Meghalaya'),
  IndianState('18', 'Assam'),
  IndianState('19', 'West Bengal'),
  IndianState('20', 'Jharkhand'),
  IndianState('21', 'Odisha'),
  IndianState('22', 'Chhattisgarh'),
  IndianState('23', 'Madhya Pradesh'),
  IndianState('24', 'Gujarat'),
  IndianState('26', 'Dadra and Nagar Haveli and Daman and Diu'),
  IndianState('27', 'Maharashtra'),
  IndianState('28', 'Andhra Pradesh (Old)'),
  IndianState('29', 'Karnataka'),
  IndianState('30', 'Goa'),
  IndianState('31', 'Lakshadweep'),
  IndianState('32', 'Kerala'),
  IndianState('33', 'Tamil Nadu'),
  IndianState('34', 'Puducherry'),
  IndianState('35', 'Andaman and Nicobar Islands'),
  IndianState('36', 'Telangana'),
  IndianState('37', 'Andhra Pradesh'),
  IndianState('38', 'Ladakh'),
];

/// Auto-detect state name from the first two digits of a GSTIN.
String? stateFromGstin(String gstin) {
  final clean = gstin.trim();
  if (clean.length < 2) return null;
  final code = clean.substring(0, 2);
  final match = indianStates.where((s) => s.code == code).firstOrNull;
  return match?.name;
}

/// Standard GSTIN validation: 15 alphanumeric characters:
/// 2 digits (state) + 10 chars (PAN) + 1 char (entity number) + 'Z' + 1 checksum char
bool isValidGstin(String gstin) {
  final clean = gstin.trim().toUpperCase();
  if (clean.isEmpty) return true; // optional
  final regex = RegExp(
    r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$',
  );
  return regex.hasMatch(clean);
}

/// Validates 10-digit Indian phone numbers
bool isValidPhone(String phone) {
  final clean = phone.replaceAll(RegExp(r'\D'), '');
  if (clean.length == 10) {
    return RegExp(r'^[6-9]\d{9}$').hasMatch(clean);
  } else if (clean.length == 12 && clean.startsWith('91')) {
    return RegExp(r'^91[6-9]\d{9}$').hasMatch(clean);
  }
  return clean.isNotEmpty;
}

