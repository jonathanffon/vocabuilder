import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common/sqlite_api.dart';
import 'package:vocab/globals.dart';
import 'query.dart';

typedef WdCallback = void Function(String, int);

class Words extends StatefulWidget {
  final List tags;
  final String category;
  const Words(this.category, this.tags, {super.key});

  @override
  State<StatefulWidget> createState() => WordsState();
}

class WordsState extends State<Words> {
  List wordlst = [];
  Map<String, int> changedMap = {};
  final Database dbw = dbWords;
  final ScrollController _scrollController =
      ScrollController(initialScrollOffset: 0);

  @override
  void initState() {
    super.initState();
    getWordList();
  }

  void wordStateChangeCallback(String word, int state) {
    changedMap[word] = state;
  }

  void getWordList() async {
    String range = "('${widget.tags.join("','")}')";
    String order = widget.category == 'Category1' ? '' : 'order by Word';
    List res = await dbw.rawQuery(
        'select * from grecore where ${widget.category} in $range $order');
    List words = [];
    for (Map q in res) {
      final row = q.values.toList();
      List thesaurus = [];
      for (int i = 4; i < 8; i++) {
        if (row[i] != null) {
          thesaurus.add(row[i]);
        }
      }
      // [word, [thesaurus], masterLevel, IsExpanded]
      // masterLevel: 0 - Oblivious; 1 - Learning; 10 - mastered.
      words.add([row[1], thesaurus, row[8], 0]);
    }
    setState(() {
      wordlst = words;
    });
  }

  Future updateWordState() async {
    final bch = dbw.batch();
    for (final k in changedMap.keys) {
      final state = changedMap[k];
      bch.update('grecore', {'State': state}, where: 'Word=?', whereArgs: [k]);
    }
    await bch.commit(noResult: true);
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // confirm exit
        return (await showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Do you want to exit ?'),
                content: const Text('Choose an action'),
                actions: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Exit'),
                  ),
                  TextButton(
                    onPressed: () async {
                      await updateWordState();
                      Navigator.of(context).pop(true);
                    },
                    child: const Text('Save&Exit'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            )) ??
            false;
      },
      child: Scaffold(
          appBar:
              AppBar(toolbarHeight: 42, title: Text(widget.tags.toString())),
          body: Center(
            child: Scrollbar(
                thumbVisibility: true,
                controller: _scrollController,
                child: ListView.builder(
                    itemCount: wordlst.length,
                    scrollDirection: Axis.vertical,
                    shrinkWrap: true,
                    controller: _scrollController,
                    itemBuilder: (context, index) => ExpansionEntry(
                        wordlst[index], wordStateChangeCallback))),
          )),
    );
  }
}

class ExpansionEntry extends StatefulWidget {
  final List entry;
  final WdCallback stateChangeCallback;
  const ExpansionEntry(this.entry, this.stateChangeCallback, {super.key});

  @override
  State<ExpansionEntry> createState() => _ExpansionEntryState();
}

class _ExpansionEntryState extends State<ExpansionEntry> {
  List entry = [];
  final Database dbd = dbDicts;
  @override
  void initState() {
    super.initState();
    entry = widget.entry;
  }

  // Lookup word in dictionary
  void lookup(BuildContext context, String w) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => Query(dbd, w)));
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      ExpansionPanelList(
          dividerColor: Colors.redAccent,
          expandedHeaderPadding: EdgeInsets.zero,
          expansionCallback: (panelIndex, isExpanded) {
            entry[3] = isExpanded ? 0 : 1;
            setState(() {});
          },
          children: [
            ExpansionPanel(
              backgroundColor: entry[2] <= 5
                  ? Colors.white
                  : const Color.fromARGB(33, 198, 255, 203),
              body: Container(
                  padding: const EdgeInsets.only(left: 20, bottom: 10),
                  alignment: Alignment.topLeft,
                  child: Wrap(
                      spacing: 15,
                      children: entry[1]
                          .map<Widget>((i) => OutlinedButton(
                              onPressed: () {
                                lookup(context, i);
                              },
                              child: Text(i)))
                          .toList()) // similar words
                  ),
              isExpanded: entry[3] == 1,
              headerBuilder: (BuildContext context, bool isExpanded) {
                return ListTile(
                    title: InkWell(
                      child: Text(
                        entry[0],
                        style: TextStyle(
                            color: entry[2] < 1 ? Colors.red : Colors.teal,
                            fontWeight: FontWeight.bold),
                      ),
                      onTap: () => {lookup(context, entry[0])},
                    ), // word entry master level = 1~10
                    trailing: Wrap(spacing: 12, children: [
                      IconButton(
                        icon: entry[2] <= 0
                            ? const Icon(Icons.task_alt)
                            : const Icon(Icons.remove_done),
                        color: entry[2] == 0 ? Colors.blue : Colors.teal,
                        onPressed: () {
                          entry[2] = entry[2] < 5 ? entry[2] + 5 : entry[2] - 5;
                          widget.stateChangeCallback(entry[0], entry[2]);
                          setState(() {});
                        }, // task_alt: level+5; remove_done: level-5
                      ), // Familiar with this word
                      IconButton(
                        icon: const Icon(Icons.remove_circle),
                        color: Colors.red,
                        onPressed: () {
                          entry[2] = 10;
                          widget.stateChangeCallback(entry[0], entry[2]);
                          setState(() {});
                        },
                      ), // know the word well
                    ]));
              },
            )
          ]),
      const SizedBox(
        height: 2,
      )
    ]);
  }
}
