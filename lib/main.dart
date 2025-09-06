import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'db.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HSETrackerApp());
}

class HSETrackerApp extends StatelessWidget {
  const HSETrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HSE Tracker',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.teal,
      ),
      home: const PinGate(),
    );
  }
}

class PinGate extends StatefulWidget {
  const PinGate({super.key});
  @override
  State<PinGate> createState() => _PinGateState();
}

class _PinGateState extends State<PinGate> {
  final ctrl = TextEditingController();
  String? _err;
  String pin = '1234';

  @override
  void initState() {
    super.initState();
    _loadPin();
  }

  Future<void> _loadPin() async {
    final sp = await SharedPreferences.getInstance();
    setState(() => pin = sp.getString('app_pin') ?? '1234');
  }

  void _check() {
    if (ctrl.text == pin) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
    } else {
      setState(() => _err = 'Wrong PIN / गलत पिन');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('HSE Tracker', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                const Text('Enter PIN / पिन दर्ज करें'),
                const SizedBox(height: 8),
                TextField(
                  controller: ctrl,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    labelText: 'PIN',
                    errorText: _err,
                  ),
                  onSubmitted: (_) => _check(),
                ),
                const SizedBox(height: 12),
                FilledButton(onPressed: _check, child: const Text('Unlock / अनलॉक')),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (context) => const PinChangeDialog(),
                    );
                    if (ok == true && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PIN updated')));
                    }
                  },
                  child: const Text('Change PIN / पिन बदलें'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PinChangeDialog extends StatefulWidget {
  const PinChangeDialog({super.key});
  @override
  State<PinChangeDialog> createState() => _PinChangeDialogState();
}

class _PinChangeDialogState extends State<PinChangeDialog> {
  final oldCtrl = TextEditingController();
  final newCtrl = TextEditingController();
  String? err;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Change PIN / पिन बदलें'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: oldCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Old PIN', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          TextField(controller: newCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'New PIN', border: OutlineInputBorder())),
          if (err != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(err!, style: const TextStyle(color: Colors.red))),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(
          onPressed: () async {
            final sp = await SharedPreferences.getInstance();
            final current = sp.getString('app_pin') ?? '1234';
            if (oldCtrl.text != current) {
              setState(() => err = 'Old PIN incorrect');
              return;
            }
            if (newCtrl.text.length < 4) {
              setState(() => err = 'PIN must be at least 4 digits');
              return;
            }
            await sp.setString('app_pin', newCtrl.text);
            if (context.mounted) Navigator.pop(context, true);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;
  final pages = const [
    AttendanceScreen(),
    WorkersScreen(),
    ShiftsScreen(),
    WagesScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('HSE Tracker')),
      body: pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.event_available), label: 'Attendance / उपस्थिति'),
          NavigationDestination(icon: Icon(Icons.people), label: 'Workers / कर्मचारी'),
          NavigationDestination(icon: Icon(Icons.schedule), label: 'Shifts / शिफ्ट'),
          NavigationDestination(icon: Icon(Icons.payments), label: 'Wages / वेतन'),
        ],
      ),
    );
  }
}

final df = DateFormat('yyyy-MM-dd');

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  DateTime selectedDate = DateTime.now();
  int? selectedWorkerId;
  int? selectedShiftId;
  final hoursCtrl = TextEditingController();
  final notesCtrl = TextEditingController();

  List<Map<String, Object?>> workers = [];
  List<Map<String, Object?>> shifts = [];
  List<Map<String, Object?>> todays = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final w = await DB().query('workers', where: 'active = 1', orderBy: 'name');
    final s = await DB().query('shifts', orderBy: 'name');
    final t = await DB().query('attendance',
        where: 'date = ?', whereArgs: [df.format(selectedDate)], orderBy: 'id DESC');
    setState(() {
      workers = w;
      shifts = s;
      todays = t;
    });
  }

  Future<void> _save() async {
    if (selectedWorkerId == null || selectedShiftId == null) return;
    final data = {
      'date': df.format(selectedDate),
      'worker_id': selectedWorkerId,
      'shift_id': selectedShiftId,
      'hours_override': hoursCtrl.text.isEmpty ? null : double.tryParse(hoursCtrl.text),
      'notes': notesCtrl.text.isEmpty ? null : notesCtrl.text,
    };
    await DB().insert('attendance', data);
    hoursCtrl.clear();
    notesCtrl.clear();
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved / सेव किया गया')));
    }
  }

  Future<double> _computeLineAmount(Map<String, Object?> row) async {
    final s = (await DB().query('shifts', where: 'id = ?', whereArgs: [row['shift_id']])).first;
    final w = (await DB().query('workers', where: 'id = ?', whereArgs: [row['worker_id']])).first;
    final hours = (row['hours_override'] as num?)?.toDouble() ?? (s['default_hours'] as num).toDouble();
    final rate = (w['custom_rate'] as num?)?.toDouble() ?? (s['hourly_rate'] as num).toDouble();
    return hours * rate;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: ListView(
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Date / तारीख: ${df.format(selectedDate)}', style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              FilledButton.tonal(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                    initialDate: selectedDate,
                  );
                  if (picked != null) {
                    setState(() => selectedDate = picked);
                    _load();
                  }
                },
                child: const Text('Change / बदलें'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            decoration: const InputDecoration(labelText: 'Worker / कर्मचारी', border: OutlineInputBorder()),
            value: selectedWorkerId,
            items: workers.map((w) => DropdownMenuItem<int>(
              value: w['id'] as int, child: Text((w['name'] as String)),
            )).toList(),
            onChanged: (v) => setState(() => selectedWorkerId = v),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            decoration: const InputDecoration(labelText: 'Shift / शिफ्ट', border: OutlineInputBorder()),
            value: selectedShiftId,
            items: shifts.map((s) => DropdownMenuItem<int>(
              value: s['id'] as int, child: Text("${s['name']} (${s['default_hours']}h @ ₹${s['hourly_rate']})"),
            )).toList(),
            onChanged: (v) => setState(() => selectedShiftId = v),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: hoursCtrl,
            decoration: const InputDecoration(labelText: 'Hours (optional) / घंटे (वैकल्पिक)', border: OutlineInputBorder()),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: notesCtrl,
            decoration: const InputDecoration(labelText: 'Notes / नोट्स', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: _save, child: const Text('Save Attendance / उपस्थिति सेव करें')),
          const SizedBox(height: 16),
          const Text('Today\'s Entries / आज की एंट्री', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...todays.map((row) => FutureBuilder<double>(
            future: _computeLineAmount(row),
            builder: (context, snap) {
              final amt = snap.data;
              final worker = workers.firstWhere((w) => w['id'] == row['worker_id'], orElse: () => {'name':'Worker'});
              final shift = shifts.firstWhere((s) => s['id'] == row['shift_id'], orElse: () => {'name':'Shift'});
              return Card(
                child: ListTile(
                  title: Text('${worker['name']} — ${shift['name']}'),
                  subtitle: Text('Hours/घंटे: ${row['hours_override'] ?? 'default'}  Notes: ${row['notes'] ?? ''}'),
                  trailing: Text(amt == null ? '₹...' : '₹${amt.toStringAsFixed(2)}'),
                ),
              );
            },
          )),
        ],
      ),
    );
  }
}

class WorkersScreen extends StatefulWidget {
  const WorkersScreen({super.key});
  @override
  State<WorkersScreen> createState() => _WorkersScreenState();
}

class _WorkersScreenState extends State<WorkersScreen> {
  List<Map<String, Object?>> workers = [];
  final nameCtrl = TextEditingController();
  final roleCtrl = TextEditingController();
  final customRateCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final w = await DB().query('workers', orderBy: 'active DESC, name ASC');
    setState(() => workers = w);
  }

  Future<void> _save() async {
    if (nameCtrl.text.trim().isEmpty) return;
    await DB().insert('workers', {
      'name': nameCtrl.text.trim(),
      'role': roleCtrl.text.trim(),
      'active': 1,
      'custom_rate': customRateCtrl.text.isEmpty ? null : double.tryParse(customRateCtrl.text),
    });
    nameCtrl.clear(); roleCtrl.clear(); customRateCtrl.clear();
    _load();
  }

  Future<void> _toggleActive(Map<String, Object?> w) async {
    await DB().update('workers', {'active': (w['active'] as int) == 1 ? 0 : 1}, where: 'id = ?', whereArgs: [w['id']]);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          TextField(decoration: const InputDecoration(labelText: 'Name / नाम', border: OutlineInputBorder()), controller: nameCtrl),
          const SizedBox(height: 8),
          TextField(decoration: const InputDecoration(labelText: 'Role / भूमिका', border: OutlineInputBorder()), controller: roleCtrl),
          const SizedBox(height: 8),
          TextField(decoration: const InputDecoration(labelText: 'Custom hourly rate (₹) / कस्टम दर', border: OutlineInputBorder()), controller: customRateCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true)),
          const SizedBox(height: 8),
          FilledButton(onPressed: _save, child: const Text('Add Worker / कर्मचारी जोड़ें')),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              itemCount: workers.length,
              itemBuilder: (context, i) {
                final w = workers[i];
                return Card(
                  child: ListTile(
                    title: Text('${w['name']}'),
                    subtitle: Text('Role: ${w['role'] ?? ''}  •  Custom ₹: ${w['custom_rate'] ?? '-'}'),
                    trailing: IconButton(
                      icon: Icon((w['active'] as int) == 1 ? Icons.toggle_on : Icons.toggle_off),
                      onPressed: () => _toggleActive(w),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class ShiftsScreen extends StatefulWidget {
  const ShiftsScreen({super.key});
  @override
  State<ShiftsScreen> createState() => _ShiftsScreenState();
}

class _ShiftsScreenState extends State<ShiftsScreen> {
  List<Map<String, Object?>> shifts = [];
  final nameCtrl = TextEditingController();
  final startCtrl = TextEditingController();
  final endCtrl = TextEditingController();
  final hoursCtrl = TextEditingController();
  final rateCtrl = TextEditingController();
  final notesCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await DB().query('shifts', orderBy: 'name');
    setState(() => shifts = s);
  }

  Future<void> _save() async {
    if (nameCtrl.text.trim().isEmpty) return;
    await DB().insert('shifts', {
      'name': nameCtrl.text.trim(),
      'start_time': startCtrl.text.trim(),
      'end_time': endCtrl.text.trim(),
      'default_hours': double.tryParse(hoursCtrl.text) ?? 0,
      'hourly_rate': double.tryParse(rateCtrl.text) ?? 0,
      'notes': notesCtrl.text.trim(),
    });
    nameCtrl.clear(); startCtrl.clear(); endCtrl.clear(); hoursCtrl.clear(); rateCtrl.clear(); notesCtrl.clear();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          TextField(decoration: const InputDecoration(labelText: 'Shift name / शिफ्ट नाम', border: OutlineInputBorder()), controller: nameCtrl),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: TextField(decoration: const InputDecoration(labelText: 'Start (HH:MM) / शुरू', border: OutlineInputBorder()), controller: startCtrl)),
            const SizedBox(width: 8),
            Expanded(child: TextField(decoration: const InputDecoration(labelText: 'End (HH:MM) / खत्म', border: OutlineInputBorder()), controller: endCtrl)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: TextField(decoration: const InputDecoration(labelText: 'Default hours / डिफ़ॉल्ट घंटे', border: OutlineInputBorder()), controller: hoursCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true))),
            const SizedBox(width: 8),
            Expanded(child: TextField(decoration: const InputDecoration(labelText: 'Hourly rate (₹) / प्रति घंटा दर', border: OutlineInputBorder()), controller: rateCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true))),
          ]),
          const SizedBox(height: 8),
          TextField(decoration: const InputDecoration(labelText: 'Notes / नोट्स', border: OutlineInputBorder()), controller: notesCtrl),
          const SizedBox(height: 8),
          FilledButton(onPressed: _save, child: const Text('Add/Update Shift / शिफ्ट जोड़ें/अपडेट करें')),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              itemCount: shifts.length,
              itemBuilder: (context, i) {
                final s = shifts[i];
                return Card(
                  child: ListTile(
                    title: Text('${s['name']} — ${s['default_hours']}h @ ₹${s['hourly_rate']}'),
                    subtitle: Text('Time: ${s['start_time'] ?? ''}-${s['end_time'] ?? ''}  |  ${s['notes'] ?? ''}'),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class WagesScreen extends StatefulWidget {
  const WagesScreen({super.key});
  @override
  State<WagesScreen> createState() => _WagesScreenState();
}

class _WagesScreenState extends State<WagesScreen> {
  DateTime weekStart = _mondayOf(DateTime.now());
  List<Map<String, Object?>> rows = [];
  final amountCtrl = TextEditingController();
  int? selectedWorkerId;
  String method = 'Cash';
  final methods = const ['Cash', 'UPI', 'Bank', 'Other'];

  static DateTime _mondayOf(DateTime d) {
    final diff = d.weekday - DateTime.monday;
    return DateTime(d.year, d.month, d.day).subtract(Duration(days: diff));
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final start = df.format(weekStart);
    final end = df.format(weekStart.add(const Duration(days: 6)));

    final data = await DB().rawQuery(r'''
      WITH att AS (
        SELECT a.worker_id,
               SUM( (COALESCE(a.hours_override, s.default_hours)) * (COALESCE(w.custom_rate, s.hourly_rate)) ) AS earned
        FROM attendance a
        JOIN shifts s ON s.id = a.shift_id
        JOIN workers w ON w.id = a.worker_id
        WHERE a.date BETWEEN ? AND ?
        GROUP BY a.worker_id
      ),
      pay AS (
        SELECT worker_id, SUM(amount) AS paid
        FROM payments
        WHERE date BETWEEN ? AND ?
        GROUP BY worker_id
      )
      SELECT w.id as worker_id, w.name,
             COALESCE(att.earned, 0) AS earned,
             COALESCE(pay.paid, 0) AS paid,
             COALESCE(att.earned, 0) - COALESCE(pay.paid, 0) AS balance
      FROM workers w
      LEFT JOIN att ON att.worker_id = w.id
      LEFT JOIN pay ON pay.worker_id = w.id
      WHERE w.active = 1
      ORDER BY w.name ASC
    ''', [start, end, start, end]);

    setState(() {
      rows = data;
    });
  }

  Future<void> _addPayment() async {
    if (selectedWorkerId == null || amountCtrl.text.isEmpty) return;
    final amt = double.tryParse(amountCtrl.text) ?? 0;
    await DB().insert('payments', {
      'date': df.format(DateTime.now()),
      'worker_id': selectedWorkerId,
      'amount': amt,
      'method': method,
      'notes': 'Weekly payment',
    });
    amountCtrl.clear();
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment recorded / भुगतान दर्ज')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final weekEnd = weekStart.add(const Duration(days: 6));
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Week / सप्ताह: ${df.format(weekStart)} → ${df.format(weekEnd)}', style: const TextStyle(fontWeight: FontWeight.bold))),
              IconButton(
                onPressed: () { setState(() => weekStart = weekStart.subtract(const Duration(days: 7))); _load(); },
                icon: const Icon(Icons.chevron_left),
                tooltip: 'Previous week / पिछला सप्ताह',
              ),
              IconButton(
                onPressed: () { setState(() => weekStart = weekStart.add(const Duration(days: 7))); _load(); },
                icon: const Icon(Icons.chevron_right),
                tooltip: 'Next week / अगला सप्ताह',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              children: rows.map((r) => Card(
                child: ListTile(
                  title: Text('${r['name']}'),
                  subtitle: Text('Earned/कमाया: ₹${(r['earned'] as num).toStringAsFixed(2)}  •  Paid/भुगतान: ₹${(r['paid'] as num).toStringAsFixed(2)}'),
                  trailing: Text('Balance/बाकी: ₹${(r['balance'] as num).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              )).toList(),
            ),
          ),
          const Divider(),
          const Text('Record a Payment / भुगतान दर्ज करें', style: TextStyle(fontWeight: FontWeight.bold)),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: FutureBuilder(
                  future: DB().query('workers', where: 'active = 1', orderBy: 'name'),
                  builder: (context, snapshot) {
                    final list = snapshot.data as List<Map<String, Object?>>? ?? [];
                    return DropdownButtonFormField<int>(
                      value: selectedWorkerId,
                      items: list.map((w) => DropdownMenuItem<int>(value: w['id'] as int, child: Text('${w['name']}'))).toList(),
                      onChanged: (v) => setState(() => selectedWorkerId = v),
                      decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Worker / कर्मचारी'),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: amountCtrl,
                  decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Amount (₹) / राशि'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: method,
                  items: const [
                    DropdownMenuItem(value: 'Cash', child: Text('Cash / नकद')),
                    DropdownMenuItem(value: 'UPI', child: Text('UPI')),
                    DropdownMenuItem(value: 'Bank', child: Text('Bank / बैंक')),
                    DropdownMenuItem(value: 'Other', child: Text('Other / अन्य')),
                  ],
                  onChanged: (v) => setState(() => method = v ?? 'Cash'),
                  decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Method / तरीका'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(onPressed: _addPayment, child: const Text('Add Payment / भुगतान जोड़ें')),
          ),
        ],
      ),
    );
  }
}
