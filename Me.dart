import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';
import '../models/customer.dart';
import '../models/drug.dart';

class CustomerScreen extends StatefulWidget {
  final Customer? customer;
  const CustomerScreen({super.key, this.customer});
  @override
  State<CustomerScreen> createState() => _CustomerScreenState();
}

class _CustomerScreenState extends State<CustomerScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _limit = TextEditingController(text: '0');

  Customer? _customer;
  List<CreditTransaction> _txns = [];
  double _balance = 0;

  @override
  void initState() {
    super.initState();
    _customer = widget.customer;
    if (_customer != null) {
      _name.text = _customer!.name;
      _phone.text = _customer!.phone;
      _address.text = _customer!.address ?? '';
      _limit.text = _customer!.creditLimit.toString();
      _loadTxns();
    }
  }

  Future<void> _loadTxns() async {
    if (_customer?.id == null) return;
    final txns = await DBHelper.instance.getCustomerTransactions(_customer!.id!);
    final bal = await DBHelper.instance.getCustomerBalance(_customer!.id!);
    setState(() { _txns = txns; _balance = bal; });
  }

  Future<void> _saveCustomer() async {
    if (_name.text.trim().isEmpty || _phone.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Name and phone required')));
      return;
    }
    final c = Customer(
      id: _customer?.id,
      name: _name.text.trim(),
      phone: _phone.text.trim(),
      address: _address.text.trim().isEmpty ? null : _address.text.trim(),
      creditLimit: double.tryParse(_limit.text) ?? 0,
    );
    if (_customer == null) {
      final id = await DBHelper.instance.insertCustomer(c);
      _customer = Customer(id: id, name: c.name, phone: c.phone,
          address: c.address, creditLimit: c.creditLimit);
    } else {
      await DBHelper.instance.updateCustomer(c);
    }
    await _loadTxns();
    if (mounted) setState(() {});
  }

  Future<void> _deleteCustomer() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete customer?'),
        content: const Text('All credit history will also be deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) {
      await DBHelper.instance.deleteCustomer(_customer!.id!);
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _recordSale() async {
    final drugs = await DBHelper.instance.getAllDrugs();
    if (drugs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Add drugs first')));
      return;
    }
    Drug? selected = drugs.first;
    final qtyCtrl = TextEditingController(text: '1');
    final priceCtrl = TextEditingController(text: drugs.first.sellingPrice.toString());
    bool paidFull = false;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Record Sale on Credit'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<Drug>(
                value: selected,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Drug'),
                items: drugs.map((d) => DropdownMenuItem(
                  value: d,
                  child: Text('${d.name} (${d.quantity} left)', overflow: TextOverflow.ellipsis),
                )).toList(),
                onChanged: (v) {
                  setS(() {
                    selected = v;
                    priceCtrl.text = v!.sellingPrice.toString();
                  });
                },
              ),
              const SizedBox(height: 8),
              TextField(
                controller: qtyCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Quantity'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: priceCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Unit Price'),
              ),
              CheckboxListTile(
                value: paidFull,
                onChanged: (v) => setS(() => paidFull = v!),
                title: const Text('Paid in full (no debt)'),
                contentPadding: EdgeInsets.zero,
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
          ],
        ),
      ),
    );

    if (result != true || selected == null) return;
    final qty = int.tryParse(qtyCtrl.text) ?? 0;
    final price = double.tryParse(priceCtrl.text) ?? selected!.sellingPrice;
    if (qty <= 0) return;
    if (qty > selected!.quantity) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Only ${selected!.quantity} in stock')));
      return;
    }

    final updated = Drug(
      id: selected!.id,
      name: selected!.name,
      category: selected!.category,
      batchNumber: selected!.batchNumber,
      supplier: selected!.supplier,
      quantity: selected!.quantity - qty,
      costPrice: selected!.costPrice,
      sellingPrice: selected!.sellingPrice,
      expiryDate: selected!.expiryDate,
      notes: selected!.notes,
    );
    await DBHelper.instance.updateDrug(updated);

    final amount = paidFull ? 0.0 : qty * price;
    await DBHelper.instance.insertTransaction(CreditTransaction(
      customerId: _customer!.id!,
      drugId: selected!.id,
      description: 'Sold $qty x ${selected!.name}${paidFull ? " (PAID)" : ""}',
      amount: amount,
      date: DateTime.now().toIso8601String(),
      type: 'sale',
    ));
    _loadTxns();
  }

  Future<void> _recordPayment() async {
    final amtCtrl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Record Payment'),
        content: TextField(
          controller: amtCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: 'Amount',
              helperText: 'Balance: \$${_balance.toStringAsFixed(2)}'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (result != true) return;
    final amt = double.tryParse(amtCtrl.text) ?? 0;
    if (amt <= 0) return;

    await DBHelper.instance.insertTransaction(CreditTransaction(
      customerId: _customer!.id!,
      description: 'Payment received',
      amount: -amt,
      date: DateTime.now().toIso8601String(),
      type: 'payment',
    ));
    _loadTxns();
  }

  @override
  Widget build(BuildContext context) {
    final isNew = _customer == null;
    final df = DateFormat('yyyy-MM-dd HH:mm');
    return Scaffold(
      appBar: AppBar(
        title: Text(isNew ? 'New Customer' : _customer!.name),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          if (!isNew)
            IconButton(icon: const Icon(Icons.delete), onPressed: _deleteCustomer),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: _name,
              decoration: const InputDecoration(labelText: 'Customer Name *', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone *', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: _address,
              decoration: const InputDecoration(labelText: 'Address', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: _limit,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                  labelText: 'Credit Limit (0 = no limit)',
                  border: OutlineInputBorder())),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _saveCustomer,
            icon: const Icon(Icons.save),
            label: Text(isNew ? 'Create Customer' : 'Update Info'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          if (!isNew) ...[
            const Divider(height: 40),
            Card(
              color: _balance > 0 ? Colors.red.shade50 : Colors.green.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  Text(_balance > 0 ? 'OWES YOU' : 'BALANCE',
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  Text('\$${_balance.abs().toStringAsFixed(2)}',
                      style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold,
                          color: _balance > 0 ? Colors.red : Colors.green)),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: ElevatedButton.icon(
                onPressed: _recordSale,
                icon: const Icon(Icons.shopping_cart),
                label: const Text('Sale'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
              )),
              const SizedBox(width: 8),
              Expanded(child: ElevatedButton.icon(
                onPressed: _balance > 0 ? _recordPayment : null,
                icon: const Icon(Icons.payments),
                label: const Text('Payment'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
              )),
            ]),
            const Divider(height: 40),
            const Text('History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            if (_txns.isEmpty)
              const Padding(padding: EdgeInsets.all(20),
                  child: Center(child: Text('No transactions yet'))),
            ..._txns.map((t) => Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: t.amount > 0 ? Colors.red.shade100 : Colors.green.shade100,
                  child: Icon(t.amount > 0 ? Icons.arrow_upward : Icons.arrow_downward,
                      color: t.amount > 0 ? Colors.red : Colors.green, size: 18),
                ),
                title: Text(t.description),
                subtitle: Text(df.format(t.dateTime)),
                trailing: Text(
                  '${t.amount > 0 ? "+" : ""}\$${t.amount.abs().toStringAsFixed(2)}',
                  style: TextStyle(fontWeight: FontWeight.bold,
                      color: t.amount > 0 ? Colors.red : Colors.green),
                ),
              ),
            )),
          ],
        ],
      ),
    );
  }
}
