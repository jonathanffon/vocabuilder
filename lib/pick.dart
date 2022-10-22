import 'package:flutter/material.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';
import 'globals.dart';
import 'words.dart';

class Pick extends StatefulWidget {
  const Pick({super.key});

  @override
  State<Pick> createState() => _PickState();
}

class _PickState extends State<Pick> {
  late List<String> primaryTags = [];
  late List<String> secondaryTags = [];
  @override
  void initState() {
    super.initState();
    getCategories();
  }

  void getCategories() async {
    final db = dbWords;
    var res = await db.rawQuery('''
      select * from category where Book='gre_core' ''');
    if (res.isEmpty) return;
    final book = res.first;
    setState(() {
      primaryTags = (book["Category1"] as String).split(",");
      secondaryTags = (book["Category2"] as String).split(",");
    });
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> picker = [
      const Text("Pickup desired tags:", style: TextStyle(fontSize: 18)),
      const SizedBox(height: 30),
    ];
    if (primaryTags.isNotEmpty) {
      picker.add(UnitSelector(primaryTags, "Category1"));
    }
    if (secondaryTags.isNotEmpty) {
      picker.add(UnitSelector(secondaryTags, "Category2"));
    }
    return Scaffold(
        appBar:
            AppBar(toolbarHeight: 42, title: const Text("Select categories")),
        body: Center(
          child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.8,
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: picker)),
        ));
  }
}

// Widget for every category of book.
class UnitSelector extends StatefulWidget {
  final List<String> units;
  final String descr;
  const UnitSelector(this.units, this.descr, {super.key});

  @override
  State<UnitSelector> createState() => _UnitSelectorState();
}

class _UnitSelectorState extends State<UnitSelector> {
  List selectedTags = [];
  void onStats() {}
  void onRecommend(int genre) {}
  void onPlay() {
    Widget wordView = Words(widget.descr, selectedTags);
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => wordView));
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      MultiSelectDialogField(
        checkColor: Colors.amber,
        selectedColor: Colors.teal.withOpacity(0.4),
        listType: MultiSelectListType.CHIP,
        searchable: true,
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.1),
          //borderRadius: const BorderRadius.all(Radius.circular(10)),
          border: const Border(
              bottom: BorderSide(
            color: Colors.teal,
            width: 2,
          )),
        ),
        buttonText: Text("${widget.descr} selector"),
        title: Text(widget.descr),
        items: widget.units.map((e) => MultiSelectItem(e, e)).toList(),
        onConfirm: (values) {
          selectedTags = values;
        },
        chipDisplay: MultiSelectChipDisplay(
          onTap: (value) {
            selectedTags.remove(value);
          },
        ),
      ),
      const SizedBox(height: 5),
      Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        ElevatedButton.icon(
            icon: const Icon(Icons.bar_chart),
            label: const Text("STATS"),
            onPressed: onStats),
        ElevatedButton.icon(
            icon: const Icon(Icons.recommend),
            label: const Text("Auto"),
            onPressed: () => {}),
        ElevatedButton.icon(
            icon: const Icon(Icons.play_lesson),
            label: const Text("Play"),
            onPressed: onPlay)
      ]),
      const SizedBox(height: 25),
    ]);
  }
}
