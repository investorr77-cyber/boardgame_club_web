import 'package:flutter/foundation.dart';

import '../models/genre.dart';
import '../models/publisher.dart';
import '../repositories/reference_repository.dart';

/// Справочники для экранов: жанры, издатели, страны авторов.
class ReferenceNotifier extends ChangeNotifier {
  ReferenceNotifier(ReferenceRepository repository)
      : genres = repository.genres,
        publishers = repository.publishers,
        countries = repository.designerCountries;

  final List<Genre> genres;
  final List<Publisher> publishers;
  final List<String> countries;

  String genreName(int id) {
    for (final genre in genres) {
      if (genre.id == id) return genre.name;
    }
    return '—';
  }

  String publisherName(int id) {
    for (final publisher in publishers) {
      if (publisher.id == id) return publisher.name;
    }
    return '—';
  }
}
