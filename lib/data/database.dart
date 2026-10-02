import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// SQLite database holder. All tables are local to the device.
class AppDatabase {
  static const _name = 'upi_expense_tracker.db';
  static const _version = 1;
  Database? _db;

  Future<Database> get database async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dir = await getDatabasesPath();
    return openDatabase(
      p.join(dir, _name),
      version: _version,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE expenses(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            amount REAL NOT NULL,
            payee TEXT NOT NULL DEFAULT '',
            category TEXT NOT NULL DEFAULT 'Other',
            note TEXT NOT NULL DEFAULT '',
            paid_via TEXT NOT NULL DEFAULT '',
            date TEXT NOT NULL,
            sms_id INTEGER,
            created_at TEXT NOT NULL
          )
        ''');
        await db.execute('CREATE INDEX idx_expenses_date ON expenses(date)');
        await db.execute('''
          CREATE TABLE budgets(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            category TEXT NOT NULL DEFAULT '',
            amount REAL NOT NULL,
            period TEXT NOT NULL DEFAULT 'monthly'
          )
        ''');
        await db.execute('''
          CREATE TABLE reminders(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            category TEXT NOT NULL DEFAULT 'Other',
            amount REAL NOT NULL DEFAULT 0,
            frequency TEXT NOT NULL DEFAULT 'monthly',
            day_of INTEGER NOT NULL DEFAULT 1,
            last_fired TEXT,
            enabled INTEGER NOT NULL DEFAULT 1
          )
        ''');
        await db.execute('''
          CREATE TABLE custom_categories(
            name TEXT PRIMARY KEY,
            color INTEGER NOT NULL
          )
        ''');
      },
    );
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
