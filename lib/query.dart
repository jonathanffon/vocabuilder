import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:flutter_html/flutter_html.dart';

final dicNames = {
  'md': 'merriam dictionary',
  'mt': 'merriam thesaurus',
  'cc': 'collins cobuild'
};

class Query extends StatefulWidget {
  final String word;
  final Database db;
  const Query(this.db, this.word, {super.key});

  @override
  State<StatefulWidget> createState() => QueryState();
}

class QueryState extends State<Query> with TickerProviderStateMixin {
  List<String> dicts = ["status: Not found"];
  List<String> sections = ["No result"];
  late TabController _tabController;
  @override
  void initState() {
    _tabController =
        TabController(length: dicts.length, vsync: this, initialIndex: 0);
    getExplaination();
    super.initState();
  }

  void getExplaination() async {
    final res = await widget.db.rawQuery('''
      select link_word,dicts,sections from 
        vocab_${widget.word[0].toLowerCase()} where word
        in ('${widget.word.toLowerCase()}', '${widget.word}')
      ''');
    if (res.isEmpty) return;
    final row = res.first;
    // TODO
    var strDicts = utf8.decode(gzip.decode(row["dicts"] as List<int>));
    strDicts = strDicts.replaceAll("</div></span>", "</div> </span>");
    final strSections = row["sections"] as String;
    if (strSections.isNotEmpty) {
      setState(() {
        dicts = strDicts.split('\$#\$');
        sections =
            strSections.split(',').map((e) => dicNames[e] ?? '').toList();
        _tabController = TabController(
            length: dicts.length,
            vsync: this,
            initialIndex: dicts.length >= 2 ? 1 : 0);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: dicts.length,
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 42,
          title: Text(widget.word),
        ),
        bottomNavigationBar: Material(
            color: Colors.white60,
            child: Container(
              color: Colors.white.withOpacity(0.5),
              //height: 25,
              child: TabBar(
                labelColor: Colors.teal,
                tabs: sections.map((i) => Text(i)).toList(),
                controller: _tabController,
              ),
            )),
        body: TabBarView(
            controller: _tabController,
            children: dicts.map((i) => DictViewer(i)).toList()),
      ),
    );
  }
}

class DictViewer extends StatelessWidget {
  final String htmlData;
  const DictViewer(this.htmlData, {super.key});
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
        child: Html(data: htmlData, style: {
      ".mm2, .m3s, .tab_content": Style(
          fontSize: const FontSize(16), lineHeight: const LineHeight(1.25)),
      ".iye, .word_entry": Style(
          fontSize: const FontSize(18),
          display: Display.INLINE,
          margin: const EdgeInsets.only(top: 10),
          color: Colors.blue,
          fontWeight: FontWeight.bold),
      ".eyx, .wsm, .okj":
          Style(color: Colors.deepOrange, fontSize: const FontSize(14)),
      ".word_entry>.pron": Style(display: Display.BLOCK),
      ".eyx, .m6j, .word-frequency-img": Style(display: Display.INLINE_BLOCK),
      ".izv, .icon-speak-uk, .icon-speak-us, .icon-speak-form, .cn_before":
          Style(display: Display.NONE),
      "li .chinese-text, .addon": Style(display: Display.NONE),
      ".muj div em, .bld, .fiz, .hcs, .lej, .n6n, .yqg, .num":
          Style(color: Colors.teal),
      ".xsx em, .kmv em, .tips_box": Style(color: Colors.purple),
      ".lsz, b, .jcz, .ycv, .st": Style(color: Colors.red),
      ".zz0, .fzy, .poy": Style(color: Colors.pink),
      ".kmv q": Style(color: Colors.green[900]),
      ".ltp, .tec": Style(color: Colors.lime[900]),
      ".pron, .pron>a":
          Style(color: Colors.black54, textDecoration: TextDecoration.none),
      ".yqg, .lpn, .a3d, .example li": Style(color: Colors.green),
      ".text_blue": Style(color: Colors.amberAccent[700]),
      ".tec, .a3d": Style(fontWeight: FontWeight.bold),
      "p, .cdw": Style(margin: const EdgeInsets.only(left: 10)),
      ".muj": Style(margin: const EdgeInsets.only(left: 5)),
      ".fzy, .j1b": Style(margin: const EdgeInsets.only(top: 5)),
      ".mm2 em":
          Style(fontFamily: '"Georgia", "Times", "Times New Roman", "serif"'),
      ".n6n": Style(fontWeight: FontWeight.bold),
      "h2,.form_inflected, .taps_box":
          Style(fontSize: const FontSize(15), margin: EdgeInsets.zero),
      ".oje, div": Style(margin: EdgeInsets.zero),
      "dt, dl": Style(padding: EdgeInsets.zero, margin: EdgeInsets.zero),
      "dd": Style(margin: const EdgeInsets.only(left: 12)),
      ".collins_en_cn": Style(margin: const EdgeInsets.only(bottom: 15)),
      ".m6j": Style(
          color: Colors.white,
          backgroundColor: Colors.green,
          margin: const EdgeInsets.all(5)),
      ".xsx>div": Style(margin: const EdgeInsets.only(left: 10)),
    }));
  }
}
