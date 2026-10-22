import '../../models/member.dart';

/// 12 участников клуба, у каждого — клубная карта (связь один к одному).
const seedMembers = <Member>[
  Member(id: 1, lastName: 'Иванов', firstName: 'Алексей', email: 'alexey.ivanov@example.com', phone: '+79001000001', city: 'Москва', card: MemberCard(number: 'BG-000101', issuedYear: 2021, maxGames: 3)),
  Member(id: 2, lastName: 'Смирнова', firstName: 'Мария', email: 'maria.smirnova@example.com', phone: '+79001000002', city: 'Москва', card: MemberCard(number: 'BG-000102', issuedYear: 2022, maxGames: 2)),
  Member(id: 3, lastName: 'Кузнецов', firstName: 'Дмитрий', email: 'dmitry.kuznetsov@example.com', phone: '+79001000003', city: 'Санкт-Петербург', card: MemberCard(number: 'BG-000103', issuedYear: 2020, maxGames: 5)),
  Member(id: 4, lastName: 'Попова', firstName: 'Анна', email: 'anna.popova@example.com', phone: '+79001000004', city: 'Казань', card: MemberCard(number: 'BG-000104', issuedYear: 2023, maxGames: 2)),
  Member(id: 5, lastName: 'Соколов', firstName: 'Иван', email: 'ivan.sokolov@example.com', phone: '+79001000005', city: 'Москва', card: MemberCard(number: 'BG-000105', issuedYear: 2019, maxGames: 4)),
  Member(id: 6, lastName: 'Лебедева', firstName: 'Екатерина', email: 'ekaterina.lebedeva@example.com', phone: '+79001000006', city: 'Санкт-Петербург', card: MemberCard(number: 'BG-000106', issuedYear: 2024, maxGames: 1)),
  Member(id: 7, lastName: 'Козлов', firstName: 'Никита', email: 'nikita.kozlov@example.com', phone: '+79001000007', city: 'Новосибирск', card: MemberCard(number: 'BG-000107', issuedYear: 2021, maxGames: 3)),
  Member(id: 8, lastName: 'Новикова', firstName: 'Ольга', email: 'olga.novikova@example.com', phone: '+79001000008', city: 'Казань', card: MemberCard(number: 'BG-000108', issuedYear: 2022, maxGames: 2)),
  Member(id: 9, lastName: 'Морозов', firstName: 'Сергей', email: 'sergey.morozov@example.com', phone: '+79001000009', city: 'Москва', card: MemberCard(number: 'BG-000109', issuedYear: 2020, maxGames: 3)),
  Member(id: 10, lastName: 'Волкова', firstName: 'Дарья', email: 'darya.volkova@example.com', phone: '+79001000010', city: 'Екатеринбург', card: MemberCard(number: 'BG-000110', issuedYear: 2023, maxGames: 2)),
  Member(id: 11, lastName: 'Фёдоров', firstName: 'Павел', email: 'pavel.fedorov@example.com', phone: '+79001000011', city: 'Новосибирск', card: MemberCard(number: 'BG-000111', issuedYear: 2024, maxGames: 1)),
  Member(id: 12, lastName: 'Михайлова', firstName: 'Полина', email: 'polina.mikhailova@example.com', phone: '+79001000012', city: 'Екатеринбург', card: MemberCard(number: 'BG-000112', issuedYear: 2022, maxGames: 3)),
];
