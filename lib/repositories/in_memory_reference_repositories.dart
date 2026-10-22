import '../models/genre.dart';
import '../models/member.dart';
import '../models/publisher.dart';
import '../models/simple_query.dart';
import 'in_memory_crud_repository.dart';
import 'local_store.dart';
import 'reference_repositories.dart';
import 'seed/seed_genres.dart';
import 'seed/seed_members.dart';
import 'seed/seed_publishers.dart';

/// Жанры: память + localStorage.
class InMemoryGenreRepository extends InMemoryCrudRepository<Genre, SimpleQuery>
    implements GenreRepository {
  InMemoryGenreRepository({super.store, super.delay, super.shouldFail})
      : super(seed: () => List.of(seedGenres));

  static const sortFields = ['name'];

  @override
  String get storageKey => LocalStore.key('genres');

  @override
  String get collectionLabel => 'Жанры';

  @override
  String notFound(int id) => 'Жанр с id $id не найден';

  @override
  int idOf(Genre item) => item.id;

  @override
  Genre withId(Genre item, int id) => item.copyWith(id: id);

  @override
  bool isDeletedItem(Genre item) => item.isDeleted;

  @override
  Genre markDeleted(Genre item, DateTime at) => item.copyWith(deletedAt: at);

  @override
  Genre markRestored(Genre item) => item.copyWith(clearDeletedAt: true);

  @override
  Map<String, dynamic> encode(Genre item) => item.toJson();

  @override
  Genre decode(Map<String, dynamic> json) => Genre.fromJson(json);

  @override
  bool matches(Genre g, SimpleQuery query) {
    final search = query.search.trim().toLowerCase();
    return search.isEmpty ||
        g.name.toLowerCase().contains(search) ||
        g.description.toLowerCase().contains(search);
  }

  @override
  int compareBy(Genre a, Genre b, SimpleQuery query) =>
      a.name.toLowerCase().compareTo(b.name.toLowerCase());
}

/// Издатели: память + localStorage. Фильтр — страна.
class InMemoryPublisherRepository
    extends InMemoryCrudRepository<Publisher, SimpleQuery>
    implements PublisherRepository {
  InMemoryPublisherRepository({super.store, super.delay, super.shouldFail})
      : super(seed: () => List.of(seedPublishers));

  static const sortFields = ['name', 'country', 'foundedYear'];

  @override
  String get storageKey => LocalStore.key('publishers');

  @override
  String get collectionLabel => 'Издатели';

  @override
  String notFound(int id) => 'Издатель с id $id не найден';

  @override
  int idOf(Publisher item) => item.id;

  @override
  Publisher withId(Publisher item, int id) => item.copyWith(id: id);

  @override
  bool isDeletedItem(Publisher item) => item.isDeleted;

  @override
  Publisher markDeleted(Publisher item, DateTime at) =>
      item.copyWith(deletedAt: at);

  @override
  Publisher markRestored(Publisher item) => item.copyWith(clearDeletedAt: true);

  @override
  Map<String, dynamic> encode(Publisher item) => item.toJson();

  @override
  Publisher decode(Map<String, dynamic> json) => Publisher.fromJson(json);

  @override
  bool matches(Publisher p, SimpleQuery query) {
    final search = query.search.trim().toLowerCase();
    if (search.isNotEmpty &&
        !p.name.toLowerCase().contains(search) &&
        !p.country.toLowerCase().contains(search)) {
      return false;
    }
    return query.filter == null || p.country == query.filter;
  }

  @override
  int compareBy(Publisher a, Publisher b, SimpleQuery query) =>
      switch (query.sortField) {
        'country' => a.country.compareTo(b.country),
        'foundedYear' => a.foundedYear.compareTo(b.foundedYear),
        _ => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      };
}

/// Участники клуба: память + localStorage. Фильтр — город.
class InMemoryMemberRepository
    extends InMemoryCrudRepository<Member, SimpleQuery>
    implements MemberRepository {
  InMemoryMemberRepository({super.store, super.delay, super.shouldFail})
      : super(seed: () => List.of(seedMembers));

  static const sortFields = ['lastName', 'city', 'email'];

  @override
  String get storageKey => LocalStore.key('members');

  @override
  String get collectionLabel => 'Участники клуба';

  @override
  String notFound(int id) => 'Участник с id $id не найден';

  @override
  int idOf(Member item) => item.id;

  @override
  Member withId(Member item, int id) => item.copyWith(id: id);

  @override
  bool isDeletedItem(Member item) => item.isDeleted;

  @override
  Member markDeleted(Member item, DateTime at) => item.copyWith(deletedAt: at);

  @override
  Member markRestored(Member item) => item.copyWith(clearDeletedAt: true);

  @override
  Map<String, dynamic> encode(Member item) => item.toJson();

  @override
  Member decode(Map<String, dynamic> json) => Member.fromJson(json);

  @override
  bool matches(Member m, SimpleQuery query) {
    final search = query.search.trim().toLowerCase();
    if (search.isNotEmpty &&
        !m.lastName.toLowerCase().contains(search) &&
        !m.email.toLowerCase().contains(search) &&
        !m.card.number.toLowerCase().contains(search)) {
      return false;
    }
    return query.filter == null || m.city == query.filter;
  }

  @override
  int compareBy(Member a, Member b, SimpleQuery query) =>
      switch (query.sortField) {
        'city' => a.city.compareTo(b.city),
        'email' => a.email.compareTo(b.email),
        _ => a.lastName.toLowerCase().compareTo(b.lastName.toLowerCase()),
      };

  @override
  Future<bool> isEmailTaken(String email, {int? exceptId}) async {
    final value = email.trim().toLowerCase();
    return items.any((m) => m.email.toLowerCase() == value && m.id != exceptId);
  }

  @override
  Future<bool> isCardNumberTaken(String number, {int? exceptId}) async {
    final value = number.trim().toUpperCase();
    return items
        .any((m) => m.card.number.toUpperCase() == value && m.id != exceptId);
  }
}
