import '../models/designer.dart';
import '../models/designer_query.dart';
import 'crud_repository.dart';

/// Источник данных об авторах.
abstract interface class DesignerRepository
    implements CrudRepository<Designer, DesignerQuery> {}
