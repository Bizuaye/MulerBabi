import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';
import '../models/drug.dart';

class AddEditScreen extends StatefulWidget {
  final Drug? drug;
  const AddEditScreen({super.key, this.drug});
  @override
  State<AddEditScreen> createState() => _AddEditScreenState();
}

class _AddEditScreenState extends State<AddEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _category = TextEditingController();
  final _batch = TextEditingController();
  final _supplier = TextEditingController();
  final _qty = TextEditingController();
  final _cost = TextEditingController();
  final _sell = TextEditingController();
  final _notes = TextEditingController();
  DateTime _expiry = DateTime.now().add(const Duration(days: 365));

  @override
  void initState() {
    super.initState();
    final d = widget.drug;
    if (d != null) {
      _name.text = d.name;
      _category.text = d.category;
      _batch.text = d.batchNumber;
      _supplier.text = d.supplier;
      _qty.text = d.quantity.toString();
      _cost.text = d.costPrice.toString();
      _sell.text = d.sellingPrice.toString();
      _notes.text = d.notes ?? '';
      _expiry = d.expiry;
    }
    _cost.addListener(() => setState(() {}));
    _sell.addListener(() => setState(() {}));
    _qty.addListener(() => setState(() {}));
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiry,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _expiry = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final cost = double.parse(_cost.text);
    final sell = double.parse(_sell.text);
    if (sell < cost) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Selling below cost!'),
          content: Text('You lose \$${(cost - sell).toStringAsFixed(2)} per unit. Save anyway?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Fix')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
          ],
        ),
      );
      if (ok != true) return;
    }
    final d = Drug(
      id: widget.drug?.id,
      name: _name.text.trim(),
      category: _category.text.trim(),
      batchNumber: _batch.text.trim(),
      supplier: _supplier.text.trim(),
      quantity: int.parse(_qty.text),
      costPrice: cost,
      sellingPrice: sell,
      expiryDate: DateFormat('yyyy-MM-dd').format(_expiry),
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
    );
    if (widget.drug == null) {
      await DBHelper.instance.insertDrug(d);
    } else {
      await DBHelper.instance.updateDrug(d);
    }
    if (mounted) Navigator.pop(context);
  }

  Widget _profitPreview() {
    final cost = double.tryParse(_cost.text) ?? 0;
    final sell = double.tryParse(_sell.text) ?? 0;
    final qty = int.tryParse(_qty.text) ?? 0;
    final profit = sell - cost;
    final margin = sell > 0 ? (profit / sell) * 100 : 0;
    final loss = profit < 0;
    return Card(
      color: loss ? Colors.red.shade50 : Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(loss ? Icons.trending_down : Icons.trending_up,
                color: loss ? Colors.red : Colors.green),
            const SizedBox(width: 6),
            Text('Profit/unit: \$${profit.toStringAsFixed(2)}',
                style: TextStyle(color: loss ? Colors.red : Colors.green,
                    fontWeight: FontWeight.bold)),
          ]),
          Text('Margin: ${margin.toStringAsFixed(1)}%'),
          Text('Total if all sold: \$${(profit * qty).toStringAsFixed(2)}'),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.drug != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'Edit Drug' : 'Add Drug'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _field(_name, 'Drug Name', required: true),
            const SizedBox(height: 12),
            _field(_category, 'Category (Antibiotic, Vaccine...)', required: true),
            const SizedBox(height: 12),
            _field(_batch, 'Batch Number', required: true),
            const SizedBox(height: 12),
            _field(_supplier, 'Supplier', required: true),
            const SizedBox(height: 12),
            _field(_qty, 'Quantity', required: true, number: true),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _field(_cost, 'Cost Price', required: true, number: true, decimal: true)),
              const SizedBox(width: 10),
              Expanded(child: _field(_sell, 'Selling Price', required: true, number: true, decimal: true)),
            ]),
            const SizedBox(height: 12),
            _profitPreview(),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Expiry Date',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                child: Text(DateFormat('yyyy-MM-dd').format(_expiry)),
              ),
            ),
            const SizedBox(height: 12),
            _field(_notes, 'Notes (optional)', required: false, maxLines: 3),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: Text(editing ? 'Update' : 'Save'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String label,
      {bool required = false, bool number = false, bool decimal = false, int maxLines = 1}) {
    return TextFormField(
      controller: c,
      maxLines: maxLines,
      keyboardType: number
          ? (decimal ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.number)
          : TextInputType.text,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      validator: (v) {
        if (required && (v == null || v.trim().isEmpty)) return 'Required';
        if (number && v != null && v.isNotEmpty) {
          if (decimal ? double.tryParse(v) == null : int.tryParse(v) == null) return 'Invalid';
        }
        return null;
      },
    );
  }
}
