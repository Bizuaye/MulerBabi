import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/drug.dart';
import '../models/customer.dart';

class DBHelper {
  static final DBHelper instance = DBHelper._();
  DBHelper._();

  static Database? _db;

  Future<Database> get database async {
    _db ??= await _init();
    return _db!;
  }

  Future<Database> _init() async {
    final path = join(await getDatabasesPath(), 'vet_wholesale.db');
    return openDatabase(path, version: 1, onCreate: (db, v) async {
      await db.execute('''
        CREATE TABLE drugs(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          category TEXT NOT NULL,
          batchNumber TEXT NOT NULL,
          supplier TEXT NOT NULL,
          quantity INTEGER NOT NULL,
          costPrice REAL NOT NULL,
          sellingPrice REAL NOT NULL,
          expiryDate TEXT NOT NULL,
          notes TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE customers(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          phone TEXT NOT NULL,
          address TEXT,
          creditLimit REAL DEFAULT 0
        )
      ''');
      await db.execute('''
        CREATE TABLE credit_transactions(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          customerId INTEGER NOT NULL,
          drugId INTEGER,
          description TEXT NOT NULL,
          amount REAL NOT NULL,
          date TEXT NOT NULL,
          type TEXT NOT NULL
        )
      ''');
    });
  }

  Future<int> insertDrug(Drug d) async {
    final db = await database;
    return db.insert('drugs', d.toMap()..remove('id'));
  }

  Future<int> updateDrug(Drug d) async {
    final db = await database;
    return db.update('drugs', d.toMap(), where: 'id=?', whereArgs: [d.id]);
  }

  Future<int> deleteDrug(int id) async {
    final db = await database;
    return db.delete('drugs', where: 'id=?', whereArgs: [id]);
  }

  Future<List<Drug>> getAllDrugs() async {
    final db = await database;
    final rows = await db.query('drugs', orderBy: 'expiryDate ASC');
    return rows.map((e) => Drug.fromMap(e)).toList();
  }

  Future<int> insertCustomer(Customer c) async {
    final db = await database;
    return db.insert('customers', c.toMap()..remove('id'));
  }

  Future<int> updateCustomer(Customer c) async {
    final db = await database;
    return db.update('customers', c.toMap(), where: 'id=?', whereArgs: [c.id]);
  }

  Future<int> deleteCustomer(int id) async {
    final db = await database;
    await db.delete('credit_transactions', where: 'customerId=?', whereArgs: [id]);
    return db.delete('customers', where: 'id=?', whereArgs: [id]);
  }

  Future<List<Customer>> getAllCustomers() async {
    final db = await database;
    final rows = await db.query('customers', orderBy: 'name ASC');
    return rows.map((e) => Customer.fromMap(e)).toList();
  }

  Future<int> insertTransaction(CreditTransaction t) async {
    final db = await database;
    return db.insert('credit_transactions', t.toMap()..remove('id'));
  }

  Future<List<CreditTransaction>> getCustomerTransactions(int customerId) async {
    final db = await database;
    final rows = await db.query('credit_transactions',
        where: 'customerId=?', whereArgs: [customerId], orderBy: 'date DESC');
    return rows.map((e) => CreditTransaction.fromMap(e)).toList();
  }

  Future<double> getCustomerBalance(int customerId) async {
    final db = await database;
    final rows = await db.rawQuery(
        'SELECT COALESCE(SUM(amount),0) AS total FROM credit_transactions WHERE customerId=?',
        [customerId]);
    return (rows.first['total'] as num).toDouble();
  }

  Future<Map<int, double>> getAllBalances() async {
    final db = await database;
    final rows = await db.rawQuery(
        'SELECT customerId, SUM(amount) AS total FROM credit_transactions GROUP BY customerId');
    return {
      for (final r in rows) (r['customerId'] as int): (r['total'] as num).toDouble()
    };
  }
}
