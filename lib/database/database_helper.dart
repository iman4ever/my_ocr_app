import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'receipt_model.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('receipts.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path, 
      version: 2, // Increment version
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const realType = 'REAL NOT NULL';

    await db.execute('''
CREATE TABLE receipts ( 
  id $idType, 
  title $textType,
  amount $realType,
  date $textType,
  category $textType,
  imagePath $textType,
  items TEXT 
  )
''');
  }
  
  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE receipts ADD COLUMN items TEXT');
    }
  }

  Future<int> create(Receipt receipt) async {
    final db = await instance.database;
    return await db.insert('receipts', receipt.toMap());
  }

  Future<Receipt> readReceipt(int id) async {
    final db = await instance.database;
    final maps = await db.query(
      'receipts',
      columns: ['id', 'title', 'amount', 'date', 'category', 'imagePath'],
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return Receipt.fromMap(maps.first);
    } else {
      throw Exception('ID $id not found');
    }
  }

  Future<List<Receipt>> readAllReceipts() async {
    final db = await instance.database;
    final orderBy = 'date DESC';
    final result = await db.query('receipts', orderBy: orderBy);

    return result.map((json) => Receipt.fromMap(json)).toList();
  }

  Future<int> update(Receipt receipt) async {
    final db = await instance.database;
    return await db.update(
      'receipts',
      receipt.toMap(),
      where: 'id = ?',
      whereArgs: [receipt.id],
    );
  }

  Future<int> delete(int id) async {
    final db = await instance.database;
    return await db.delete(
      'receipts',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
  
  Future<double> calculateTotalSpending() async {
     final db = await instance.database;
     final result = await db.rawQuery('SELECT SUM(amount) as total FROM receipts');
     if(result.isNotEmpty && result.first['total'] != null) {
       return result.first['total'] as double;
     }
     return 0.0;
  }
  
  // Returns Map<Category, Amount>
  Future<Map<String, double>> getSpendingByCategory() async {
    final db = await instance.database;
    final result = await db.rawQuery('SELECT category, SUM(amount) as total FROM receipts GROUP BY category');
    
    Map<String, double> stats = {};
    for (var row in result) {
      stats[row['category'] as String] = row['total'] as double;
    }
    return stats;
  }
  
  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }
}
