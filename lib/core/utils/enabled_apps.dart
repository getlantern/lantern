/// Cached view of user enabled apps split-tunneling selection
class EnabledAppsSnapshot {
  EnabledAppsSnapshot({
    required this.keys,
    required this.names,
  });

  final Set<String> keys; // bundleIds / packageNames
  final Set<String> names; // display names (fallback)

  const EnabledAppsSnapshot.empty()
      : keys = const <String>{},
        names = const <String>{};

  bool contains({required String key, required String name}) {
    return keys.contains(key) || names.contains(name);
  }
}
