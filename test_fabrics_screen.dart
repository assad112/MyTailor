import 'package:flutter/material.dart';
import 'lib/screens/manage_fabrics_modern_screen.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Test Fabrics Screen',
      home: Scaffold(
        appBar: AppBar(title: Text('اختبار شاشة الخامات')),
        body: Center(
          child: ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ManageFabricsModernScreen(),
                ),
              );
            },
            child: Text('فتح شاشة الخامات الجديدة'),
          ),
        ),
      ),
    );
  }
}

