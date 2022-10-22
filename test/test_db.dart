/// After executing 'dart $file':
///    drop table dictionary;
///    vacuum;

import 'dart:convert';
import 'dart:io';

import 'package:sqflite_common/sqlite_api.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

late Database db;

void main() async {
  sqfliteFfiInit();
  var databaseFactory = databaseFactoryFfi;
  var dir = Directory.current.path;
  db = await databaseFactory.openDatabase("$dir/../assets/db/words.db");
  final res = await db.rawQuery('''
    select * from 'grecore';
      ''');
  final row = res[0];
  print(row);
  await db.close();
}
