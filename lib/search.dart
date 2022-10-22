import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_html/html_parser.dart';
import 'package:flutter_html/style.dart';

const htmlData = """
<div class="uay">
  <div class="j1b">
    <div class="muj">
      <span class="xsx">
        <div>
          <div class="tec">syn</div>,
        </div></span></div>
  </div>
  <div class="j1b"><div class="muj"><span class="n6n">5</span></div></div>
</div>
""";

class SearchPage extends StatefulWidget {
  const SearchPage({Key? key}) : super(key: key);

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
            toolbarHeight: 42,
            title: Container(
                height: 28,
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10)),
                child: Center(
                    child: TextField(
                        decoration: InputDecoration(
                            isDense: true,
                            prefixIcon: const Icon(Icons.search, size: 25),
                            suffixIcon: IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {}),
                            hintText: "Search..."))))),
        body: SingleChildScrollView(
            child: Html(data: htmlData, style: {
          ".xsx": Style(display: Display.BLOCK, padding: EdgeInsets.zero),
        })));
  }
}
