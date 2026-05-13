import 'package:flutter/material.dart';
import '../constants/strings.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(Strings.profileTitle)),
      body: const Center(child: Text('TODO')),
    );
  }
}
