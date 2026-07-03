/// Returns [items] with entries whose key (per [keyOf]) appears in [order]
/// placed first, in [order]'s sequence, followed by the remaining items in
/// their original relative order.
///
/// Used to apply a user-defined drag-to-reorder sequence (persisted as a
/// `List<String>` of names/ids) to a list of tags, tag names, or books.
List<T> sortByStoredOrder<T>(
  Iterable<T> items,
  List<String> order,
  String Function(T) keyOf,
) {
  final byKey = {for (final item in items) keyOf(item): item};
  return [
    for (final key in order)
      if (byKey.containsKey(key)) byKey[key]!,
    for (final item in items)
      if (!order.contains(keyOf(item))) item,
  ];
}
