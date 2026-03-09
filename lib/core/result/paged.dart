class Paged<T> {
  const Paged({
    required this.items,
    this.nextCursor,
  });

  final List<T> items;
  final String? nextCursor;
}

