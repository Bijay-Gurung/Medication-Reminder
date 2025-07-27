import 'package:flutter/material.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initializing Hive with proper path
  await Hive.initFlutter();
  await Hive.openBox('medication_reminders');

  // Initializing notifications
  await AwesomeNotifications().initialize(null, [
    NotificationChannel(
      channelKey: 'medication_reminder',
      channelName: 'Medication Reminders',
      channelDescription: 'Channel for medication reminders',
      importance: NotificationImportance.High,
      defaultColor: const Color(0xFF650424),
      ledColor: Colors.white,
      playSound: true,
      enableVibration: true,
    ),
  ]);

  // Request notification permissions
  await AwesomeNotifications().isNotificationAllowed().then((isAllowed) {
    if (!isAllowed) {
      AwesomeNotifications().requestPermissionToSendNotifications();
    }
  });

  // Configuring timezones
  tz_data.initializeTimeZones();
  try {
    final String timeZoneName = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timeZoneName));
    print('Configured timezone: $timeZoneName');
  } catch (e) {
    tz.setLocalLocation(tz.getLocation('UTC'));
    print("Error Setting timezone: $e");
  }

  // Printing current time to debug
  print('Current time: ${tz.TZDateTime.now(tz.local)}');

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 100, 26, 57),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 101, 4, 36),
        title: const Text(
          'Medication Reminder',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: Center(
        child: Column(
          children: [
            Container(
              height: 40,
              width: 500,
              margin: const EdgeInsets.fromLTRB(80, 50, 0, 0),
              child: const Text(
                "Don't forget to take your medicine!",
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
            Container(
              height: 180,
              width: 180,
              margin: const EdgeInsets.fromLTRB(0, 1, 20, 0),
              padding: const EdgeInsets.fromLTRB(0, 10, 20, 0),
              child: Image.asset(
                'assets/MedicineBox.png',
                height: 140,
                width: 140,
                fit: BoxFit.contain,
              ),
            ),
            Container(
              margin: const EdgeInsets.fromLTRB(0, 30, 30, 0),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 15,
                  ),
                ),
                child: const Text(
                  'Set Reminder',
                  style: TextStyle(
                    color: Color.fromARGB(255, 101, 4, 36),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const Details()),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class Details extends StatefulWidget {
  const Details({super.key});

  @override
  State<Details> createState() => _DetailsState();
}

class _DetailsState extends State<Details> {
  late Box myBox;
  List<Map<String, dynamic>> reminders = [];
  TimeOfDay? _selectedTime;

  final timeController = TextEditingController();
  final nameController = TextEditingController();
  final doseController = TextEditingController();

  @override
  void initState() {
    super.initState();
    myBox = Hive.box('medication_reminders');
    _loadReminders();
  }

  void _loadReminders() {
    final data = myBox.get("reminders");
    if (data is List) {
      reminders = data
          .whereType<Map>()
          .map((item) => item.map((key, value) => MapEntry(key.toString(), value)))
          .toList();
      print('Loaded ${reminders.length} reminders from Hive');
    } else {
      reminders = [];
      print('No reminders found in Hive');
    }
    _rescheduleAllNotifications();
  }

  void _saveReminders() {
    myBox.put("reminders", reminders);
    print('Saved ${reminders.length} reminders to Hive');
  }

  Future<void> _rescheduleAllNotifications() async {
    print('Rescheduling all notifications...');
    await AwesomeNotifications().cancelAllSchedules();

    for (var reminder in reminders) {
      if (reminder['hour'] != null &&
          reminder['minute'] != null &&
          reminder['name'] != null &&
          reminder['dose'] != null) {
        await _scheduleNotification(
          id: reminder['id'],
          hour: reminder['hour'],
          minute: reminder['minute'],
          name: reminder['name'],
          dose: reminder['dose'],
        );
      }
    }
  }

  Future<void> _scheduleNotification({
    required int id,
    required int hour,
    required int minute,
    required String name,
    required String dose,
  }) async {
    try {
      final now = tz.TZDateTime.now(tz.local);
      tz.TZDateTime scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );

      // If time passed, schedule for next day
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      print('Scheduling notification at $scheduledDate for $name');

      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: id,
          channelKey: 'medication_reminder',
          title: 'Medication Reminder',
          body: 'Time to take $name - Dose: $dose',
          payload: {'name': name, 'dose': dose},
        ),
        schedule: NotificationCalendar(
          timeZone: await FlutterTimezone.getLocalTimezone(),
          hour: hour,
          minute: minute,
          repeats: true,
        ),
      );
    } catch (e) {
      print('Error scheduling notification: $e');
    }
  }

  Future<void> addReminder() async {
    if (_selectedTime == null ||
        nameController.text.isEmpty ||
        doseController.text.isEmpty) {
      return;
    }

    // Check notification permission
    final isAllowed = await AwesomeNotifications().isNotificationAllowed();
    if (!isAllowed) {
      await AwesomeNotifications().requestPermissionToSendNotifications();
      return;
    }

    // Generate 32-bit compatible ID
    final int id = DateTime.now().millisecondsSinceEpoch % 2147483647;
    final newReminder = {
      'id': id,
      'hour': _selectedTime!.hour,
      'minute': _selectedTime!.minute,
      'timeString': timeController.text,
      'name': nameController.text,
      'dose': doseController.text,
    };

    setState(() {
      reminders.add(newReminder);
      _saveReminders();
    });

    await _scheduleNotification(
      id: id,
      hour: _selectedTime!.hour,
      minute: _selectedTime!.minute,
      name: nameController.text,
      dose: doseController.text,
    );

    nameController.clear();
    doseController.clear();
    timeController.clear();
    _selectedTime = null;
  }

  Future<void> deleteReminder(int index) async {
    final id = reminders[index]['id'];
    setState(() {
      reminders.removeAt(index);
      _saveReminders();
    });
    await AwesomeNotifications().cancel(id);
  }

  @override
  void dispose() {
    timeController.dispose();
    nameController.dispose();
    doseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 100, 26, 57),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 101, 4, 36),
        title: const Text(
          "Set Your Reminder",
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: Center(
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(0, 30, 0, 0),
              child: SizedBox(
                height: 60,
                width: 300,
                child: TextFormField(
                  controller: nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Medicine Name',
                    labelStyle: const TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: const BorderSide(color: Colors.white),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: const BorderSide(color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),

            Container(
              margin: const EdgeInsets.fromLTRB(0, 20, 0, 0),
              child: SizedBox(
                height: 60,
                width: 300,
                child: TextFormField(
                  controller: doseController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Number of Doses',
                    labelStyle: const TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: const BorderSide(color: Colors.white),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: const BorderSide(color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),

            Container(
              margin: const EdgeInsets.fromLTRB(0, 20, 0, 0),
              child: SizedBox(
                height: 60,
                width: 300,
                child: TextFormField(
                  readOnly: true,
                  controller: timeController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Select Time',
                    labelStyle: const TextStyle(color: Colors.white70),
                    suffixIcon: const Icon(
                      Icons.access_time,
                      color: Colors.white,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: const BorderSide(color: Colors.white),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: const BorderSide(color: Colors.white),
                    ),
                  ),
                  onTap: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.now(),
                      builder: (context, child) {
                        return Theme(data: ThemeData.dark(), child: child!);
                      },
                    );

                    if (time != null) {
                      setState(() {
                        _selectedTime = time;
                        timeController.text = time.format(context);
                        // timeController.text = "${time.hour}:${time.minute.toString().padLeft(2, '0')}";
                      });
                    }
                  },
                ),
              ),
            ),

            Container(
              margin: const EdgeInsets.fromLTRB(0, 30, 0, 0),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 15,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text(
                  'SET REMINDER',
                  style: TextStyle(
                    color: Color.fromARGB(255, 101, 4, 36),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: () async {
                  if (_selectedTime == null) {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        backgroundColor: const Color.fromARGB(255, 100, 26, 57),
                        title: const Text(
                          'Missing Time',
                          style: TextStyle(color: Colors.white),
                        ),
                        content: const Text(
                          'Please select a reminder time',
                          style: TextStyle(color: Colors.white70),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text(
                              'OK',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    );
                    return;
                  }

                  await addReminder();
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: const Color.fromARGB(255, 100, 26, 57),
                      content: const Text(
                        "Reminder Set Successfully",
                        style: TextStyle(color: Colors.white, fontSize: 18),
                      ),
                      actions: [
                        Center(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text(
                              'OK',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 30),
            const Text(
              'Your Reminders:',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(color: Colors.white54, indent: 50, endIndent: 50),

            Expanded(
              child: ListView.builder(
                itemCount: reminders.length,
                itemBuilder: (context, index) {
                  final reminder = reminders[index];
                  return Card(
                    color: const Color.fromARGB(255, 101, 4, 36),
                    margin: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    child: ListTile(
                      title: Text(
                        reminder['timeString'],
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        "${reminder['name']} - ${reminder['dose']} dose(s)",
                        style: const TextStyle(color: Colors.white70),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.white),
                        onPressed: () => deleteReminder(index),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}