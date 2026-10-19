/// Состояние загрузки списка.
enum LoadStatus { idle, loading, success, error }

/// Состояние загрузки карточки: загрузка, найдено, «не найдено», ошибка.
enum DetailsStatus { idle, loading, found, notFound, error }
