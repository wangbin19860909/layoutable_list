import 'package:flutter/material.dart';
import 'stack_demo.dart';
import 'grid_demo.dart';
import 'animation_demo.dart';
import 'flex_demo.dart';
import 'layout_animation_demo.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter 布局动画 Demo',
      debugShowCheckedModeBanner: false,
      home: const DemoListScreen(),
    );
  }
}

class DemoListScreen extends StatelessWidget {
  const DemoListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flutter 布局动画 Demo'),
        backgroundColor: Colors.blue,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildDemoCard(
            context,
            title: '堆叠布局',
            description: 'StackLayoutAlgorithm + 补位动画',
            icon: Icons.layers,
            color: Colors.blue,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const StackDemo()),
              );
            },
          ),
          const SizedBox(height: 16),
          _buildDemoCard(
            context,
            title: '网格布局 - 横向一行',
            description: 'GridLayoutAlgorithm + 补位动画',
            icon: Icons.view_carousel,
            color: Colors.green,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const GridDemo()),
              );
            },
          ),
          const SizedBox(height: 16),
          _buildDemoCard(
            context,
            title: 'FlexBox 布局',
            description: 'FlexLayoutAlgorithm + justify-content / align-items',
            icon: Icons.view_week,
            color: Colors.indigo,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const FlexDemo()),
              );
            },
          ),
          const SizedBox(height: 16),
          _buildDemoCard(
            context,
            title: '补位动画 Demo',
            description: 'add / remove / move / swap / reverse',
            icon: Icons.swap_horiz,
            color: Colors.teal,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LayoutAnimationDemo()),
              );
            },
          ),
          const SizedBox(height: 16),
          _buildDemoCard(
            context,
            title: '动画演示',
            description: 'AnimationWidget: offset / scale / alpha + 弹簧 / 曲线',
            icon: Icons.animation,
            color: Colors.deepPurple,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AnimationDemoPage()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDemoCard(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 32, color: color),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}
