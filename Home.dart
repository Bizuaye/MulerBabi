import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';
import '../models/drug.dart';
import '../models/customer.dart';
import 'add_edit_screen.dart';
import 'customer_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  List<Drug> _drugs = [];
  List<Drug> _filtered = [];
  List<Customer> _customers = [];
  Map<int, double> _balances = {};
  final _searchCtrl = TextEditingController();
  int _filter = 0;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(() => setState(() {}));
    _load();
  }

  Future<void> _load() async {
    final list = await DBHelper.instance.getAllDrugs();
    final customers = await DBHelper.instance.getAllCustomers();
    final balances = await DBHelper.instance.getAllBalances();
    setState(() {
      _drugs = list;
      _customers = customers;
      _balances = balances;
      _applyFilter();
    });
  }

  void _applyFilter() {
    final q = _searchCtrl.text.toLowerCase();
    List<Drug> base = _drugs;
    if (_filter == 1) base = base.where((d) => d.isExpired).toList();
    if (_filter == 2) base = base.where((d) => d.isExpiringSoon).toList();
    if (_filter == 3) base = base.where((d) => d.quantity <= 10).toList();
    if (q.isNotEmpty) {
      base = base.where((d) =>
          d.name.toLowerCase().contains(q) ||
          d.category.toLowerCase().contains(q) ||
          d.supplier.toLowerCase().contains(q) ||
          d.batchNumber.toLowerCase().contains(q)).toList();
    }
    _filtered = base;
  }

  Future<void> _delete(Drug d) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete drug?'),
        content: Text('Remove "${d.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) { await DBHelper.instance.deleteDrug(d.id!); _load(); }
  }

  Color _statusColor(Drug d) =>
      d.isExpired ? Colors.red : (d.isExpiringSoon ? Colors.orange : Colors.green);
  String _statusText(Drug d) =>
      d.isExpired ? 'EXPIRED ${-d.daysToExpiry}d ago'
      : (d.isExpiringSoon ? 'Expires in ${d.daysToExpiry}d' : 'OK');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vet Wholesale'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.medical_services), text: 'Inventory'),
            Tab(icon: Icon(Icons.people), text: 'Customers'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [_buildInventoryTab(), _buildCustomersTab()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text(_tabCtrl.index == 0 ? 'Add Drug' : 'Add Customer'),
        onPressed: () async {
          if (_tabCtrl.index == 0) {
            await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddEditScreen()));
          } else {
            await Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomerScreen()));
          }
          _load();
        },
      ),
    );
  }

  Widget _buildInventoryTab() {
    final totalCost = _drugs.fold<double>(0, (s, d) => s + d.totalCostValue);
    final totalSell = _drugs.fold<double>(0, (s, d) => s + d.totalSellingValue);
    final totalProfit = _drugs.fold<double>(0, (s, d) => s + d.totalProfit);
    final expired = _drugs.where((d) => d.isExpired).length;
    final expSoon = _drugs.where((d) => d.isExpiringSoon).length;

    return Column(children: [
      Container(
        color: Colors.teal.shade50,
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          _kpi('Cost', '\$${totalCost.toStringAsFixed(0)}', Colors.blueGrey),
          _kpi('Value', '\$${totalSell.toStringAsFixed(0)}', Colors.blue),
          _kpi('Profit', '\$${totalProfit.toStringAsFixed(0)}', Colors.green),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.all(8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _chip('All (${_drugs.length})', 0, Colors.teal),
            _chip('Expired ($expired)', 1, Colors.red),
            _chip('Soon ($expSoon)', 2, Colors.orange),
            _chip('Low Stock', 3, Colors.purple),
          ]),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: TextField(
          controller: _searchCtrl,
          onChanged: (_) => setState(_applyFilter),
          decoration: InputDecoration(
            hintText: 'Search...',
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            isDense: true,
          ),
        ),
      ),
      const SizedBox(height: 8),
      Expanded(
        child: _filtered.isEmpty
            ? const Center(child: Text('No drugs. Tap + to add.'))
            : ListView.builder(
                itemCount: _filtered.length,
                itemBuilder: (_, i) {
                  final d = _filtered[i];
                  final df = DateFormat('yyyy-MM-dd');
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _statusColor(d).withOpacity(0.15),
                        child: Icon(Icons.medical_services, color: _statusColor(d)),
                      ),
                      title: Text(d.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${d.category} • ${d.batchNumber}'),
                        Text('Qty: ${d.quantity} • Cost: \$${d.costPrice.toStringAsFixed(2)} • Sell: \$${d.sellingPrice.toStringAsFixed(2)}'),
                        Text(
                          'Profit/unit: \$${d.profitPerUnit.toStringAsFixed(2)} (${d.profitMargin.toStringAsFixed(0)}%)${d.isLoss ? " ⚠ LOSS" : ""}',
                          style: TextStyle(
                            color: d.isLoss ? Colors.red : Colors.green,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text('Exp: ${df.format(d.expiry)} • ${_statusText(d)}',
                            style: TextStyle(color: _statusColor(d), fontSize: 12)),
                      ]),
                      isThreeLine: true,
                      trailing: PopupMenuButton<String>(
                        onSelected: (v) async {
                          if (v == 'edit') {
                            await Navigator.push(context,
                                MaterialPageRoute(builder: (_) => AddEditScreen(drug: d)));
                            _load();
                          } else if (v == 'delete') _delete(d);
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'edit', child: Text('Edit')),
                          PopupMenuItem(value: 'delete', child: Text('Delete')),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    ]);
  }

  Widget _kpi(String label, String value, Color color) => Expanded(
    child: Column(children: [
      Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
      Text(label, style: TextStyle(fontSize: 12, color: color)),
    ]),
  );

  Widget _chip(String label, int index, Color color) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: _filter == index,
      selectedColor: color.withOpacity(0.2),
      onSelected: (_) => setState(() { _filter = index; _applyFilter(); }),
    ),
  );

  Widget _buildCustomersTab() {
    final totalDebt = _balances.values.where((b) => b > 0).fold<double>(0, (s, b) => s + b);
    final debtors = _balances.values.where((b) => b > 0).length;

    return Column(children: [
      Container(
        color: Colors.red.shade50,
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          const Icon(Icons.account_balance_wallet, color: Colors.red, size: 32),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Owed to You: \$${totalDebt.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 16)),
            Text('$debtors customer(s) with balance'),
          ])),
        ]),
      ),
      Expanded(
        child: _customers.isEmpty
            ? const Center(child: Text('No customers. Tap + to add.'))
            : ListView.builder(
                itemCount: _customers.length,
                itemBuilder: (_, i) {
                  final c = _customers[i];
                  final bal = _balances[c.id] ?? 0;
                  final overLimit = c.creditLimit > 0 && bal > c.creditLimit;
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: bal > 0 ? Colors.red.shade100 : Colors.green.shade100,
                        child: Icon(Icons.person, color: bal > 0 ? Colors.red : Colors.green),
                      ),
                      title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(c.phone),
                        Text('Balance: \$${bal.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: bal > 0 ? Colors.red : Colors.green,
                              fontWeight: FontWeight.w600,
                            )),
                        if (c.creditLimit > 0)
                          Text('Limit: \$${c.creditLimit.toStringAsFixed(2)}${overLimit ? " ⚠ OVER" : ""}',
                              style: TextStyle(fontSize: 12,
                                  color: overLimit ? Colors.red : Colors.grey)),
                      ]),
                      isThreeLine: true,
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        await Navigator.push(context,
                            MaterialPageRoute(builder: (_) => CustomerScreen(customer: c)));
                        _load();
                      },
                    ),
                  );
                },
              ),
      ),
    ]);
  }
}
