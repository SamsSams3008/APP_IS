import 'package:flutter/material.dart';
import '../widgets/primary_button.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: Center(
        child: PrimaryButton(
          text: 'Ir al Dashboard',
          onPressed: () {
            Navigator.pushNamed(context, '/dashboard');
          },
        ),
      ),
    );
  }
}