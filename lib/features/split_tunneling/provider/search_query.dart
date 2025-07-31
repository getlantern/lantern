import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'search_query.g.dart';

@riverpod
class SearchQuery extends _$SearchQuery {
  @override
  String build() {
    return "";
  }

  void setQuery(String newQuery) => state = newQuery;
}
