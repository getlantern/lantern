class ServerLocation {
  final String code;

  final String label;
  const ServerLocation({required this.code, required this.label});
}

// TEST data
final locations = [
  ServerLocation(code: 'AU', label: 'australia_sydney'),
  ServerLocation(code: 'US', label: 'us_los_angeles'),
  ServerLocation(code: 'JP', label: 'japan_tokyo'),
];
