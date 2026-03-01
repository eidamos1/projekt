// pages/calendar_page.dart
// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/task.dart';
import '../widgets/task_card.dart';
import '../widgets/xp_bar.dart';
import '../services/task_service.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _taskService = TaskService();

  final TextEditingController _titleController = TextEditingController();
  TaskType _selectedType = TaskType.daily;

  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  bool _isDayInPast(DateTime day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final checkDay = DateTime(day.year, day.month, day.day);
    return checkDay.isBefore(today);
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser!;
    final uid = user.uid;

    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection('users').doc(uid).snapshots(),
      builder: (context, snapshot) {
        int xp = 0, coins = 0, level = 1, streak = 0;
        String nickname = 'Hrac';
        String? photoUrl;

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          xp = data['xp'] ?? 0;
          coins = data['coins'] ?? 0;
          level = data['level'] ?? 1;
          streak = data['streak'] ?? 0;
          nickname = data['nickname'] ?? 'Hrac';
          photoUrl = data['photoUrl'];
        }

        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                if (photoUrl != null && photoUrl.isNotEmpty)
                  CircleAvatar(
                    backgroundImage: NetworkImage(photoUrl),
                    radius: 18,
                    backgroundColor: Colors.transparent,
                  )
                else
                  CircleAvatar(
                    backgroundColor: Colors.indigo.shade100,
                    radius: 18,
                    child: Text(
                      nickname.isNotEmpty ? nickname[0].toUpperCase() : '?',
                      style: const TextStyle(
                          color: Colors.indigo, fontWeight: FontWeight.bold),
                    ),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    nickname,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ],
            ),
            actions: [
              // Streak counter
              if (streak > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.local_fire_department,
                          color: Colors.orange, size: 20),
                      const SizedBox(width: 2),
                      Text('$streak',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                ),
              // Zvonecek s badge
              StreamBuilder<int>(
                stream: _taskService.unreadNotificationCount(),
                builder: (context, notifSnapshot) {
                  final count = notifSnapshot.data ?? 0;
                  return IconButton(
                    icon: Badge(
                      isLabelVisible: count > 0,
                      label: Text('$count'),
                      child: const Icon(Icons.notifications),
                    ),
                    tooltip: 'Notifikace',
                    onPressed: () =>
                        Navigator.pushNamed(context, '/notifications'),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.bar_chart),
                tooltip: 'Statistiky',
                onPressed: () => Navigator.pushNamed(context, '/stats'),
              ),
              IconButton(
                icon: const Icon(Icons.task_alt),
                tooltip: 'Potvrdit kod',
                onPressed: () => Navigator.pushNamed(context, '/confirm'),
              ),
              IconButton(
                icon: const Icon(Icons.settings),
                tooltip: 'Nastaveni',
                onPressed: () => Navigator.pushNamed(context, '/settings'),
              ),
              IconButton(
                icon: const Icon(Icons.logout),
                tooltip: 'Odhlasit',
                onPressed: () async {
                  await _auth.signOut();
                  Navigator.pushReplacementNamed(context, '/');
                },
              ),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    Expanded(child: XPBar(xp: xp % 100, level: level)),
                    const SizedBox(width: 16),
                    Column(
                      children: [
                        const Text('Mince', style: TextStyle(fontSize: 16)),
                        Text('$coins',
                            style: const TextStyle(fontSize: 24)),
                      ],
                    ),
                  ],
                ),
              ),
              TableCalendar(
                firstDay: DateTime(2000),
                lastDay: DateTime(2100),
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                },
                calendarStyle: CalendarStyle(
                  defaultTextStyle: TextStyle(
                      color:
                          Theme.of(context).textTheme.bodyLarge?.color),
                  weekendTextStyle:
                      const TextStyle(color: Colors.redAccent),
                  outsideTextStyle:
                      const TextStyle(color: Colors.grey),
                  todayDecoration: BoxDecoration(
                    color: Colors.indigo.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  selectedDecoration: const BoxDecoration(
                    color: Colors.indigo,
                    shape: BoxShape.circle,
                  ),
                ),
                headerStyle: HeaderStyle(
                  titleTextStyle: TextStyle(
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  formatButtonVisible: false,
                  titleCentered: true,
                  leftChevronIcon: Icon(Icons.chevron_left,
                      color: Theme.of(context).iconTheme.color),
                  rightChevronIcon: Icon(Icons.chevron_right,
                      color: Theme.of(context).iconTheme.color),
                ),
              ),
              Expanded(
                child: StreamBuilder<List<Task>>(
                  stream: _taskService
                      .tasksForDate(_formatDate(_selectedDay)),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(
                          child: CircularProgressIndicator());
                    }
                    final tasks = snapshot.data!;
                    if (tasks.isEmpty) {
                      return const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inbox_outlined,
                                size: 64, color: Colors.grey),
                            SizedBox(height: 12),
                            Text('Zadne ukoly pro tento den.',
                                style: TextStyle(
                                    color: Colors.grey, fontSize: 16)),
                            SizedBox(height: 4),
                            Text('Klikni na + a pridej novy ukol!',
                                style: TextStyle(
                                    color: Colors.grey, fontSize: 13)),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: tasks.length,
                      itemBuilder: (context, index) {
                        return TaskCard(
                          task: tasks[index],
                          onDelete: () =>
                              _taskService.deleteTask(tasks[index].id),
                          onEdit: () =>
                              _showEditTaskDialog(tasks[index]),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
          floatingActionButton: _isDayInPast(_selectedDay)
              ? null
              : FloatingActionButton(
                  child: const Icon(Icons.add),
                  onPressed: () => _showAddTaskDialog(uid),
                ),
        );
      },
    );
  }

  void _showAddTaskDialog(String uid) {
    _titleController.clear();
    _selectedType = TaskType.daily;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Novy ukol',
                style: TextStyle(fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Co chces splnit?',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.edit),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<TaskType>(
                  initialValue: _selectedType,
                  decoration: const InputDecoration(
                    labelText: 'Typ ukolu',
                    border: OutlineInputBorder(),
                  ),
                  items: TaskType.values.map((TaskType type) {
                    String label = '';
                    switch (type) {
                      case TaskType.daily:
                        label = 'Denni';
                      case TaskType.weekly:
                        label = 'Tydenni';
                      case TaskType.monthly:
                        label = 'Mesicni';
                    }
                    return DropdownMenuItem(
                        value: type, child: Text(label));
                  }).toList(),
                  onChanged: (val) =>
                      setDialogState(() => _selectedType = val!),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Zrusit'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  _addTask();
                },
                child: const Text('Vytvorit ukol'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditTaskDialog(Task task) {
    final editController = TextEditingController(text: task.title);
    TaskType editType = task.type;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Upravit ukol',
                style: TextStyle(fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: editController,
                  decoration: const InputDecoration(
                    labelText: 'Nazev ukolu',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.edit),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<TaskType>(
                  initialValue: editType,
                  decoration: const InputDecoration(
                    labelText: 'Typ ukolu',
                    border: OutlineInputBorder(),
                  ),
                  items: TaskType.values.map((TaskType type) {
                    String label = '';
                    switch (type) {
                      case TaskType.daily:
                        label = 'Denni';
                      case TaskType.weekly:
                        label = 'Tydenni';
                      case TaskType.monthly:
                        label = 'Mesicni';
                    }
                    return DropdownMenuItem(
                        value: type, child: Text(label));
                  }).toList(),
                  onChanged: (val) =>
                      setDialogState(() => editType = val!),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Zrusit'),
              ),
              FilledButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await _taskService.updateTask(
                    task.id,
                    title: editController.text.trim(),
                    type: editType,
                  );
                  editController.dispose();
                },
                child: const Text('Ulozit'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _addTask() async {
    String title = _titleController.text.trim();
    if (title.isEmpty) return;

    DateTime selected =
        DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day);

    await _taskService.createTask(
      title: title,
      type: _selectedType,
      date: _formatDate(selected),
    );
  }
}
