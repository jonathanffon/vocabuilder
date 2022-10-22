import 'dart:io';
import 'search.dart';
import 'pick.dart';
import 'globals.dart';
import 'package:desktop_window/desktop_window.dart';
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:path/path.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await newUserDatabase("words");
  await newUserDatabase("dicts");
  Directory documentsDirectory = await getApplicationDocumentsDirectory();
  var pathw = join(documentsDirectory.path, "usr_words.db");
  var pathd = join(documentsDirectory.path, "usr_dicts.db");
  if (Platform.isLinux || Platform.isWindows) {
    await DesktopWindow.setWindowSize(const Size(500, 600));
    dbWords = await databaseFactoryFfi.openDatabase(pathw);
    dbDicts = await databaseFactoryFfi.openDatabase(pathd);
  } else {
    dbWords = await openDatabase(pathw);
    dbDicts = await openDatabase(pathd);
  }
  runApp(const MyApp());
}

Future newUserDatabase(String dbname) async {
  Directory documentsDirectory = await getApplicationDocumentsDirectory();
  String path = join(documentsDirectory.path, "usr_$dbname.db");

  // Load database from asset and copy
  if (FileSystemEntity.typeSync(path) == FileSystemEntityType.notFound) {
    ByteData data = await rootBundle.load(join('assets/db', '$dbname.db'));
    List<int> bytes =
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);

    // Save copied asset to documents
    await File(path).writeAsBytes(bytes);
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vocabulary Playground',
      theme: ThemeData(
        primarySwatch: Colors.blueGrey,
      ),
      home: const MyHomePage(title: 'Home'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _currentBook = 0;
  final CarouselController _controller = CarouselController();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
            toolbarHeight: 42,
            title: Row(
                children: const [Icon(Icons.menu), Text("  Vocab Playground")]),
            actions: [
              IconButton(
                  onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SearchPage())),
                  icon: const Icon(Icons.search)),
            ]),
        body: Center(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CarouselSlider(
                options: CarouselOptions(
                    height: MediaQuery.of(context).size.height * 0.5,
                    enlargeCenterPage: true,
                    onPageChanged: (index, reason) {
                      setState(() {
                        _currentBook = index;
                      });
                    }),
                items: ["GRE 7000", 2, 3, 4, 5].map((i) {
                  return Builder(
                    builder: (BuildContext context) {
                      return Container(
                          width: MediaQuery.of(context).size.width * 0.8,
                          margin: const EdgeInsets.symmetric(horizontal: 5.0),
                          decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: Colors.teal[100]),
                          child: Text(
                            '$i',
                            style: const TextStyle(
                                fontSize: 16.0, color: Colors.amber),
                          ));
                    },
                  );
                }).toList(),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 24, bottom: 12),
                child: Text(
                  'Worm',
                  style: TextStyle(color: Colors.black54),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [0, 1, 2, 3, 4].map((entry) {
                  return GestureDetector(
                    onTap: () => _controller.animateToPage(entry),
                    child: Container(
                      width: 12.0,
                      height: 12.0,
                      margin: const EdgeInsets.symmetric(
                          vertical: 8.0, horizontal: 4.0),
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: (Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.white
                                  : Colors.blue)
                              .withOpacity(_currentBook == entry ? 0.9 : 0.4)),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                icon: const Icon(Icons.start),
                label: const Text("Start"),
                onPressed: () => Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => const Pick())),
              )
            ],
          ),
        ),
        floatingActionButton:
            Column(mainAxisAlignment: MainAxisAlignment.end, children: [
          FloatingActionButton.small(
            heroTag: "addBtn",
            onPressed: () => {},
            tooltip: 'Add',
            child: const Icon(Icons.add),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.small(
            heroTag: "deleteBtn",
            onPressed: () => {},
            tooltip: 'Delete',
            child: const Icon(Icons.delete),
          ),
        ]));
  }
}
