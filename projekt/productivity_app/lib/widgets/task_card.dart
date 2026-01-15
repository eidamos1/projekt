import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/task.dart';

class TaskCard extends StatefulWidget {
  final Task task;
  const TaskCard({super.key, required this.task});

  @override
  State<TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<TaskCard> {
  bool _isProcessing = false;

  Color _getTypeColor(TaskType type) {
    switch (type) {
      case TaskType.daily: return Colors.blueAccent;
      case TaskType.weekly: return Colors.orangeAccent;
      case TaskType.monthly: return Colors.purpleAccent;
    }
  }

  Future<void> _savePhoto() async {
    final picker = ImagePicker();
    
    // Změna: Na webu je lepší použít Gallery, protože 'Camera' nemusí být v prohlížeči spolehlivá.
    // Ale ImageSource.camera by mělo fungovat (otevře to webkameru nebo výběr souboru).
    final XFile? image = await picker.pickImage(
      source: ImageSource.camera, 
      maxWidth: 500, // Zmenšeno na 500px (bezpečné pro limit 1MB)
      imageQuality: 40, // Kvalita 40%
    );

    if (image == null) return;
    
    setState(() => _isProcessing = true);

    try {
      // KLÍČOVÁ OPRAVA PRO WEB:
      // Místo File(image.path).readAsBytes() musíme použít přímo image.readAsBytes()
      final bytes = await image.readAsBytes();
      
      // Kontrola velikosti (Firestore limit je 1MB, Base64 přidá 33%)
      // Takže bajty musí být menší než cca 750kB.
      if (bytes.lengthInBytes > 750000) {
        throw Exception("Obrázek je i po zmenšení moc velký. Zkus jiný.");
      }

      String base64Image = base64Encode(bytes);
      final uid = FirebaseAuth.instance.currentUser!.uid;
      
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('tasks')
          .doc(widget.task.id)
          .update({'imageBase64': base64Image});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Důkaz uložen!')));
      }
    } catch (e) {
      print("Chyba nahrávání: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chyba: ${e.toString().replaceAll("Exception:", "")}'))
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _shareTask() {
    if (widget.task.imageBase64 == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Musíš nejdřív vyfotit důkaz! 📸'), backgroundColor: Colors.red),
      );
      return;
    }

    // Odkazy pro sdílení
    String mobileLink = 'adamapp://confirm?code=${widget.task.code}';

    String webLink = 'https://calendar-mot.web.app/#/confirm?code=${widget.task.code}';

    Share.share(
      'Čau! Mám hotovo: "${widget.task.title}".\n'
      'Koukni na fotku v appce a potvrď mi to!\n\n'
      '📱 V aplikaci: $mobileLink\n'
      '💻 Na webu: $webLink'
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isFullyCompleted = widget.task.completed;
    bool isPending = widget.task.imageBase64 != null && !isFullyCompleted;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    final subTextColor = Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black;
    return Card(
      color: isFullyCompleted ? Theme.of(context).cardColor.withOpacity(0.6) : Theme.of(context).cardColor,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      elevation: 4,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border(left: BorderSide(color: isFullyCompleted ? Colors.green : _getTypeColor(widget.task.type), width: 5)),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.task.title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, decoration: isFullyCompleted ? TextDecoration.lineThrough : null, color: isFullyCompleted ? Colors.green : textColor,decorationColor: isFullyCompleted ? Colors.grey : textColor)),
            const SizedBox(height: 4),
            Text('${widget.task.typeLabel} • ${widget.task.xp} XP • ${widget.task.coins} Mincí', style: TextStyle(color: isFullyCompleted ? Colors.grey : subTextColor, fontSize: 12)),
            
            // --- STAV ÚKOLU ---
            if (isFullyCompleted)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Row(children: const [
                  Icon(Icons.verified, size: 20, color: Colors.green),
                  SizedBox(width: 4), 
                  Text("Potvrzeno & Splněno", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))
                ]),
              )
            else if (isPending)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Row(children: const [
                  Icon(Icons.hourglass_top, size: 20, color: Colors.orange),
                  SizedBox(width: 4), 
                  Text("Čeká na potvrzení kamarádem", style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold))
                ]),
              ),

            if (widget.task.imageBase64 != null) ...{
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Row(children: const [
                  Icon(Icons.image, size: 20, color: Colors.green), 
                  SizedBox(width: 4), 
                  Text("Důkaz připojen", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))
                ]),
              ),
              SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                  base64Decode(widget.task.imageBase64!),
                  height: 200,
                  width: 200,
                  fit: BoxFit.cover,
                ),
              ),
              
            },


// Ovládací tlačítka (skryjeme, pokud je už hotovo/verified)
            if (!isFullyCompleted) ...[
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _isProcessing
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : TextButton.icon(
                      onPressed: _savePhoto,
                      // Pokud má fotku, tlačítko je "Přefotit", jinak "Vyfotit"
                      icon: Icon(Icons.camera_alt, color: textColor),
                      label: Text(widget.task.imageBase64 == null ? "Vyfotit důkaz" : "Změnit fotku", style: TextStyle(color: textColor)),
                    ),
                  
                  // Tlačítko sdílet je aktivní jen když máme fotku
                  ElevatedButton.icon(
                    onPressed: widget.task.imageBase64 != null ? _shareTask : null,
                    icon: const Icon(Icons.send),
                    label: const Text("Potvrdit"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _getTypeColor(widget.task.type), 
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.withOpacity(0.3)
                    ),
                  ),
                ],
              )
            ],
            
          ],
        ),
      ),
    );
  }
}