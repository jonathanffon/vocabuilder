/// After executing 'dart $file':
///    drop table dictionary;
///    vacuum;

import 'dart:convert';
import 'dart:io';

import 'package:sqflite_common/sqlite_api.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

late Database db;
List<String> dictCols = [
  "merriam_dict",
  "merriam_thesaurus",
  "collins_cobuild"
];
final dictCodes = ['md', 'mt', 'cc'];

void main() async {
  sqfliteFfiInit();
  var databaseFactory = databaseFactoryFfi;
  var dir = Directory.current.path;
  db = await databaseFactory.openDatabase("$dir/dicts.db");
  List<String> tableNames = ["vocab_\$"];
  int j = 25;
  do {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${tableNames.removeLast()}(
        id integer NOT NULL PRIMARY KEY,
        word text NOT NULL UNIQUE,
        link_word text, 
        dicts blob,
        sections text
      ); ''');
    tableNames.add('vocab_${String.fromCharCode('a'.codeUnitAt(0) + j)}');
  } while (j-- >= 0 && tableNames.isNotEmpty);
  await db.execute('''
    CREATE TABLE IF NOT EXISTS config (
      section_name text,
      section_code text
    );''');
  j = 0;
  for (final c in dictCodes) {
    await db
        .insert('config', {'section_name': dictCols[j++], 'section_code': c});
  }
  var result = await db.rawQuery('select count(word) from dictionary');
  int count = result.first['count(word)'] as int;
  await compressDict(count);
  await db.close();
}

Future compressDict(int totalCnt) async {
  // Init ffi loader if needed.
  print("compressing ${totalCnt} records\n");
  int i, j;
  Batch bch;
  String tableName, term, sections;
  List<Map> res;
  final codec = GZipCodec(level: 8);
  const chunkSize = 1000;
  for (i = 0; i < totalCnt; i += chunkSize) {
    print("  processing index from $i");
    res = await db.query("dictionary", limit: chunkSize, offset: i);
    bch = db.batch();
    for (final row in res) {
      term = sections = "";
      for (j = 0; j < 3; j++) {
        final blob = row[dictCols[j]];
        if (blob == null || blob.isEmpty) continue;
        if (term.isNotEmpty) {
          term += "\$#\$";
          sections += ',';
        }
        term += utf8.decode(gzip.decode(blob));
        sections += dictCodes[j];
      }
      final word = (row["word"] as String).toLowerCase();
      final ch = word.codeUnitAt(word.startsWith("-") ? 1 : 0);
      if (ch >= 'a'.codeUnitAt(0) && ch <= 'z'.codeUnitAt(0)) {
        tableName = "vocab_${String.fromCharCode(ch)}";
      } else {
        tableName = "vocab_\$";
      }
      final newblob = codec.encode(utf8.encode(term));
      bch.rawInsert(
          "insert or replace into $tableName (word,link_word,dicts,sections) values (?,?,?,?)",
          [row["word"], row["link_word"], newblob, sections]);
    }
    await bch.commit(noResult: true);
  }
}
