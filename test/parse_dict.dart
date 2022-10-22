import "dart:io";
import "dart:developer";
import 'dart:convert';
import 'package:sqflite_common/sqlite_api.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

late Batch bch;
late Database db;
int alphabet = 0, nrec = 0;

void main() async {
  sqfliteFfiInit();
  final dir = Directory.current.path;
  db = await databaseFactoryFfi.openDatabase('$dir/dicts.db');
  db.execute('''
      CREATE TABLE IF NOT EXISTS dictionary(
        id integer NOT NULL PRIMARY KEY,
        word text NOT NULL UNIQUE,
        link_word text, 
        merriam_dict blob,
        merriam_thesaurus blob,
        collins_cobuild blob
      );
  ''');
  bch = db.batch();
  await processDict();
}

Future processDict() async {
  // fileName: [ identifier in string, column in database ]
  Map dicmap = {
    'MerriamWebster.txt': [
      '<div class="mm2"',
      'merriam_dict',
      '<div class="m3s"',
      'merriam_thesaurus'
    ],
    'CollinsCobuild.txt': [
      '<div class="collinsbody"',
      'collins_cobuild',
    ]
  };
  for (var key in dicmap.keys) {
    print("----\nProcessing $key\n");
    nrec = 0;
    alphabet = '0'.codeUnitAt(0);
    var lines = File(key)
        .openRead()
        .transform(utf8.decoder)
        .transform(const LineSplitter());
    lines.forEach((l) => extractEntries(l, dicmap[key]));
    print("Processed $nrec words\n");
  }
  await bch.commit(noResult: false);
  // return db.close();
}

// extract entries from lexical explanation
void extractEntries(String l, List<String> rules) async {
  int idxWordtail = -1, idxXmlstart = 0;
  String refWord = "";
  for (var i = 0; i < l.length; i++) {
    if (l[i] == ' ' || l[i] == '\t') {
      idxWordtail = i;
    }
    // a word is followed by ' ', '<' or '@'
    if (l[i] == '<') {
      idxXmlstart = i;
      break;
    } else if (l[i] == '@') {
      int start = l.indexOf("LINK=");
      int end = l.indexOf("\\n");
      refWord = l.substring(start + 5, end);
      String word = l.substring(0, idxWordtail);
      word = word.replaceAll('&amp;', '&');
      //log("$word  --- ref: $refWord");
      updateDatabase(word, linkWord: refWord);
      return;
    }
  }
  final word = l.substring(0, idxWordtail);
  var xmlstr = l.substring(idxXmlstart);
  if (word == 'testdebug') return; // ignore a debug record
  List<String> itemlist = [];
  for (var r = 0; r < rules.length; r = r + 2) {
    int pos = xmlstr.indexOf(rules[r]);
    if (pos >= 0) {
      final str = parseSnippet(xmlstr, pos);
      itemlist.add(rules[r + 1]);
      itemlist.add(str);
    }
  }
  updateDatabase(word, entries: itemlist);
}

// entries: [column1, value1, ...]
void updateDatabase(String word,
    {List<String> entries = const [], String linkWord = ''}) {
  List<String> columns = ["word"];
  List values = [word]; // used to fill text,blob
  String sets = "";
  if (linkWord.isNotEmpty) {
    columns.add("link_word");
    values.add(linkWord);
    sets = "link_word=excluded.link_word";
  } else if (entries.isNotEmpty) {
    for (int i = 0; i < entries.length; i += 2) {
      final v = utf8.encode(entries[i + 1]);
      columns.add(entries[i]);
      values.add(gzip.encode(v));
      sets += "${entries[i]}=excluded.${entries[i]},";
    }
    sets = sets.substring(0, sets.length - 1);
  } else {
    return;
  }
  bch.rawInsert('''
    INSERT INTO dictionary (${columns.join(',')}) 
    VALUES (${List.filled(columns.length, '?').join(',')})
    ON CONFLICT(word) DO UPDATE SET $sets
  ''', values);
  if (nrec % 2000 == 0) {
    bch.commit(noResult: false);
  }
  // print info
  final letter = word.toLowerCase().codeUnitAt(0);
  if (letter != alphabet) {
    final ch = String.fromCharCode(letter);
    alphabet = letter;
    print("  $nrec words extracted; dealing with $ch*!");
  }
  nrec++;
}

// return the snippet parsed from xs, starting from position.
String parseSnippet(String xs, [int startPos = 0]) {
  int j = 0, maskLevel = -1, code = 0, errs = 0;
  bool hasSlash = false, hasTag = false, isFinished = false;
  String str = "", tag = "", prefix = "", affix = "";
  List<String> tagsList = [];
  while (startPos < xs.length && !isFinished) {
    if (xs[startPos] == '<') {
      // identify tags
      hasSlash = false;
      hasTag = false;
      for (j = startPos + 1; xs[j] != '>'; j++) {
        if (!hasSlash &&
            xs[j] == '/' &&
            (xs[j - 1] == '<' || xs[j + 1] == '>')) {
          hasSlash = true;
          continue; // donnot try to recognize tag then
        } // this is a closed tag
        if (!hasTag) {
          if (xs[j] == '<') {
            tag = tagsList.last;
            affix = "$tag>";
            hasTag = true;
            break;
          } // deal with '</<div>' bug
          do {
            code = xs.codeUnitAt(j++);
          } while ((code >= 'A'.codeUnitAt(0) && code <= 'Z'.codeUnitAt(0)) ||
              (code >= 'a'.codeUnitAt(0) && code <= 'z'.codeUnitAt(0)) ||
              (code >= '0'.codeUnitAt(0) && code <= '9'.codeUnitAt(0)));
          j = j - 2; // back to the last charactor of the tag
          tag = xs.substring(startPos + (hasSlash ? 2 : 1), j + 1);
          hasTag = true;
        }
      }
      j++; // move to next char after '>'
      // maintain a tag stack until it's empty.
      if (hasSlash && xs[startPos + 1] == '/') {
        while (['img', 'br'].contains(tagsList.last)) {
          tagsList.removeLast();
        }
        if (tag == tagsList.last) {
          tagsList.removeLast();
          errs = 0;
          isFinished = tagsList.isEmpty ? true : false;
        } else if (tag == tagsList[tagsList.length - 2]) {
          // deal with '<q><em></q><div></em></div>' bug
          final lastTag = tagsList.removeLast();
          tagsList.removeLast();
          prefix = "</$lastTag>";
          errs = 0;
        } else if (errs < 1) {
          // allow just one error like '<q></h2></q>'
          prefix = "<$tag>";
          errs++;
        } else {
          log("The closed tag </$tag> doesnot match previous ones");
        }
      } else if (!hasSlash && tag != 'sc') {
        // deal with invalid <sc> bug
        tagsList.add(tag);
      }
    } else {
      // identify contents outside '<>'. 'script' is skipped.
      if (tag == "script") {
        startPos = xs.indexOf("</script>", startPos);
      }
      if (startPos < 0) {
        log('startPos wrong');
      }
      for (j = startPos;
          j < xs.length && xs[j] != '<';
          j++); // move to start of '<'
    }
    // make a new string that we want.
    if (tag != "script" && tag != 'img' && tag != 'sc') {
      String substr = prefix + xs.substring(startPos, j) + affix;
      prefix = affix = "";
      if (substr.startsWith('<div class="trendContent"')) {
        maskLevel = tagsList.length;
        str += '<div>'; // just mask trendContent
      }
      if (maskLevel < 0 || tagsList.length < maskLevel) {
        maskLevel = -1;
        str += substr;
      }
    }
    startPos = j;
  }
  return str;
}
