import 'package:flutter/material.dart';

class StackTestDemo extends StatelessWidget {
  const StackTestDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stack Test Demo'),
        backgroundColor: Colors.blue,
      ),
      body: Center(
        child: Container(
          width: 100,
          height: 200,
          color: Colors.grey[300],
          child: Center(
            child: Stack(
              children: [
                // 第一个 child：80x160 黄色方框
                Container(
                  width: 80,
                  height: 160,
                  color: Colors.yellow,
                ),
                // 第二个 child：100x20 红色方框
                Container(
                  width: 100,
                  height: 20,
                  color: Colors.red,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
