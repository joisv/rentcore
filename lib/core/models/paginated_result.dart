class PaginatedResult<T> {
  final List<T> items;
  final int currentPage;
  final int lastPage;
  final int total;
  final int perPage;
  final bool hasMore;

  const PaginatedResult({
    required this.items,
    this.currentPage = 1,
    this.lastPage = 1,
    this.total = 0,
    this.perPage = 20,
    this.hasMore = false,
  });

  PaginatedResult<T> copyWith({
    List<T>? items,
    int? currentPage,
    int? lastPage,
    int? total,
    int? perPage,
    bool? hasMore,
  }) {
    return PaginatedResult<T>(
      items: items ?? this.items,
      currentPage: currentPage ?? this.currentPage,
      lastPage: lastPage ?? this.lastPage,
      total: total ?? this.total,
      perPage: perPage ?? this.perPage,
      hasMore: hasMore ?? this.hasMore,
    );
  }

  factory PaginatedResult.empty() => const PaginatedResult(
        items: [],
        currentPage: 1,
        lastPage: 1,
        total: 0,
        perPage: 20,
        hasMore: false,
      );
}
