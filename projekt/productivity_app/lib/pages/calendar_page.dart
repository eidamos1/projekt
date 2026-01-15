// pages/calendar_page.dart
// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import '../models/task.dart';
import '../widgets/task_card.dart';
import '../widgets/xp_bar.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  final TextEditingController _titleController = TextEditingController();
  TaskType _selectedType = TaskType.daily; // Změna na Enum

  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();

  // Deklarace controllerů pro pole formuláře nového úkolu

  // Pomocná funkce pro formát data do 'yyyy-MM-dd'
  String _formatDate(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }
  // Funkce zjistí, jestli je vybraný den včera nebo dříve (bez času)
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
        int xp = 0, coins = 0, level = 1;
        String nickname = 'Hráč';
        String? photoUrl; // Proměnná pro fotku

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          xp = data['xp'] ?? 0;
          coins = data['coins'] ?? 0;
          level = data['level'] ?? 1;
          nickname = data['nickname'] ?? 'Hráč';
          photoUrl = data['photoUrl']; // Načtení URL fotky
        }

        return Scaffold(
          appBar: AppBar(
            // --- ZMĚNA: Titulek s fotkou a jménem ---
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
                      style: TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold),
                    ),
                  ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    nickname,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ],
            ),
            // ----------------------------------------
            actions: [
              IconButton(
                icon: Icon(Icons.task_alt),
                tooltip: 'Potvrdit kód',
                onPressed: () {
                  Navigator.pushNamed(context, '/confirm');
                },
              ),
              IconButton(
                icon: Icon(Icons.settings),
                tooltip: 'Nastavení',
                onPressed: () {
                  Navigator.pushNamed(context, '/settings');
                },
              ),
              IconButton(
                icon: Icon(Icons.logout),
                tooltip: 'Odhlásit',
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
                padding: EdgeInsets.all(8),
                child: Row(
                  children: [
                    Expanded(child: XPBar(xp: xp % 100, level: level)),
                    SizedBox(width: 16),
                    Column(
                      children: [
                        Text('Mince', style: TextStyle(fontSize: 16)),
                        Text('$coins', style: TextStyle(fontSize: 24)),
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
                  defaultTextStyle: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
                  weekendTextStyle: TextStyle(color: Colors.redAccent),
                  outsideTextStyle: TextStyle(color: Colors.grey),

                  todayDecoration: BoxDecoration(
                    color: Colors.indigo.withOpacity( 0.5),
                    shape: BoxShape.circle,
                  ),
                  selectedDecoration: BoxDecoration(
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
                  leftChevronIcon: Icon(Icons.chevron_left, color: Theme.of(context).iconTheme.color),
                  rightChevronIcon: Icon(Icons.chevron_right, color: Theme.of(context).iconTheme.color),
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _firestore
                      .collection('users')
                      .doc(uid)
                      .collection('tasks')
                      .where('date', isEqualTo: _formatDate(_selectedDay))
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
                    final docs = snapshot.data!.docs;
                    if (docs.isEmpty) return Center(child: Text('Žádné úkoly pro tento den.'));
                    
                    return ListView.builder(
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        Task task = Task.fromMap(
                            docs[index].id, docs[index].data() as Map<String, dynamic>);
                        return TaskCard(task: task);
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
            child: Icon(Icons.add),
            onPressed: () => _showAddTaskDialog(uid),
          ),
        );
      },
    );
  }
  // Dialog pro přidání nového úkolu
void _showAddTaskDialog(String uid) {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder( // StatefulBuilder aby se dropdown překreslil
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text('Nový úkol', style: TextStyle(fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: 'Co chceš splnit?',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.edit),
                  ),
                ),
                SizedBox(height: 16),
                DropdownButtonFormField<TaskType>(
                  initialValue: _selectedType,
                  decoration: InputDecoration(
                    labelText: 'Typ úkolu',
                    border: OutlineInputBorder(),
                  ),
                  items: TaskType.values.map((TaskType type) {
                    // Převedeme Enum na hezký text
                    String label = '';
                    switch (type) {
                      case TaskType.daily: label = 'Denní (+XP/Coins)'; break;
                      case TaskType.weekly: label = 'Týdenní (Větší odměna)'; break;
                      case TaskType.monthly: label = 'Měsíční (Epická odměna)'; break;
                    }
                    return DropdownMenuItem(value: type, child: Text(label));
                  }).toList(),
                  onChanged: (val) => setDialogState(() {
                    _selectedType = val!;
                  }),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Zrušit'),
              ),
              FilledButton( // Modernější tlačítko
                onPressed: () {
                  Navigator.pop(context);
                  _addTask(uid);
                  _titleController.clear();
                  _selectedType = TaskType.daily;
                },
                child: Text('Vytvořit úkol'),
              ),
            ],
          );
        }
      ),
    );
  }

  Future<void> _addTask(String uid) async {
    String title = _titleController.text.trim();
    if (title.isEmpty) return;

    // ... logika data zůstává stejná ...
    DateTime selected = DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day);
    // ...

    int xp = 10;
    int coins = 5;

    // Logika odměn podle Enumu
    switch (_selectedType) {
      case TaskType.daily:
        xp = 10; coins = 5; break;
      case TaskType.weekly:
        xp = 50; coins = 20; break; // Zvýšil jsem odměny pro motivaci :)
      case TaskType.monthly:
        xp = 200; coins = 100; break;
    }

    final random = Random();
    String code = (100000 + random.nextInt(900000)).toString();

    // Vytvoření objektu Task (používáme toMap metodu modelu)
    Task newTask = Task(
      id: '', // ID vygeneruje Firestore
      title: title,
      type: _selectedType,
      date: _formatDate(selected),
      xp: xp,
      coins: coins,
      code: code,
    );

    await _firestore
        .collection('users')
        .doc(uid)
        .collection('tasks')
        .add(newTask.toMap()); // Použití metody toMap pro čistší kód
  }
}