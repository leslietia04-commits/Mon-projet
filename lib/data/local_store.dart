import 'dart:typed_data';

import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

class EventItem {
  const EventItem({
    required this.id,
    required this.name,
    required this.city,
    required this.startDate,
    required this.endDate,
    required this.stand,
    this.programme = '',
    this.isLocal = true,
  });

  final int id;
  final String name;
  final String city;
  final String startDate;
  final String endDate;
  final String stand;
  final String programme;
  final bool isLocal;

  factory EventItem.fromMap(Map<String, Object?> map) => EventItem(
    id: map['id']! as int,
    name: map['name']! as String,
    city: map['city']! as String,
    startDate: map['start_date']! as String,
    endDate: map['end_date']! as String,
    stand: map['stand']! as String,
    programme: map['programme'] as String? ?? '',
    isLocal: (map['is_local']! as int) == 1,
  );
}

class LeadItem {
  const LeadItem({
    required this.id,
    required this.eventId,
    required this.name,
    required this.company,
    required this.position,
    required this.owner,
    required this.email,
    required this.phone,
    required this.priority,
    required this.tags,
    required this.note,
    required this.createdAt,
    required this.synced,
    this.voiceNote,
  });

  final int id;
  final int eventId;
  final String name;
  final String company;
  final String position;
  final String owner;
  final String email;
  final String phone;
  final String priority;
  final String tags;
  final String note;
  final Uint8List? voiceNote;
  final String createdAt;
  final bool synced;

  factory LeadItem.fromMap(Map<String, Object?> map) => LeadItem(
    id: map['id']! as int,
    eventId: map['event_id']! as int,
    name: map['name']! as String,
    company: map['company']! as String,
    position: map['position']! as String,
    owner: map['owner']! as String,
    email: map['email']! as String,
    phone: map['phone']! as String,
    priority: map['priority']! as String,
    tags: map['tags']! as String,
    note: map['note']! as String,
    voiceNote: map['voice_note'] as Uint8List?,
    createdAt: map['created_at']! as String,
    synced: (map['synced']! as int) == 1,
  );
}

class LeadDraft {
  const LeadDraft({
    required this.eventId,
    required this.name,
    required this.company,
    required this.position,
    required this.owner,
    required this.email,
    required this.phone,
    required this.priority,
    required this.tags,
    required this.note,
    this.voiceNote,
  });

  final int eventId;
  final String name;
  final String company;
  final String position;
  final String owner;
  final String email;
  final String phone;
  final String priority;
  final List<String> tags;
  final String note;
  final Uint8List? voiceNote;
}

class AgentItem {
  const AgentItem({
    required this.id,
    required this.name,
    required this.email,
    required this.password,
    required this.eventId,
  });

  final int id;
  final String name;
  final String email;
  final String password;
  final int eventId;

  factory AgentItem.fromMap(Map<String, Object?> map) => AgentItem(
    id: map['id']! as int,
    name: map['name']! as String,
    email: map['email']! as String,
    password: map['password']! as String,
    eventId: map['event_id']! as int,
  );
}

abstract interface class ExhibitorStore {
  Future<List<EventItem>> getEvents();
  Future<List<LeadItem>> getLeads();
  Future<List<AgentItem>> getAgents();
  Future<AgentItem?> getAgentByEmail(String email);
  Future<void> addAgent({
    required String name,
    required String email,
    required String password,
    required int eventId,
  });
  Future<void> updateAgent({
    required int id,
    required String name,
    required String email,
    required String password,
    required int eventId,
  });
  Future<void> deleteAgent(int id);
  Future<EventItem> addEvent({
    required String name,
    required String city,
    required String startDate,
    required String endDate,
    required String stand,
  });
  Future<void> updateStand(int eventId, String stand);
  Future<void> updateProgramme(int eventId, String programme);
  Future<void> addLead(LeadDraft draft);
}

class SqliteExhibitorStore implements ExhibitorStore {
  Future<Database>? _database;

  Future<Database> get _db => _database ??= _openDatabase();

  Future<Database> _openDatabase() async {
    final databasePath = await getDatabasesPath();
    return openDatabase(
      path.join(databasePath, 'digitalyx_exhibitor.db'),
      version: 6,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE events (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            city TEXT NOT NULL,
            start_date TEXT NOT NULL,
            end_date TEXT NOT NULL,
            stand TEXT NOT NULL DEFAULT '',
            programme TEXT NOT NULL DEFAULT '',
            is_local INTEGER NOT NULL DEFAULT 1
          )
        ''');
        await db.execute('''
          CREATE TABLE leads (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            event_id INTEGER NOT NULL,
            name TEXT NOT NULL,
            company TEXT NOT NULL,
            position TEXT NOT NULL DEFAULT '',
            owner TEXT NOT NULL DEFAULT 'Équipe de stand',
            email TEXT NOT NULL,
            phone TEXT NOT NULL,
            priority TEXT NOT NULL,
            tags TEXT NOT NULL,
            note TEXT NOT NULL,
            voice_note BLOB,
            created_at TEXT NOT NULL,
            synced INTEGER NOT NULL DEFAULT 0,
            FOREIGN KEY (event_id) REFERENCES events (id)
          )
        ''');
        await db.execute('''
          CREATE TABLE agents (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            email TEXT NOT NULL COLLATE NOCASE UNIQUE,
            password TEXT NOT NULL,
            event_id INTEGER NOT NULL,
            FOREIGN KEY (event_id) REFERENCES events (id)
          )
        ''');
        await db.insert('events', {
          'name': 'GreenTech Expo',
          'city': 'Paris',
          'start_date': '2026-11-18',
          'end_date': '2026-11-20',
          'stand': 'B24',
          'is_local': 1,
        });
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            "ALTER TABLE leads ADD COLUMN position TEXT NOT NULL DEFAULT ''",
          );
        }
        if (oldVersion < 3) {
          await db.execute(
            "ALTER TABLE leads ADD COLUMN owner TEXT NOT NULL DEFAULT 'Équipe de stand'",
          );
        }
        if (oldVersion < 4) {
          await db.execute(
            "ALTER TABLE events ADD COLUMN programme TEXT NOT NULL DEFAULT ''",
          );
        }
        if (oldVersion < 5) {
          await db.execute('''
            CREATE TABLE agents (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              email TEXT NOT NULL COLLATE NOCASE UNIQUE,
              password TEXT NOT NULL,
              event_id INTEGER NOT NULL,
              FOREIGN KEY (event_id) REFERENCES events (id)
            )
          ''');
        }
        if (oldVersion < 6) {
          await db.execute('ALTER TABLE leads ADD COLUMN voice_note BLOB');
        }
      },
    );
  }

  @override
  Future<List<EventItem>> getEvents() async {
    final rows = await (await _db).query('events', orderBy: 'start_date ASC');
    return rows.map(EventItem.fromMap).toList();
  }

  @override
  Future<List<LeadItem>> getLeads() async {
    final rows = await (await _db).query('leads', orderBy: 'created_at DESC');
    return rows.map(LeadItem.fromMap).toList();
  }

  @override
  Future<List<AgentItem>> getAgents() async {
    final rows = await (await _db).query(
      'agents',
      orderBy: 'name COLLATE NOCASE',
    );
    return rows.map(AgentItem.fromMap).toList();
  }

  @override
  Future<AgentItem?> getAgentByEmail(String email) async {
    final rows = await (await _db).query(
      'agents',
      where: 'LOWER(email) = ?',
      whereArgs: [email.trim().toLowerCase()],
      limit: 1,
    );
    return rows.isEmpty ? null : AgentItem.fromMap(rows.first);
  }

  @override
  Future<void> addAgent({
    required String name,
    required String email,
    required String password,
    required int eventId,
  }) async {
    await (await _db).insert('agents', {
      'name': name.trim(),
      'email': email.trim().toLowerCase(),
      'password': password,
      'event_id': eventId,
    });
  }

  @override
  Future<void> updateAgent({
    required int id,
    required String name,
    required String email,
    required String password,
    required int eventId,
  }) async {
    await (await _db).update(
      'agents',
      {
        'name': name.trim(),
        'email': email.trim().toLowerCase(),
        'password': password,
        'event_id': eventId,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> deleteAgent(int id) async {
    await (await _db).delete('agents', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<EventItem> addEvent({
    required String name,
    required String city,
    required String startDate,
    required String endDate,
    required String stand,
  }) async {
    final db = await _db;
    final id = await db.insert('events', {
      'name': name.trim(),
      'city': city.trim(),
      'start_date': startDate,
      'end_date': endDate,
      'stand': stand.trim(),
      'is_local': 1,
    });
    return EventItem(
      id: id,
      name: name.trim(),
      city: city.trim(),
      startDate: startDate,
      endDate: endDate,
      stand: stand.trim(),
    );
  }

  @override
  Future<void> updateStand(int eventId, String stand) async {
    await (await _db).update(
      'events',
      {'stand': stand.trim()},
      where: 'id = ?',
      whereArgs: [eventId],
    );
  }

  @override
  Future<void> updateProgramme(int eventId, String programme) async {
    await (await _db).update(
      'events',
      {'programme': programme.trim()},
      where: 'id = ?',
      whereArgs: [eventId],
    );
  }

  @override
  Future<void> addLead(LeadDraft draft) async {
    await (await _db).insert('leads', {
      'event_id': draft.eventId,
      'name': draft.name.trim(),
      'company': draft.company.trim(),
      'position': draft.position.trim(),
      'owner': draft.owner.trim(),
      'email': draft.email.trim(),
      'phone': draft.phone.trim(),
      'priority': draft.priority,
      'tags': draft.tags.join(','),
      'note': draft.note.trim(),
      'voice_note': draft.voiceNote,
      'created_at': DateTime.now().toIso8601String(),
      'synced': 0,
    });
  }
}
