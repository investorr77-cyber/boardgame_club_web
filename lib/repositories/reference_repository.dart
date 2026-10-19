import '../models/genre.dart';
import '../models/publisher.dart';
import 'seed/seed_designers.dart';
import 'seed/seed_genres.dart';
import 'seed/seed_publishers.dart';

/// Справочники: жанры, издатели и страны авторов. Константы, без CRUD.
class ReferenceRepository {
  const ReferenceRepository();

  List<Genre> get genres => seedGenres;

  List<Publisher> get publishers => seedPublishers;

  List<String> get designerCountries =>
      {for (final d in seedDesigners) d.country}.toList()..sort();
}
