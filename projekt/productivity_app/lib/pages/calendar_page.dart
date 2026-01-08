// pages/calendar_page.dart
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
  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();

  // Deklarace controllerů pro pole formuláře nového úkolu
  final TextEditingController _titleController = TextEditingController();
  String _selectedType = 'Denní';

  // Pomocná funkce pro formát data do 'yyyy-MM-dd'
  String _formatDate(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  @override
  Widget build(BuildContext context) {
    // Získání aktuálního uživatele
    final user = _auth.currentUser!;
    final uid = user.uid;

    // StreamBuilder pro čtení dat uživatele (XP, coins, level)
    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection('users').doc(uid).snapshots(),
      builder: (context, snapshot) {
        int xp = 0, coins = 0, level = 1;
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          xp = data['xp'] ?? 0;
          coins = data['coins'] ?? 0;
          level = data['level'] ?? 1;
        }
        // Stavba celé stránky
        return Scaffold(
          appBar: AppBar(
            title: Text('Můj kalendář'),
            actions: [
              IconButton(
                icon: Icon(Icons.task_alt),
                tooltip: 'Potvrdit kód',
                onPressed: () {
                  Navigator.pushNamed(context, '/confirm');
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
              // Horní panel: XP bar a mince
              Padding(
                padding: EdgeInsets.all(8),
                child: Row(
                  children: [
                    Expanded(child: XPBar(xp: xp, level: level)),
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
              // Kalendář
              TableCalendar(
                firstDay: DateTime(2000),
                lastDay: DateTime(2100),
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) {
                  return isSameDay(_selectedDay, day);
                },
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                },
              ),
              // Seznam úkolů pro vybraný den
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _firestore
                      .collection('users')
                      .doc(uid)
                      .collection('tasks')
                      .where('date', isEqualTo: _formatDate(_selectedDay))
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return Center(child: CircularProgressIndicator());
                    }
                    final docs = snapshot.data!.docs;
                    if (docs.isEmpty) {
                      return Center(child: Text('Žádné úkoly pro tento den.'));
                    }
                    // Vytvoření seznamu karet úkolů
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
          // Tlačítko pro přidání nového úkolu
          floatingActionButton: FloatingActionButton(
            child: Icon(Icons.add),
            onPressed: () {
              _showAddTaskDialog(uid);
            },
          ),
        );
      },
    );
  }

  // Dialog pro přidání nového úkolu
  void _showAddTaskDialog(String uid) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Nový úkol'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Název úkolu
            TextField(
              controller: _titleController,
              decoration: InputDecoration(labelText: 'Název úkolu'),
            ),
            SizedBox(height: 10),
            // Typ úkolu (Denní, Týdenní, Měsíční)
            DropdownButton<String>(
              value: _selectedType,
              items: ['Denní', 'Týdenní', 'Měsíční']
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (val) => setState(() {
                _selectedType = val!;
              }),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _titleController.clear();
              _selectedType = 'Denní';
            },
            child: Text('Zrušit'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _addTask(uid);
              _titleController.clear();
              _selectedType = 'Denní';
            },
            child: Text('Přidat'),
          ),
        ],
      ),
    );
  }

  // Funkce pro přidání úkolu do Firestore
 Future<void> _addTask(String uid) async {
  String title = _titleController.text.trim();
  if (title.isEmpty) return;

  DateTime today = DateTime.now();
  DateTime selected = DateTime(
    _selectedDay.year,
    _selectedDay.month,
    _selectedDay.day,
  );

  if (selected.isBefore(DateTime(today.year, today.month, today.day))) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Nelze přidat úkol do minulosti')),
    );
    return;
  }

  int xp = 10;
  int coins = 5;

  if (_selectedType == 'Týdenní') {
    xp = 25;
    coins = 10;
  } else if (_selectedType == 'Měsíční') {
    xp = 60;
    coins = 25;
  }

  final random = Random();
  String code = (100000 + random.nextInt(900000)).toString();

  await _firestore
      .collection('users')
      .doc(uid)
      .collection('tasks')
      .add({
    'title': title,
    'type': _selectedType,
    'date': _formatDate(selected),
    'xp': xp,
    'coins': coins,
    'code': code,
    'completed': false,
  });
}
}