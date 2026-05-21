import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class GroupSettingsScreen extends ConsumerWidget {
  const GroupSettingsScreen({super.key, required this.chatId});
  final String chatId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Group settings')),
      body: const Center(child: Text('TODO: T7.4')),
    );
  }
}
