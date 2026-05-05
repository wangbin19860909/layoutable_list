import 'package:flutter/material.dart';

/// 测试 ListView/GridView item 加 Transform.translate 后 hit test 是否跟随视觉位置
class ListViewTransformTest extends StatelessWidget {
  const ListViewTransformTest({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Transform Hit Test'),
          bottom: const TabBar(tabs: [Tab(text: 'ListView'), Tab(text: 'GridView 2行')]),
        ),
        body: const TabBarView(children: [_ListViewTest(), _GridViewTest()]),
      ),
    );
  }
}

class _ListViewTest extends StatelessWidget {
  const _ListViewTest();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: 5,
      itemExtent: 200,
      itemBuilder: (context, index) {
        return Transform.translate(
          offset: const Offset(40, 40), // 横向和纵向都偏移 40px
          child: GestureDetector(
            onTap: () => debugPrint('[ListView] tapped index=$index'),
            child: Container(
              margin: const EdgeInsets.all(8),
              color: Colors.primaries[index % Colors.primaries.length],
              alignment: Alignment.center,
              child: Text('$index', style: const TextStyle(color: Colors.white, fontSize: 32)),
            ),
          ),
        );
      },
    );
  }
}

class _GridViewTest extends StatelessWidget {
  const _GridViewTest();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      scrollDirection: Axis.horizontal,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2),
      itemCount: 10,
      itemBuilder: (context, index) {
        return Transform.translate(
          offset: const Offset(0, 40),
          child: GestureDetector(
            onTap: () => debugPrint('[GridView] tapped index=$index'),
            child: Container(
              margin: const EdgeInsets.all(8),
              color: Colors.primaries[index % Colors.primaries.length],
              alignment: Alignment.center,
              child: Text('$index', style: const TextStyle(color: Colors.white, fontSize: 32)),
            ),
          ),
        );
      },
    );
  }
}
