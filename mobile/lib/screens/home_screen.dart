import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: Center(
        child: ElevatedButton(
          child: const Text('Ir al Dashboard'),
          onPressed: () {
            Navigator.pushNamed(context, '/dashboard');
          },
        ),
      ),
    );
  }
}