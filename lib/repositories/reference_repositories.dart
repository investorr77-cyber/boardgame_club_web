import '../models/genre.dart';
import '../models/member.dart';
import '../models/publisher.dart';
import '../models/simple_query.dart';
import 'crud_repository.dart';

/// Источник данных о жанрах.
abstract interface class GenreRepository
    implements CrudRepository<Genre, SimpleQuery> {}

/// Источник данных об издателях.
abstract interface class PublisherRepository
    implements CrudRepository<Publisher, SimpleQuery> {}

/// Источник данных об участниках клуба.
abstract interface class MemberRepository
    implements CrudRepository<Member, SimpleQuery> {
  /// Почта уже занята другим участником.
  Future<bool> isEmailTaken(String email, {int? exceptId});

  /// Номер клубной карты уже занят.
  Future<bool> isCardNumberTaken(String number, {int? exceptId});
}
