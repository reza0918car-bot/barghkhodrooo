import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'sms_helper.dart';

import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
//import 'package:url_launcher/url_launcher.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AutoElectricApp());
}

// ======================== ثابت‌ها ========================
const List<String> kIranPlateLetters = [
  'ب', 'ج', 'د', 'س', 'ص', 'ط', 'ق', 'ل', 'م', 'ن', 'و', 'ه', 'ی','ت','ع',
];

const List<String> kPopularCars = [
  'پژو پارس', 'پژو ۲۰۶', 'پژو ۲۰۷', 'پژو ۴۰۵', 'پراید ۱۳۱', 'پراید ۱۱۱',
  'کوییک', 'تیبا', 'ساینا', 'سمند EF7', 'دنا پلاس', 'تارا', 'شاهین',
  'رانا', 'نیسان وانت', 'پیکان وانت', 'ال ۹۰ (تندر)', 'ام‌وی‌ام (MVM)', 'جک (JAC)',
];

const List<Map<String, dynamic>> kDefaultQuickLabors = [
  {'title': 'تعمیر و سرویس دینام', 'cost': 1500000},
  {'title': 'تعمیر و سرویس استارت', 'cost': 1200000},
  {'title': 'دیاگ، عیب‌یابی و پاک کردن خطا', 'cost': 200000},
  {'title': 'عیب‌یابی سیم‌کشی و فن خنک‌کننده', 'cost': 450000},
  {'title': 'تست باتری و شارژ دینام', 'cost': 100000},
  {'title': 'تعویض رله دوبل و فیوزها', 'cost': 120000},
  {'title': 'سرویس شمع و وایر', 'cost': 300000},
  {'title': 'شارژ گاز و نشت‌یابی کولر', 'cost': 6000000},
];

// ======================== انواع پلاک ========================
enum PlateType { national, temporary, freeZone, regional, personal }

String plateTypeToKey(PlateType t) {
  switch (t) {
    case PlateType.national: return 'national';
    case PlateType.temporary: return 'temporary';
    case PlateType.freeZone: return 'freeZone';
    case PlateType.regional: return 'regional';
    case PlateType.personal: return 'personal';
  }
}

PlateType plateTypeFromKey(String? key) {
  switch (key) {
    case 'temporary': return PlateType.temporary;
    case 'freeZone': return PlateType.freeZone;
    case 'regional': return PlateType.regional;
    case 'personal': return PlateType.personal;
    default: return PlateType.national;
  }
}

String plateTypeLabel(PlateType t) {
  switch (t) {
    case PlateType.national: return 'پلاک ملی';
    case PlateType.temporary: return 'گذر موقت';
    case PlateType.freeZone: return 'منطقه آزاد';
    case PlateType.regional: return 'منطقه‌ای/مرزی';
    case PlateType.personal: return 'شخصی/دلخواه';
  }
}

const List<String> kFreeZones = [
  'کیش', 'قشم', 'اروند', 'ارس', 'انزلی', 'چابهار', 'ماکو', 'اروندکنار',
];

// ======================== ابزارهای کمکی ========================
class NumberHelper {
  static String cleanNumbers(String input) {
    const f = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    const a = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    const e = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    String res = input.trim();
    for (int i = 0; i < 10; i++) {
      res = res.replaceAll(f[i], e[i]).replaceAll(a[i], e[i]);
    }
    return res.replaceAll(',', '').replaceAll(' ', '');
  }

  static String normalizePhone(String input) {
    String res = cleanNumbers(input).replaceAll('-', '').replaceAll('+', '');
    if (res.startsWith('0098')) {
      res = '0${res.substring(4)}';
    } else if (res.startsWith('98') && res.length == 12) {
      res = '0${res.substring(2)}';
    } else if (res.length == 10 && res.startsWith('9')) {
      res = '0$res';
    }
    return res;
  }

  static int safeParseInt(String input) {
    final cleaned = cleanNumbers(input);
    return int.tryParse(cleaned) ?? 0;
  }
}

String normalizePlateLetter(String letter) {
  return letter.trim().replaceAll('هـ', 'ه').replaceAll('ي', 'ی').replaceAll('ك', 'ک');
}

class JalaliHelper {
  static String nowShamsi() {
    final now = DateTime.now();
    return gregorianToJalali(now.year, now.month, now.day);
  }

  static String currentMonthShamsi() => nowShamsi().substring(0, 7);

  static String gregorianToJalali(int gy, int gm, int gd) {
    List<int> gDM = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334];
    int jy = (gy <= 1600) ? 0 : 979;
    gy -= (gy <= 1600) ? 621 : 1600;
    int gy2 = (gm > 2) ? (gy + 1) : gy;
    int days = (365 * gy) + ((gy2 + 3) ~/ 4) - ((gy2 + 99) ~/ 100) +
        ((gy2 + 399) ~/ 400) - 80 + gd + gDM[gm - 1];
    jy += 33 * (days ~/ 12053);
    days %= 12053;
    jy += 4 * (days ~/ 1461);
    days %= 1461;
    jy += (days > 365) ? ((days - 1) ~/ 365) : 0;
    if (days > 365) days = (days - 1) % 365;
    int jm = (days < 186) ? 1 + (days ~/ 31) : 7 + ((days - 186) ~/ 30);
    int jd = 1 + ((days < 186) ? (days % 31) : ((days - 186) % 30));
    return '$jy/${jm.toString().padLeft(2, '0')}/${jd.toString().padLeft(2, '0')}';
  }
}

final intl.NumberFormat _tomanFormatter = intl.NumberFormat('#,###', 'fa');
String formatToman(int amount) => '${_tomanFormatter.format(amount)} تومان';

// ======================== Isolates ========================
List<Customer> _decodeCustomersIsolate(String rawJson) {
  final List decoded = jsonDecode(rawJson);
  return decoded.map((e) => Customer.fromMap(e as Map<String, dynamic>)).toList();
}

String _encodeCustomersIsolate(List<Map<String, dynamic>> rawMaps) => jsonEncode(rawMaps);

// ======================== مدل‌ها ========================
class LaborItem {
  String title;
  int cost;
  LaborItem({required this.title, required this.cost});
  Map<String, dynamic> toMap() => {'title': title, 'cost': cost};
  factory LaborItem.fromMap(Map<String, dynamic> m) =>
      LaborItem(title: m['title'] ?? '', cost: m['cost'] ?? 0);
}

class PartItem {
  String name;
  int price;
  // فقط قطعاتی که از فهرست انبار انتخاب شده‌اند موجودی را تغییر می‌دهند.
  // مقدار پیش‌فرض false با فاکتورهای قدیمی سازگار است.
  bool fromInventory;
  // بهای خرید ثبت‌شده در لحظه افزودن قطعه به فاکتور؛ برای محاسبه بهای تمام‌شده.
  int unitCost;
  PartItem({required this.name, required this.price, this.fromInventory = false, this.unitCost = 0});
  Map<String, dynamic> toMap() => {
    'name': name,
    'price': price,
    'fromInventory': fromInventory,
    'unitCost': unitCost,
  };
  factory PartItem.fromMap(Map<String, dynamic> m) => PartItem(
    name: m['name'] ?? '',
    price: (m['price'] as num?)?.toInt() ?? 0,
    fromInventory: m['fromInventory'] == true,
    unitCost: (m['unitCost'] as num?)?.toInt() ?? 0,
  );
}

class ServiceTemplate {
  String title;
  int cost;
  ServiceTemplate({required this.title, required this.cost});
  Map<String, dynamic> toMap() => {'title': title, 'cost': cost};
  factory ServiceTemplate.fromMap(Map<String, dynamic> m) =>
      ServiceTemplate(title: m['title'] ?? '', cost: m['cost'] ?? 0);
}

class PartTemplate {
  String name;
  int price;
  int quantity;
  int purchasePrice; // بهای خرید هر عدد قطعه
  
  PartTemplate({required this.name, required this.price, this.quantity = 0, this.purchasePrice = 0});
  
  Map<String, dynamic> toMap() => {'name': name, 'price': price, 'quantity': quantity, 'purchasePrice': purchasePrice};
  
  factory PartTemplate.fromMap(Map<String, dynamic> m) => PartTemplate(
    name: m['name'] ?? '', 
    price: m['price'] ?? 0,
    quantity: (m['quantity'] as num?)?.toInt() ?? 0,
    purchasePrice: (m['purchasePrice'] as num?)?.toInt() ?? 0,
  );
}

class TemplatesRepository {
  static const _kServiceKey = 'service_templates_v1';
  static const _kPartKey = 'part_templates_v1';

  static List<ServiceTemplate> _defaultServices() => kDefaultQuickLabors
      .map((m) => ServiceTemplate(title: m['title'] as String, cost: m['cost'] as int))
      .toList();

  static Future<List<ServiceTemplate>> loadServices() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kServiceKey);
      if (raw == null || raw.isEmpty) return _defaultServices();
      final list = jsonDecode(raw) as List;
      return list.map((e) => ServiceTemplate.fromMap(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return _defaultServices();
    }
  }

  static Future<void> saveServices(List<ServiceTemplate> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kServiceKey, jsonEncode(items.map((e) => e.toMap()).toList()));
  }

  static Future<void> resetServicesToDefault() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kServiceKey);
  }

  static Future<List<PartTemplate>> loadParts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kPartKey);
      if (raw == null || raw.isEmpty) return [];
      final list = jsonDecode(raw) as List;
      return list.map((e) => PartTemplate.fromMap(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveParts(List<PartTemplate> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPartKey, jsonEncode(items.map((e) => e.toMap()).toList()));
  }
}

class PaymentEntry {
  final String id;
  final String date;
  final int amount;
  final String method;
  final String note;

  PaymentEntry({required this.id, required this.date, required this.amount,
    required this.method, this.note = ''});

  Map<String, dynamic> toMap() => {
    'id': id, 'date': date, 'amount': amount, 'method': method, 'note': note,
  };

  factory PaymentEntry.fromMap(Map<String, dynamic> map) => PaymentEntry(
    id: map['id']?.toString() ?? DateTime.now().microsecondsSinceEpoch.toString(),
    date: map['date']?.toString() ?? JalaliHelper.nowShamsi(),
    amount: (map['amount'] as num?)?.toInt() ?? 0,
    method: map['method']?.toString() ?? 'نقدی',
    note: map['note']?.toString() ?? '',
  );
}

class ServiceRecord {
  String id;
  String date;
  String km;
  String warrantyNote;
  String paymentMethod;
  int discount;
  int paidAmount;
  List<LaborItem> labors;
  List<PartItem> parts;
  List<PaymentEntry> paymentEntries = [];

  ServiceRecord({
    required this.id,
    required this.date,
    this.km = '',
    this.warrantyNote = '',
    this.paymentMethod = 'کارت‌خوان (POS)',
    this.discount = 0,
    this.paidAmount = 0,
    required this.labors,
    required this.parts,
    List<PaymentEntry>? paymentEntries,
  }) : paymentEntries = paymentEntries ?? [];

  int get laborTotal => labors.fold(0, (s, i) => s + i.cost);
  int get partsTotal => parts.fold(0, (s, i) => s + i.price);
  int get subTotal => laborTotal + partsTotal;
  int get grandTotal => (subTotal - discount) > 0 ? (subTotal - discount) : 0;
  int get remainingDebt => (grandTotal - paidAmount) > 0 ? (grandTotal - paidAmount) : 0;

  String get summaryTitle =>
      labors.isNotEmpty ? labors.map((l) => l.title).join(' ، ') : 'خدمات عمومی برق خودرو';

  Map<String, dynamic> toMap() => {
        'id': id,
        'date': date,
        'km': km,
        'warrantyNote': warrantyNote,
        'paymentMethod': paymentMethod,
        'discount': discount,
        'paidAmount': paidAmount,
        'labors': labors.map((l) => l.toMap()).toList(),
        'parts': parts.map((p) => p.toMap()).toList(),
        'paymentEntries': paymentEntries.map((p) => p.toMap()).toList(),
      };

  factory ServiceRecord.fromMap(Map<String, dynamic> map) {
    final fallbackId = DateTime.now().microsecondsSinceEpoch.toString();
    List<LaborItem> parsedLabors = [];
    if (map['labors'] != null) {
      parsedLabors = (map['labors'] as List).map((l) => LaborItem.fromMap(l)).toList();
    } else if (map['title'] != null) {
      parsedLabors = [LaborItem(title: map['title'], cost: map['laborCost'] ?? 0)];
    }
    final rawGrand =
        (map['parts'] as List? ?? []).fold<int>(0, (sum, p) => sum + ((p['price'] as int?) ?? 0)) +
            parsedLabors.fold<int>(0, (sum, l) => sum + l.cost);

    return ServiceRecord(
      id: (map['id'] as String?)?.isNotEmpty == true ? map['id'] : fallbackId,
      date: map['date'] ?? JalaliHelper.nowShamsi(),
      km: map['km'] ?? '',
      warrantyNote: map['warrantyNote'] ?? '',
      paymentMethod: map['paymentMethod'] ?? 'کارت‌خوان (POS)',
      discount: map['discount'] ?? 0,
      paidAmount: map['paidAmount'] ?? rawGrand,
      labors: parsedLabors,
      parts: (map['parts'] as List? ?? []).map((p) => PartItem.fromMap(p)).toList(),
      paymentEntries: (map['paymentEntries'] as List? ?? [])
          .map((p) => PaymentEntry.fromMap(Map<String, dynamic>.from(p))).toList(),
    );
  }
}

class Car {
  String id;
  String model;
  PlateType plateType;
  String plateTwoDigits;
  String plateLetter;
  String plateThreeDigits;
  String plateProvinceCode;
  String customPlate;
  String freeZoneName;
  List<ServiceRecord> services;

  Car({
    required this.id,
    required this.model,
    this.plateType = PlateType.national,
    required this.plateTwoDigits,
    required this.plateLetter,
    required this.plateThreeDigits,
    required this.plateProvinceCode,
    this.customPlate = '',
    this.freeZoneName = '',
    required this.services,
  });

  String get fullPlate {
    switch (plateType) {
      case PlateType.national:
        if (plateTwoDigits.isEmpty && plateThreeDigits.isEmpty) return 'بدون پلاک';
        return '$plateTwoDigits $plateLetter $plateThreeDigits - ایران $plateProvinceCode';
      case PlateType.temporary:
        return 'گذر موقت - $customPlate';
      case PlateType.freeZone:
        return 'منطقه آزاد $freeZoneName - $customPlate';
      case PlateType.regional:
        return 'منطقه‌ای - $customPlate';
      case PlateType.personal:
        return 'شخصی - $customPlate';
    }
  }

  bool get hasAnyPlate {
    if (plateType == PlateType.national) {
      return plateTwoDigits.isNotEmpty && plateThreeDigits.isNotEmpty;
    }
    return customPlate.trim().isNotEmpty;
  }

  bool matchesPlate(Car other) {
    if (plateType != other.plateType) return false;
    if (plateType == PlateType.national) {
      final t1 = NumberHelper.cleanNumbers(plateTwoDigits);
      final t2 = NumberHelper.cleanNumbers(other.plateTwoDigits);
      final l1 = normalizePlateLetter(plateLetter);
      final l2 = normalizePlateLetter(other.plateLetter);
      final th1 = NumberHelper.cleanNumbers(plateThreeDigits);
      final th2 = NumberHelper.cleanNumbers(other.plateThreeDigits);
      final p1 = NumberHelper.cleanNumbers(plateProvinceCode);
      final p2 = NumberHelper.cleanNumbers(other.plateProvinceCode);
      if (t1.isEmpty || th1.isEmpty || t2.isEmpty || th2.isEmpty) return false;
      if (t1 != t2 || l1 != l2 || th1 != th2) return false;
      if (p1.isNotEmpty && p2.isNotEmpty) return p1 == p2;
      return true;
    }
    final c1 = customPlate.trim().toLowerCase();
    final c2 = other.customPlate.trim().toLowerCase();
    if (c1.isEmpty || c2.isEmpty) return false;
    if (c1 != c2) return false;
    if (plateType == PlateType.freeZone) {
      return freeZoneName.trim() == other.freeZoneName.trim();
    }
    return true;
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'model': model,
        'plateType': plateTypeToKey(plateType),
        'two': plateTwoDigits,
        'letter': plateLetter,
        'three': plateThreeDigits,
        'prov': plateProvinceCode,
        'customPlate': customPlate,
        'freeZoneName': freeZoneName,
        'services': services.map((s) => s.toMap()).toList(),
      };

  factory Car.fromMap(Map<String, dynamic> map) => Car(
        id: (map['id'] as String?)?.isNotEmpty == true
            ? map['id']
            : DateTime.now().microsecondsSinceEpoch.toString(),
        model: map['model'] ?? '',
        plateType: plateTypeFromKey(map['plateType'] as String?),
        plateTwoDigits: map['two'] ?? '',
        plateLetter: map['letter'] ?? 'ب',
        plateThreeDigits: map['three'] ?? '',
        plateProvinceCode: map['prov'] ?? '',
        customPlate: map['customPlate'] ?? '',
        freeZoneName: map['freeZoneName'] ?? '',
        services: (map['services'] as List? ?? []).map((s) => ServiceRecord.fromMap(s)).toList(),
      );
}

class Customer {
  String id;
  String name;
  String phone;
  List<Car> cars;
  late String searchKey;

  Customer({required this.id, required this.name, required this.phone, required this.cars}) {
    updateSearchKey();
  }

  void updateSearchKey() {
    final carsStr = cars.map((c) {
      final noSpace = c.fullPlate.replaceAll(' ', '');
      return '${c.model} ${c.fullPlate} $noSpace';
    }).join(' ');
    searchKey = '${name.toLowerCase()} ${phone.replaceAll(' ', '')} $carsStr'.toLowerCase();
  }

  int get totalDebt =>
      cars.fold(0, (sum, c) => sum + c.services.fold(0, (s, srv) => s + srv.remainingDebt));

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'phone': phone,
        'cars': cars.map((c) => c.toMap()).toList(),
      };

  factory Customer.fromMap(Map<String, dynamic> map) => Customer(
        id: (map['id'] as String?)?.isNotEmpty == true
            ? map['id']
            : DateTime.now().microsecondsSinceEpoch.toString(),
        name: map['name'] ?? '',
        phone: map['phone'] ?? '',
        cars: (map['cars'] as List? ?? []).map((c) => Car.fromMap(c)).toList(),
      );
}


// ======================== هزینه‌های تعمیرگاه ========================
class WorkshopExpense {
  final String id;
  final String title;
  final String category;
  final int amount;
  final String date;
  final String note;
  const WorkshopExpense({required this.id, required this.title, required this.category,
    required this.amount, required this.date, this.note = ''});
  Map<String, dynamic> toMap() => {'id': id, 'title': title, 'category': category,
    'amount': amount, 'date': date, 'note': note};
  factory WorkshopExpense.fromMap(Map<String, dynamic> m) => WorkshopExpense(
    id: m['id']?.toString() ?? DateTime.now().microsecondsSinceEpoch.toString(),
    title: m['title']?.toString() ?? '', category: m['category']?.toString() ?? 'سایر',
    amount: (m['amount'] as num?)?.toInt() ?? 0,
    date: m['date']?.toString() ?? JalaliHelper.nowShamsi(), note: m['note']?.toString() ?? '');
}

class WorkshopExpenseScreen extends StatefulWidget {
  const WorkshopExpenseScreen({super.key});
  @override
  State<WorkshopExpenseScreen> createState() => _WorkshopExpenseScreenState();
}
class _WorkshopExpenseScreenState extends State<WorkshopExpenseScreen> {
  static const _storageKey = 'workshop_expenses_v1';
  final List<WorkshopExpense> _items = [];
  bool _loading = true;
  final _categories = const ['خرید قطعات', 'اجاره', 'قبوض و اینترنت', 'ابزار و تجهیزات', 'حقوق و دستمزد', 'حمل‌ونقل', 'سایر'];
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as List;
        _items.addAll(decoded.map((e) => WorkshopExpense.fromMap(Map<String, dynamic>.from(e))));
      }
    } catch (e) { debugPrint('Expense load error: $e'); }
    if (mounted) setState(() => _loading = false);
  }
  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_storageKey, jsonEncode(_items.map((e) => e.toMap()).toList()));
  }
  int get _total => _items.fold(0, (sum, e) => sum + e.amount);
  Future<void> _addExpense() async {
    final title = TextEditingController(); final amount = TextEditingController();
    final note = TextEditingController(); String category = _categories.first;
    final result = await showDialog<WorkshopExpense>(context: context, builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialog) => AlertDialog(
        title: const Text('ثبت هزینه جدید'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: title, decoration: const InputDecoration(labelText: 'عنوان هزینه')),
          const SizedBox(height: 10),
          TextField(controller: amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'مبلغ (تومان)')),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(value: category, decoration: const InputDecoration(labelText: 'دسته‌بندی'),
            items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(), onChanged: (v) => setDialog(() => category = v ?? _categories.first)),
          const SizedBox(height: 10), TextField(controller: note, decoration: const InputDecoration(labelText: 'توضیحات (اختیاری)')),
        ])),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
          FilledButton(onPressed: () { final v = NumberHelper.safeParseInt(amount.text);
            if (title.text.trim().isEmpty || v <= 0) return;
            Navigator.pop(ctx, WorkshopExpense(id: DateTime.now().microsecondsSinceEpoch.toString(), title: title.text.trim(), category: category, amount: v, date: JalaliHelper.nowShamsi(), note: note.text.trim()));
          }, child: const Text('ثبت هزینه'))],
      )));
    title.dispose(); amount.dispose(); note.dispose();
    if (result != null) { setState(() => _items.insert(0, result)); await _save(); }
  }
  Future<void> _delete(WorkshopExpense e) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('حذف هزینه'), content: Text('هزینه «${e.title}» حذف شود؟'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('انصراف')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف'))]));
    if (ok == true) { setState(() => _items.removeWhere((x) => x.id == e.id)); await _save(); }
  }
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(appBar: AppBar(title: const Text('هزینه‌های تعمیرگاه')),
      floatingActionButton: FloatingActionButton.extended(onPressed: _addExpense, icon: const Icon(Icons.add), label: const Text('ثبت هزینه')),
      body: _loading ? const Center(child: CircularProgressIndicator()) : Column(children: [
        Card(margin: const EdgeInsets.all(16), child: Padding(padding: const EdgeInsets.all(18), child: Row(children: [
          const Icon(Icons.account_balance_wallet_outlined, size: 36, color: Colors.orange), const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('مجموع هزینه‌های ثبت‌شده', style: TextStyle(color: cs.onSurfaceVariant)), const SizedBox(height: 5), Text(formatToman(_total), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.orange))]))
        ]))),
        Expanded(child: _items.isEmpty ? const Center(child: Text('هنوز هزینه‌ای ثبت نشده است.')) : ListView.builder(padding: const EdgeInsets.fromLTRB(12, 0, 12, 90), itemCount: _items.length, itemBuilder: (ctx, i) {
          final e = _items[i]; return Card(child: ListTile(leading: CircleAvatar(child: Icon(e.category == 'خرید قطعات' ? Icons.build : Icons.receipt_long)),
            title: Text(e.title, style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text('${e.category} • ${e.date}${e.note.isEmpty ? '' : '\n${e.note}'}'), isThreeLine: e.note.isNotEmpty,
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [Text(formatToman(e.amount), style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)), IconButton(tooltip: 'حذف', onPressed: () => _delete(e), icon: const Icon(Icons.delete_outline, color: Colors.redAccent))])));
        }))
      ]));
  }
}

// ======================== App + Theme ========================
class AutoElectricApp extends StatefulWidget {
  const AutoElectricApp({super.key});
  @override
  State<AutoElectricApp> createState() => _AutoElectricAppState();
}

class _AutoElectricAppState extends State<AutoElectricApp> {
  bool _isDark = true;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _isDark = prefs.getBool('theme_dark') ?? true;
        _loaded = true;
      });
    } catch (_) {
      setState(() => _loaded = true);
    }
  }

  Future<void> _toggleTheme() async {
    setState(() => _isDark = !_isDark);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('theme_dark', _isDark);
    } catch (_) {}
  }

  ThemeData _darkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF0A0F1D),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF38BDF8),
        onPrimary: Colors.white,
        secondary: Colors.amberAccent,
        surface: Color(0xFF131D31),
        onSurface: Colors.white,
        onSurfaceVariant: Color(0xFFB0B8C5),
        surfaceContainerHighest: Color(0xFF0F172A),
        outline: Color(0xFF3A4557),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      cardTheme: const CardThemeData(color: Color(0xFF131D31), elevation: 2),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF131D31),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      ),
    );
  }

  ThemeData _lightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF3F6FA),
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF0284C7),
        onPrimary: Colors.white,
        secondary: Color(0xFFF59E0B),
        surface: Colors.white,
        onSurface: Color(0xFF141821),
        onSurfaceVariant: Color(0xFF5A6478),
        surfaceContainerHighest: Color(0xFFEAF0F7),
        outline: Color(0xFFD0D7E0),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Color(0xFF141821),
        elevation: 0,
      ),
      cardTheme: const CardThemeData(color: Colors.white, elevation: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: const Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }
    return MaterialApp(
      title: 'کلینیک برق خودرو مهندس',
      debugShowCheckedModeBanner: false,
      theme: _isDark ? _darkTheme() : _lightTheme(),
      locale: const Locale('fa', 'IR'),
      supportedLocales: const [Locale('fa', 'IR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: MainNavigationScreen(isDark: _isDark, onToggleTheme: _toggleTheme),
    );
  }
}

// ======================== ناوبری اصلی ========================
class MainNavigationScreen extends StatefulWidget {
  final bool isDark;
  final VoidCallback onToggleTheme;
  const MainNavigationScreen({super.key, required this.isDark, required this.onToggleTheme});
  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  List<Customer> customers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? raw = prefs.getString('customers_data_v9');
      if (raw != null && raw.isNotEmpty) {
        try {
          final parsed = await compute(_decodeCustomersIsolate, raw);
          if (!mounted) return;
          setState(() {
            customers = parsed;
            _isLoading = false;
          });
          return;
        } catch (e) {
          debugPrint('Error decoding: $e');
          if (mounted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('خطا در بازیابی داده‌های ذخیره‌شده. لطفاً از پشتیبان بازیابی کنید.'),
                  backgroundColor: Colors.redAccent,
                  duration: Duration(seconds: 6),
                ),
              );
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _saveData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawList = customers.map((c) => c.toMap()).toList();
      final encoded = await compute(_encodeCustomersIsolate, rawList);
      await prefs.setString('customers_data_v9', encoded);
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Save error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در ذخیره‌سازی: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.cyanAccent),
              SizedBox(height: 14),
              Text('در حال بارگذاری پرونده‌ها...'),
            ],
          ),
        ),
      );
    }

    final screens = [
      HomeScreen(
        customers: customers,
        onDataChanged: _saveData,
        isDark: widget.isDark,
        onToggleTheme: widget.onToggleTheme,
      ),
      DebtorsScreen(customers: customers, onDataChanged: _saveData),
      DailyReportScreen(customers: customers),
      const WorkshopExpenseScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: Theme.of(context).colorScheme.outline.withOpacity(0.3), width: 0.8),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (i) => setState(() => _currentIndex = i),
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          selectedItemColor: Theme.of(context).colorScheme.primary,
          unselectedItemColor: Theme.of(context).colorScheme.onSurfaceVariant,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.engineering), label: 'میز کار مشتریان'),
            BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet), label: 'حساب دفتری'),
            BottomNavigationBarItem(icon: Icon(Icons.query_stats), label: 'دخل و گزارش'),
            BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: 'هزینه‌ها'),
          ],
        ),
      ),
    );
  }
}

// ======================== صفحه اصلی ========================
class HomeScreen extends StatefulWidget {
  final List<Customer> customers;
  final VoidCallback onDataChanged;
  final bool isDark;
  final VoidCallback onToggleTheme;
  const HomeScreen({
    super.key,
    required this.customers,
    required this.onDataChanged,
    required this.isDark,
    required this.onToggleTheme,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;
  List<Customer> _filteredList = [];

  final Map<String, ExpansionTileController> _tileControllers = {};
  ExpansionTileController _controllerFor(String id) =>
      _tileControllers.putIfAbsent(id, () => ExpansionTileController());

  @override
  void initState() {
    super.initState();
    _filteredList = widget.customers;
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.customers != widget.customers) {
      _applyFilter(searchQuery);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String q) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 150), () => _applyFilter(q));
  }

  void _applyFilter(String q) {
    final cleanQ = q.trim().toLowerCase();
    setState(() {
      searchQuery = cleanQ;
      if (cleanQ.isEmpty) {
        _filteredList = widget.customers;
      } else {
        _filteredList = widget.customers.where((c) => c.searchKey.contains(cleanQ)).toList();
      }
    });
  }

  Future<void> _navigateToCustomer(Customer customer) async {
    final query = customer.phone.isNotEmpty ? customer.phone : customer.name;
    _searchCtrl.text = query;
    _applyFilter(query);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 250));
      if (!mounted) return;
      try {
        _controllerFor(customer.id).expand();
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final int totalCars = widget.customers.fold(0, (s, c) => s + c.cars.length);

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bolt, color: Colors.amberAccent, size: 26),
            SizedBox(width: 6),
            Text('کلینیک برق خودرو مهندس',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(widget.isDark ? Icons.light_mode : Icons.dark_mode,
                color: Colors.amberAccent),
            tooltip: widget.isDark ? 'تم روشن' : 'تم تاریک',
            onPressed: widget.onToggleTheme,
          ),
          IconButton(
            icon: const Icon(Icons.campaign, color: Colors.amberAccent, size: 26),
            tooltip: 'پیامک گروهی',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => BulkSmsScreen(customers: widget.customers)),
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.cyanAccent),
            tooltip: 'بیشتر',
            onSelected: (v) {
              if (v == 'templates') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TemplatesManagerScreen()),
                );
              } else if (v == 'backup') {
                _openSmartBackupDialog(context);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'templates',
                child: Row(children: [
                  Icon(Icons.tune, color: Colors.cyanAccent),
                  SizedBox(width: 8),
                  Text('مدیریت قیمت‌ها'),
                ]),
              ),
              PopupMenuItem(
                value: 'backup',
                child: Row(children: [
                  Icon(Icons.cloud_sync, color: Colors.amberAccent),
                  SizedBox(width: 8),
                  Text('پشتیبان‌گیری'),
                ]),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [cs.primary.withOpacity(0.25), cs.surface],
                begin: Alignment.centerRight,
                end: Alignment.centerLeft,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cs.primary.withOpacity(0.25)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  const Icon(Icons.groups, color: Colors.cyanAccent, size: 22),
                  const SizedBox(width: 8),
                  Text('مشتریان: ${widget.customers.length}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ]),
                Container(height: 18, width: 1, color: cs.outline),
                Row(children: [
                  const Icon(Icons.directions_car, color: Colors.amberAccent, size: 20),
                  const SizedBox(width: 8),
                  Text('خودروها: $totalCars',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ]),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber[800],
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.sms, size: 14, color: Colors.white),
                  label: const Text('پیامک',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => BulkSmsScreen(customers: widget.customers)),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'جستجوی آنی (نام، شماره، مدل خودرو یا پلاک)...',
                hintStyle: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                prefixIcon: const Icon(Icons.search, color: Colors.cyanAccent),
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          _applyFilter('');
                        },
                      )
                    : null,
              ),
            ),
          ),
          Expanded(
            child: _filteredList.isEmpty
                ? Center(
                    child: Text('پرونده‌ای یافت نشد.',
                        style: TextStyle(color: cs.onSurfaceVariant)),
                  )
                : ListView.builder(
                    itemCount: _filteredList.length,
                    itemBuilder: (_, i) => _buildCustomerCard(_filteredList[i]),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: cs.primary,
        icon: const Icon(Icons.person_add_alt_1, color: Colors.white),
        label: const Text('مشتری جدید',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () => _openCustomerDialog(),
      ),
    );
  }

  Widget _buildCustomerCard(Customer customer) {
    final cs = Theme.of(context).colorScheme;
    final bool hasDebt = customer.totalDebt > 0;
    return Card(
      key: ValueKey(customer.id),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ExpansionTile(
        key: PageStorageKey('cust_${customer.id}'),
        controller: _controllerFor(customer.id),
        leading: CircleAvatar(
          backgroundColor: hasDebt ? Colors.redAccent.withOpacity(0.85) : cs.primary,
          child: Icon(hasDebt ? Icons.priority_high : Icons.person, color: Colors.white),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(customer.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
            if (hasDebt)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                margin: const EdgeInsets.only(left: 4),
                decoration:
                    BoxDecoration(color: Colors.red[900], borderRadius: BorderRadius.circular(6)),
                child: Text('بدهکار: ${formatToman(customer.totalDebt)}',
                    style: const TextStyle(fontSize: 10, color: Colors.white)),
              ),
            IconButton(
              icon: const Icon(Icons.edit, size: 20, color: Colors.cyanAccent),
              onPressed: () => _openCustomerDialog(customer: customer),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
              onPressed: () => _confirmDeleteCustomer(customer),
            ),
          ],
        ),
        subtitle: Text(
          '📞 ${customer.phone.isNotEmpty ? customer.phone : 'بدون شماره'}  |  🚗 ${customer.cars.length} خودرو',
          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
        ),
        children: [
          ...customer.cars.map((car) => _buildCarRow(customer, car)),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: cs.surfaceContainerHighest,
                  side: BorderSide(color: cs.primary)),
              icon: const Icon(Icons.add_circle_outline, color: Colors.cyanAccent, size: 18),
              label: const Text('ثبت خودروی دیگر',
                  style: TextStyle(color: Colors.cyanAccent, fontSize: 12)),
              onPressed: () => _openCarDialog(customer: customer),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCarRow(Customer customer, Car car) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outline.withOpacity(0.4)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(children: [
                  Flexible(
                    child: Text(car.model,
                        style: const TextStyle(
                            color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 14),
                        overflow: TextOverflow.ellipsis),
                  ),
                  IconButton(
                    icon: Icon(Icons.edit, size: 16, color: cs.onSurfaceVariant),
                    onPressed: () => _openCarDialog(customer: customer, carToEdit: car),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_forever, size: 16, color: Colors.redAccent),
                    onPressed: () => _confirmDeleteCar(customer, car),
                  ),
                ]),
              ),
              RealisticPlateBadge(car: car),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${car.services.length} فاکتور ثبت شده',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: cs.primary),
                icon: const Icon(Icons.receipt_long, size: 15, color: Colors.white),
                label: const Text('فاکتورها و سوابق',
                    style: TextStyle(color: Colors.white, fontSize: 11)),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CarServicesScreen(
                        customer: customer,
                        car: car,
                        onChanged: () {
                          customer.updateSearchKey();
                          widget.onDataChanged();
                          setState(() {});
                        },
                      ),
                    ),
                  );
                  setState(() {});
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openCustomerDialog({Customer? customer}) {
    showDialog(
      context: context,
      builder: (_) => _CustomerEditDialog(
        customer: customer,
        existingCustomers: widget.customers,
        onGoToExisting: (c) {
          Navigator.pop(context);
          _navigateToCustomer(c);
        },
        onSave: (name, phone) {
          setState(() {
            if (customer == null) {
              widget.customers.insert(
                0,
                Customer(
                  id: DateTime.now().microsecondsSinceEpoch.toString(),
                  name: name,
                  phone: phone,
                  cars: [],
                ),
              );
            } else {
              customer.name = name;
              customer.phone = phone;
              customer.updateSearchKey();
            }
          });
          _applyFilter(searchQuery);
          widget.onDataChanged();
        },
      ),
    );
  }

  void _confirmDeleteCustomer(Customer customer) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('⚠️ حذف پرونده مشتری', style: TextStyle(color: Colors.redAccent)),
        content:
            Text('آیا از حذف پرونده "${customer.name}" و تمام سوابق فاکتورهای آن اطمینان دارید؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              setState(() => widget.customers.removeWhere((c) => c.id == customer.id));
              _applyFilter(searchQuery);
              widget.onDataChanged();
              Navigator.pop(ctx);
            },
            child: const Text('حذف'),
          )
        ],
      ),
    );
  }

  void _openCarDialog({required Customer customer, Car? carToEdit}) {
    showDialog(
      context: context,
      builder: (_) => _CarEditDialog(
        carToEdit: carToEdit,
        customer: customer,
        existingCustomers: widget.customers,
        onGoToExisting: (owner) {
          Navigator.pop(context);
          _navigateToCustomer(owner);
        },
        onSave: (model, two, letter, three, prov, plateType, customPlate, freeZoneName) {
          setState(() {
            if (carToEdit == null) {
              customer.cars.add(Car(
                id: DateTime.now().microsecondsSinceEpoch.toString(),
                model: model,
                plateType: plateType,
                plateTwoDigits: two,
                plateLetter: letter,
                plateThreeDigits: three,
                plateProvinceCode: prov,
                customPlate: customPlate,
                freeZoneName: freeZoneName,
                services: [],
              ));
            } else {
              carToEdit.model = model;
              carToEdit.plateType = plateType;
              carToEdit.plateTwoDigits = two;
              carToEdit.plateLetter = letter;
              carToEdit.plateThreeDigits = three;
              carToEdit.plateProvinceCode = prov;
              carToEdit.customPlate = customPlate;
              carToEdit.freeZoneName = freeZoneName;
            }
            customer.updateSearchKey();
          });
          _applyFilter(searchQuery);
          widget.onDataChanged();
        },
      ),
    );
  }

  void _confirmDeleteCar(Customer customer, Car car) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف خودرو', style: TextStyle(color: Colors.redAccent)),
        content: Text('آیا از حذف خودروی "${car.model}" مطمئن هستید؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              setState(() => customer.cars.removeWhere((c) => c.id == car.id));
              customer.updateSearchKey();
              _applyFilter(searchQuery);
              widget.onDataChanged();
              Navigator.pop(ctx);
            },
            child: const Text('حذف'),
          )
        ],
      ),
    );
  }

  void _openSmartBackupDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.save_as, color: Colors.cyanAccent),
          SizedBox(width: 8),
          Text('پشتیبان‌گیری و بازیابی'),
        ]),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                  'پشتیبان‌گیری به شکل یک فایل اختصاصی JSON ذخیره و به اشتراک گذاشته می‌شود.',
                  style: TextStyle(fontSize: 12)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  minimumSize: const Size.fromHeight(45),
                ),
                icon: const Icon(Icons.share, color: Colors.white),
                label: const Text('اشتراک فایل پشتیبان (.json)',
                    style: TextStyle(color: Colors.white, fontSize: 13)),
                onPressed: () {
                  Navigator.pop(ctx);
                  _exportBackupAsFile(context);
                },
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber[800],
                    minimumSize: const Size.fromHeight(45)),
                icon: const Icon(Icons.file_open, color: Colors.white),
                label: const Text('انتخاب فایل پشتیبان از گوشی',
                    style: TextStyle(color: Colors.white, fontSize: 13)),
                onPressed: () {
                  Navigator.pop(ctx);
                  _pickAndRestoreBackupFile(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _exportBackupAsFile(BuildContext context) async {
    try {
      final rawList = widget.customers.map((c) => c.toMap()).toList();
      final jsonString = await compute(_encodeCustomersIsolate, rawList);

      final dir = await getTemporaryDirectory();
      final shamsiDate = JalaliHelper.nowShamsi().replaceAll('/', '_');
      final file = File('${dir.path}/پشتیبان_برق_خودرو_$shamsiDate.json');
      await file.writeAsString(jsonString, encoding: utf8);

      if (!context.mounted) return;
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/json')],
        subject: 'پشتیبان برق خودرو',
        text: 'فایل پشتیبان تاریخ $shamsiDate',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در ایجاد فایل پشتیبان: $e')),
        );
      }
    }
  }

  Future<void> _pickAndRestoreBackupFile(BuildContext context) async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.isEmpty) return;

      final PlatformFile file = result.first;
      final String filePath = file.path!;

      final fileContent = await File(filePath).readAsString(encoding: utf8);
      final parsed = await compute(_decodeCustomersIsolate, fileContent);

      if (!context.mounted) return;

      bool? confirm = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Row(children: [
            Icon(Icons.warning_amber, color: Colors.orange),
            SizedBox(width: 8),
            Text('تایید بازیابی'),
          ]),
          content: Text(
            'آیا از بازنویسی اطلاعات فعلی با ${parsed.length} پرونده موجود در فایل پشتیبان اطمینان دارید؟\n\nاطلاعات فعلی پاک خواهند شد!',
            style: const TextStyle(fontSize: 13),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('انصراف')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () => Navigator.pop(c, true),
              child: const Text('بله، بازیابی کن'),
            ),
          ],
        ),
      );

      if (confirm != true) return;

      setState(() {
        widget.customers.clear();
        widget.customers.addAll(parsed);
      });
      _applyFilter(searchQuery);
      widget.onDataChanged();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('${parsed.length} پرونده با موفقیت بازیابی شد!'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا در بازیابی فایل. آیا فایل انتخاب شده معتبر است؟\n$e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }
}

// ======================== صفحه مدیریت قیمت‌ها ========================
class TemplatesManagerScreen extends StatefulWidget {
  const TemplatesManagerScreen({super.key});
  @override
  State<TemplatesManagerScreen> createState() => _TemplatesManagerScreenState();
}

class _TemplatesManagerScreenState extends State<TemplatesManagerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<ServiceTemplate> _services = [];
  List<PartTemplate> _parts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final services = await TemplatesRepository.loadServices();
    final parts = await TemplatesRepository.loadParts();
    if (mounted) {
      setState(() {
        _services = services;
        _parts = parts;
        _loading = false;
      });
    }
  }

  Future<void> _saveServices() async {
    await TemplatesRepository.saveServices(_services);
  }

  Future<void> _saveParts() async {
    await TemplatesRepository.saveParts(_parts);
  }

  void _addService() {
    _openEditDialog(
      title: 'افزودن خدمت',
      nameLabel: 'شرح خدمت',
      priceLabel: 'اجرت (تومان)',
      initialName: '',
      initialPrice: 0,
      onSave: (name, price, quantity, purchasePrice) async {
        setState(() => _services.add(ServiceTemplate(title: name, cost: price)));
        await _saveServices();
      },
    );
  }

  void _editService(int index) {
    final s = _services[index];
    _openEditDialog(
      title: 'ویرایش خدمت',
      nameLabel: 'شرح خدمت',
      priceLabel: 'اجرت (تومان)',
      initialName: s.title,
      initialPrice: s.cost,
      onSave: (name, price, quantity, purchasePrice) async {
        setState(() {
          s.title = name;
          s.cost = price;
        });
        await _saveServices();
      },
    );
  }

  void _deleteService(int index) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف خدمت', style: TextStyle(color: Colors.redAccent)),
        content: Text('آیا «${_services[index].title}» حذف شود؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              setState(() => _services.removeAt(index));
              await _saveServices();
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }

    void _addPart() {
    _openEditDialog(
      title: 'افزودن قطعه',
      nameLabel: 'نام قطعه',
      priceLabel: 'قیمت (تومان)',
      initialName: '',
      initialPrice: 0,
      initialQuantity: 0, // 👈 مقدار اولیه موجودی
      onSave: (name, price, quantity, purchasePrice) async {
        setState(() => _parts.add(PartTemplate(name: name, price: price, quantity: quantity, purchasePrice: purchasePrice)));
        await _saveParts();
      },
    );
  }

    void _editPart(int index) {
    final p = _parts[index];
    _openEditDialog(
      title: 'ویرایش قطعه',
      nameLabel: 'نام قطعه',
      priceLabel: 'قیمت (تومان)',
      initialName: p.name,
      initialPrice: p.price,
      initialQuantity: p.quantity,
      initialPurchasePrice: p.purchasePrice,
      onSave: (name, price, quantity, purchasePrice) async {
        setState(() {
          p.name = name;
          p.price = price;
          p.quantity = quantity;
          p.purchasePrice = purchasePrice;
        });
        await _saveParts();
      },
    );
  }

  void _deletePart(int index) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف قطعه', style: TextStyle(color: Colors.redAccent)),
        content: Text('آیا «${_parts[index].name}» حذف شود؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              setState(() => _parts.removeAt(index));
              await _saveParts();
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }

  void _resetServicesToDefault() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('بازگشت به پیش‌فرض'),
        content: const Text(
            'لیست خدمات به مقادیر پیش‌فرض اولیه برگردانده می‌شود. تغییرات شما از بین می‌رود. ادامه می‌دهید؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[800]),
            onPressed: () async {
              await TemplatesRepository.resetServicesToDefault();
              final defaults = await TemplatesRepository.loadServices();
              setState(() => _services = defaults);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('بازگشت به پیش‌فرض'),
          ),
        ],
      ),
    );
  }

    void _openEditDialog({
    required String title,
    required String nameLabel,
    required String priceLabel,
    required String initialName,
    required int initialPrice,
    int? initialQuantity,
    int initialPurchasePrice = 0,
    required Future<void> Function(String name, int price, int quantity, int purchasePrice) onSave,
  }) {
    final nameCtrl = TextEditingController(text: initialName);
    final priceCtrl = TextEditingController(text: initialPrice > 0 ? initialPrice.toString() : '');
    final qtyCtrl = TextEditingController(text: initialQuantity != null ? initialQuantity.toString() : '');
    final purchaseCtrl = TextEditingController(text: initialQuantity != null && initialPurchasePrice > 0 ? initialPurchasePrice.toString() : '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(labelText: nameLabel),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: priceCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9۰-۹٠-٩]'))],
                decoration: InputDecoration(labelText: priceLabel),
              ),
              if (initialQuantity != null) ...[
                const SizedBox(height: 8),
                TextField(controller: purchaseCtrl, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9۰-۹٠-٩]'))], decoration: const InputDecoration(labelText: 'بهای خرید هر عدد (تومان)')),
                const SizedBox(height: 8),
                TextField(
                  controller: qtyCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9۰-۹٠-٩]'))],
                  decoration: const InputDecoration(labelText: 'موجودی انبار (تعداد)'),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('نام نمی‌تواند خالی باشد.')),
                );
                return;
              }
              final price = NumberHelper.safeParseInt(priceCtrl.text);
              final qty = initialQuantity != null ? NumberHelper.safeParseInt(qtyCtrl.text) : 0;
              final purchasePrice = initialQuantity != null ? NumberHelper.safeParseInt(purchaseCtrl.text) : 0;
              Navigator.pop(ctx);
              await onSave(name, price, qty, purchasePrice);
            },
            child: const Text('ذخیره'),
          ),
        ],
      ),
    ).whenComplete(() {
      nameCtrl.dispose();
      priceCtrl.dispose();
      qtyCtrl.dispose();
      purchaseCtrl.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('⚙️ مدیریت قیمت‌ها'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.cyanAccent,
          labelColor: Colors.cyanAccent,
          tabs: [
            Tab(text: 'خدمات (${_services.length})'),
            Tab(text: 'قطعات (${_parts.length})'),
          ],
        ),
        actions: [
          if (_tabController.index == 0)
            IconButton(
              icon: const Icon(Icons.restore, color: Colors.orangeAccent),
              tooltip: 'بازگشت به پیش‌فرض',
              onPressed: _resetServicesToDefault,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildServiceList(cs),
                _buildPartList(cs),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: cs.primary,
        icon: Icon(
            _tabController.index == 0 ? Icons.add_task : Icons.add_box,
            color: Colors.white),
        label: Text(
          _tabController.index == 0 ? 'افزودن خدمت' : 'افزودن قطعه',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        onPressed: () {
          if (_tabController.index == 0) {
            _addService();
          } else {
            _addPart();
          }
        },
      ),
    );
  }

  Widget _buildServiceList(ColorScheme cs) {
    if (_services.isEmpty) {
      return Center(
        child: Text('لیست خدمات خالی است. دکمه‌ی افزودن را بزنید.',
            style: TextStyle(color: cs.onSurfaceVariant)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _services.length,
      itemBuilder: (_, i) {
        final s = _services[i];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: cs.primary.withOpacity(0.2),
              child: const Icon(Icons.build_circle, color: Colors.cyanAccent),
            ),
            title: Text(s.title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            subtitle: Text(formatToman(s.cost),
                style: const TextStyle(fontSize: 12, color: Colors.greenAccent)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, size: 18, color: Colors.cyanAccent),
                  onPressed: () => _editService(i),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      size: 18, color: Colors.redAccent),
                  onPressed: () => _deleteService(i),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPartList(ColorScheme cs) {
    if (_parts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            'هنوز قطعه‌ای تعریف نکرده‌اید.\nقطعاتی که زیاد استفاده می‌کنید را اینجا اضافه کنید تا در فاکتور سریع درج شوند.',
            textAlign: TextAlign.center,
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _parts.length,
      itemBuilder: (_, i) {
        final p = _parts[i];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.amber.withOpacity(0.2),
              child: const Icon(Icons.settings_input_component, color: Colors.amberAccent),
            ),
            title: Text(p.name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: Text(
              '${formatToman(p.price)}  |  موجودی: ${p.quantity} عدد',
              style: const TextStyle(fontSize: 12, color: Colors.greenAccent),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, size: 18, color: Colors.cyanAccent),
                  onPressed: () => _editPart(i),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      size: 18, color: Colors.redAccent),
                  onPressed: () => _deletePart(i),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ======================== ویجت پلاک ========================
class RealisticPlateBadge extends StatelessWidget {
  final Car car;
  const RealisticPlateBadge({super.key, required this.car});

  @override
  Widget build(BuildContext context) {
    if (car.plateType == PlateType.national) return _buildNationalBadge();
    return _buildCustomBadge();
  }

  Widget _buildNationalBadge() {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.black87, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 14,
              height: 26,
              decoration: BoxDecoration(
                color: const Color(0xFF003399),
                borderRadius: BorderRadius.circular(2),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('🇮🇷', style: TextStyle(fontSize: 6)),
                  Text('IR',
                      style: TextStyle(
                          color: Colors.white, fontSize: 5, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Text(car.plateTwoDigits,
                style: const TextStyle(
                    color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(width: 3),
            Text(car.plateLetter,
                style: const TextStyle(
                    color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(width: 3),
            Text(car.plateThreeDigits,
                style: const TextStyle(
                    color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13)),
            Container(
                height: 20,
                width: 1,
                color: Colors.black38,
                margin: const EdgeInsets.symmetric(horizontal: 4)),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('ایران', style: TextStyle(color: Colors.black, fontSize: 7, height: 1)),
                Text(car.plateProvinceCode,
                    style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                        height: 1)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomBadge() {
    late Color bg, borderColor, textColor;
    late IconData icon;
    late String label;

    switch (car.plateType) {
      case PlateType.temporary:
        bg = Colors.white;
        borderColor = Colors.red;
        textColor = Colors.red[800]!;
        icon = Icons.timer;
        label = 'گذر موقت';
        break;
      case PlateType.freeZone:
        bg = const Color(0xFFE8F5E9);
        borderColor = Colors.green[800]!;
        textColor = Colors.green[900]!;
        icon = Icons.beach_access;
        label = car.freeZoneName.isNotEmpty ? car.freeZoneName : 'منطقه آزاد';
        break;
      case PlateType.regional:
        bg = const Color(0xFFFFF3E0);
        borderColor = Colors.orange[800]!;
        textColor = Colors.orange[900]!;
        icon = Icons.place;
        label = 'منطقه‌ای';
        break;
      case PlateType.personal:
        bg = const Color(0xFFF3E5F5);
        borderColor = Colors.purple[800]!;
        textColor = Colors.purple[900]!;
        icon = Icons.star;
        label = 'شخصی';
        break;
      default:
        bg = Colors.grey[200]!;
        borderColor = Colors.grey;
        textColor = Colors.black;
        icon = Icons.directions_car;
        label = '';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 10, color: textColor),
              const SizedBox(width: 3),
              Text(label,
                  style: TextStyle(
                      color: textColor, fontSize: 8, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 2),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 110),
            child: Text(
              car.customPlate.isNotEmpty ? car.customPlate : 'بدون شماره',
              style: TextStyle(
                  color: textColor, fontSize: 11, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

// ======================== دیالوگ خودرو ========================
class _CarEditDialog extends StatefulWidget {
  final Car? carToEdit;
  final Customer customer;
  final List<Customer> existingCustomers;
  final void Function(Customer owner) onGoToExisting;
  final Function(
    String model,
    String two,
    String letter,
    String three,
    String prov,
    PlateType plateType,
    String customPlate,
    String freeZoneName,
  ) onSave;

  const _CarEditDialog({
    this.carToEdit,
    required this.customer,
    required this.existingCustomers,
    required this.onGoToExisting,
    required this.onSave,
  });

  @override
  State<_CarEditDialog> createState() => _CarEditDialogState();
}

class _CarEditDialogState extends State<_CarEditDialog> {
  late final TextEditingController modelCtrl;
  late final TextEditingController twoCtrl;
  late final TextEditingController threeCtrl;
  late final TextEditingController provCtrl;
  late final TextEditingController customPlateCtrl;
  late String selectedLetter;
  late List<String> _availableLetters;
  late PlateType _plateType;
  late String _freeZoneName;

  final FocusNode twoFocus = FocusNode();
  final FocusNode threeFocus = FocusNode();
  final FocusNode provFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    modelCtrl = TextEditingController(text: widget.carToEdit?.model ?? '');
    twoCtrl = TextEditingController(text: widget.carToEdit?.plateTwoDigits ?? '');
    threeCtrl = TextEditingController(text: widget.carToEdit?.plateThreeDigits ?? '');
    provCtrl = TextEditingController(text: widget.carToEdit?.plateProvinceCode ?? '');
    customPlateCtrl = TextEditingController(text: widget.carToEdit?.customPlate ?? '');
    _plateType = widget.carToEdit?.plateType ?? PlateType.national;
    _freeZoneName = (widget.carToEdit?.freeZoneName.isNotEmpty == true)
        ? widget.carToEdit!.freeZoneName
        : kFreeZones.first;

    final oldLetter = normalizePlateLetter(widget.carToEdit?.plateLetter ?? '');
    _availableLetters = [...kIranPlateLetters];
    if (oldLetter.isNotEmpty && !_availableLetters.contains(oldLetter)) {
      _availableLetters.add(oldLetter);
    }
    selectedLetter =
        _availableLetters.contains(oldLetter) ? oldLetter : _availableLetters.first;
  }

  @override
  void dispose() {
    modelCtrl.dispose();
    twoCtrl.dispose();
    threeCtrl.dispose();
    provCtrl.dispose();
    customPlateCtrl.dispose();
    twoFocus.dispose();
    threeFocus.dispose();
    provFocus.dispose();
    super.dispose();
  }

  List<TextInputFormatter> get _digitFormatters => [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9۰-۹٠-٩]')),
      ];

  void _trySave({required bool force}) {
    final model = modelCtrl.text.trim();
    if (model.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('لطفاً مدل خودرو را وارد کنید.')));
      return;
    }

    final newCar = Car(
      id: widget.carToEdit?.id ?? 'temp',
      model: model,
      plateType: _plateType,
      plateTwoDigits: NumberHelper.cleanNumbers(twoCtrl.text),
      plateLetter: selectedLetter.trim(),
      plateThreeDigits: NumberHelper.cleanNumbers(threeCtrl.text),
      plateProvinceCode: NumberHelper.cleanNumbers(provCtrl.text),
      customPlate: customPlateCtrl.text.trim(),
      freeZoneName: _plateType == PlateType.freeZone ? _freeZoneName : '',
      services: const [],
    );

    if (_plateType == PlateType.national) {
      final hasTwo = newCar.plateTwoDigits.isNotEmpty;
      final hasThree = newCar.plateThreeDigits.isNotEmpty;
      if (hasTwo != hasThree) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('پلاک ملی باید هر دو بخش شماره را داشته باشد.')),
        );
        return;
      }
    } else {
      if (newCar.customPlate.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('لطفاً متن پلاک ${plateTypeLabel(_plateType)} را وارد کنید.')),
        );
        return;
      }
    }

    if (!force && newCar.hasAnyPlate) {
      for (final cust in widget.existingCustomers) {
        for (final car in cust.cars) {
          if (widget.carToEdit != null && car.id == widget.carToEdit!.id) continue;
          if (car.matchesPlate(newCar)) {
            _showDuplicatePlateDialog(cust, car);
            return;
          }
        }
      }
    }

    widget.onSave(
      model,
      newCar.plateTwoDigits,
      newCar.plateLetter,
      newCar.plateThreeDigits,
      newCar.plateProvinceCode,
      newCar.plateType,
      newCar.customPlate,
      newCar.freeZoneName,
    );
    Navigator.pop(context);
  }

  void _showDuplicatePlateDialog(Customer owner, Car existingCar) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.warning_amber, color: Colors.amber),
          SizedBox(width: 8),
          Text('پلاک تکراری'),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'این پلاک (${plateTypeLabel(existingCar.plateType)}) قبلاً برای خودروی «${existingCar.model}» در پرونده «${owner.name}» ثبت شده است.'),
            const SizedBox(height: 10),
            const Text('می‌خواهید به پرونده‌ی مالک بروید یا پلاک را به‌هرحال ثبت کنید؟',
                style: TextStyle(fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
          ElevatedButton.icon(
            icon: const Icon(Icons.folder_open, size: 16),
            label: const Text('برو به پرونده مالک'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal[700]),
            onPressed: () {
              Navigator.pop(ctx);
              widget.onGoToExisting(owner);
            },
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.save, size: 16),
            label: const Text('ثبت به‌هرحال'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[800]),
            onPressed: () {
              Navigator.pop(ctx);
              _trySave(force: true);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(widget.carToEdit == null ? 'افزودن خودرو' : 'ویرایش خودرو'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: modelCtrl,
              decoration: const InputDecoration(
                  labelText: 'مدل خودرو (مثلاً: پژو ۲۰۶ سفید)'),
            ),
            const SizedBox(height: 8),
            Text('انتخاب سریع خودرو:',
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
            const SizedBox(height: 4),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: kPopularCars.take(8).map((carName) {
                  return Padding(
                    padding: const EdgeInsets.only(left: 6.0),
                    child: ActionChip(
                      label: Text(carName, style: const TextStyle(fontSize: 11)),
                      onPressed: () => setState(() => modelCtrl.text = carName),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 14),
            const Text('نوع پلاک:',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.cyanAccent)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: PlateType.values.map((type) {
                final selected = _plateType == type;
                return ChoiceChip(
                  selected: selected,
                  label: Text(plateTypeLabel(type),
                      style: TextStyle(
                          fontSize: 11,
                          color: selected ? Colors.white : cs.onSurface)),
                  selectedColor: cs.primary,
                  onSelected: (_) => setState(() => _plateType = type),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            if (_plateType == PlateType.national) ...[
              const Text('شماره پلاک ملی:',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.cyanAccent)),
              const SizedBox(height: 6),
              _buildNationalPlateInput(cs),
            ] else if (_plateType == PlateType.freeZone) ...[
              Row(children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _freeZoneName,
                    decoration: const InputDecoration(labelText: 'منطقه آزاد'),
                    items: kFreeZones
                        .map((z) => DropdownMenuItem(value: z, child: Text(z)))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _freeZoneName = v ?? kFreeZones.first),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: customPlateCtrl,
                    decoration: const InputDecoration(
                        labelText: 'شماره سریال پلاک', hintText: 'مثلاً: ۱۲۳۴۵'),
                  ),
                ),
              ]),
            ] else ...[
              TextField(
                controller: customPlateCtrl,
                decoration: InputDecoration(
                  labelText: _plateType == PlateType.temporary
                      ? 'متن کامل پلاک گذر موقت'
                      : _plateType == PlateType.regional
                          ? 'متن کامل پلاک منطقه‌ای'
                          : 'شماره/متن پلاک شخصی',
                  hintText: _plateType == PlateType.temporary
                      ? 'مثلاً: ۱۲ گ ۳۴۵ گذر موقت'
                      : _plateType == PlateType.regional
                          ? 'مثلاً: مرزی ۱۲۳۴۵'
                          : 'مثلاً: ۱۲۳۴۵ - الف',
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('انصراف')),
        ElevatedButton(
            onPressed: () => _trySave(force: false), child: const Text('ذخیره')),
      ],
    );
  }

  Widget _buildNationalPlateInput(ColorScheme cs) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.amberAccent, width: 2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 22,
              height: 48,
              decoration: BoxDecoration(
                  color: const Color(0xFF003399),
                  borderRadius: BorderRadius.circular(4)),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('🇮🇷', style: TextStyle(fontSize: 8)),
                  Text('I.R.',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 6,
                          fontWeight: FontWeight.bold)),
                  Text('IRAN', style: TextStyle(color: Colors.white, fontSize: 5)),
                ],
              ),
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: 44,
              child: TextField(
                controller: twoCtrl,
                focusNode: twoFocus,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 2,
                inputFormatters: _digitFormatters,
                style: const TextStyle(
                    color: Colors.black, fontWeight: FontWeight.bold, fontSize: 17),
                decoration: const InputDecoration(
                    counterText: '',
                    hintText: '۲۲',
                    hintStyle: TextStyle(color: Colors.grey),
                    border: InputBorder.none,
                    filled: false,
                    isDense: true,
                    contentPadding: EdgeInsets.zero),
                onChanged: (val) {
                  if (val.length == 2) FocusScope.of(context).requestFocus(threeFocus);
                },
              ),
            ),
            DropdownButton<String>(
              value: selectedLetter,
              dropdownColor: cs.surfaceContainerHighest,
              underline: const SizedBox(),
              style: const TextStyle(
                  color: Colors.blueAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 17),
              items: _availableLetters
                  .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                  .toList(),
              onChanged: (v) =>
                  setState(() => selectedLetter = v ?? _availableLetters.first),
            ),
            SizedBox(
              width: 58,
              child: TextField(
                controller: threeCtrl,
                focusNode: threeFocus,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 3,
                inputFormatters: _digitFormatters,
                style: const TextStyle(
                    color: Colors.black, fontWeight: FontWeight.bold, fontSize: 17),
                decoration: const InputDecoration(
                    counterText: '',
                    hintText: '۳۶۵',
                    hintStyle: TextStyle(color: Colors.grey),
                    border: InputBorder.none,
                    filled: false,
                    isDense: true,
                    contentPadding: EdgeInsets.zero),
                onChanged: (val) {
                  if (val.length == 3) FocusScope.of(context).requestFocus(provFocus);
                },
              ),
            ),
            Container(
                height: 38,
                width: 1.5,
                color: Colors.black45,
                margin: const EdgeInsets.symmetric(horizontal: 4)),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('ایران',
                    style: TextStyle(
                        color: Colors.black,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        height: 1)),
                SizedBox(
                  width: 38,
                  height: 32,
                  child: TextField(
                    controller: provCtrl,
                    focusNode: provFocus,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 2,
                    inputFormatters: _digitFormatters,
                    style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 15),
                    decoration: const InputDecoration(
                        counterText: '',
                        hintText: '۶۸',
                        hintStyle: TextStyle(color: Colors.grey),
                        border: InputBorder.none,
                        filled: false,
                        isDense: true,
                        contentPadding: EdgeInsets.zero),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ======================== دیالوگ مشتری ========================
class _CustomerEditDialog extends StatefulWidget {
  final Customer? customer;
  final List<Customer> existingCustomers;
  final void Function(Customer existing) onGoToExisting;
  final Function(String name, String phone) onSave;

  const _CustomerEditDialog({
    this.customer,
    required this.existingCustomers,
    required this.onGoToExisting,
    required this.onSave,
  });

  @override
  State<_CustomerEditDialog> createState() => _CustomerEditDialogState();
}

class _CustomerEditDialogState extends State<_CustomerEditDialog> {
  late final TextEditingController nameCtrl;
  late final TextEditingController phoneCtrl;

  @override
  void initState() {
    super.initState();
    nameCtrl = TextEditingController(text: widget.customer?.name ?? '');
    phoneCtrl = TextEditingController(text: widget.customer?.phone ?? '');
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    phoneCtrl.dispose();
    super.dispose();
  }

  void _trySave({required bool force}) {
    final name = nameCtrl.text.trim();
    final rawPhone = phoneCtrl.text.trim();
    final cleanPhone = NumberHelper.cleanNumbers(rawPhone);
    final normPhone = NumberHelper.normalizePhone(rawPhone);

    if (name.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('لطفاً نام مشتری را وارد کنید.')));
      return;
    }

    if (!force && normPhone.isNotEmpty) {
      for (final c in widget.existingCustomers) {
        if (widget.customer != null && c.id == widget.customer!.id) continue;
        if (NumberHelper.normalizePhone(c.phone) == normPhone) {
          _showDuplicatePhoneDialog(c);
          return;
        }
      }
    }

    widget.onSave(name, cleanPhone);
    Navigator.pop(context);
  }

  void _showDuplicatePhoneDialog(Customer existing) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.warning_amber, color: Colors.amber),
          SizedBox(width: 8),
          Text('شماره تکراری'),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('این شماره قبلاً برای پرونده «${existing.name}» ثبت شده است.'),
            const SizedBox(height: 8),
            if (existing.cars.isNotEmpty)
              Text('خودروها: ${existing.cars.map((c) => c.model).join('، ')}',
                  style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 10),
            const Text('می‌خواهید به پرونده‌ی موجود بروید یا این شماره را به‌هرحال ذخیره کنید؟',
                style: TextStyle(fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
          ElevatedButton.icon(
            icon: const Icon(Icons.folder_open, size: 16),
            label: const Text('برو به پرونده'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal[700]),
            onPressed: () {
              Navigator.pop(ctx);
              widget.onGoToExisting(existing);
            },
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.save, size: 16),
            label: const Text('ذخیره به‌هرحال'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[800]),
            onPressed: () {
              Navigator.pop(ctx);
              _trySave(force: true);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.customer == null ? 'ثبت مشتری جدید' : 'ویرایش مشتری'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'نام و نام خانوادگی')),
          const SizedBox(height: 8),
          TextField(
            controller: phoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'شماره همراه'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('انصراف')),
        ElevatedButton(onPressed: () => _trySave(force: false), child: const Text('ذخیره')),
      ],
    );
  }
}

// ======================== صفحه سوابق خودرو ========================
class CarServicesScreen extends StatefulWidget {
  final Customer customer;
  final Car car;
  final VoidCallback onChanged;
  const CarServicesScreen({
    super.key,
    required this.customer,
    required this.car,
    required this.onChanged,
  });

  @override
  State<CarServicesScreen> createState() => _CarServicesScreenState();
}

class _CarServicesScreenState extends State<CarServicesScreen> {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.car.model} (${widget.customer.name})'),
      ),
      body: widget.car.services.isEmpty
          ? Center(
              child: Text('هنوز فاکتوری برای این خودرو ثبت نشده است.',
                  style: TextStyle(color: cs.onSurfaceVariant)))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: widget.car.services.length,
              itemBuilder: (_, i) {
                final s = widget.car.services[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('📅 تاریخ: ${s.date}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: Colors.amberAccent)),
                                if (s.km.isNotEmpty)
                                  Text('🚗 کارکرد: ${s.km} km',
                                      style: TextStyle(
                                          fontSize: 12, color: cs.onSurfaceVariant)),
                              ],
                            ),
                            Row(children: [
                              IconButton(
                                icon: const Icon(Icons.edit,
                                    size: 18, color: Colors.cyanAccent),
                                onPressed: () => _openServiceDialog(serviceToEdit: s),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    size: 18, color: Colors.redAccent),
                                onPressed: () => _confirmDeleteService(s),
                              ),
                            ]),
                          ],
                        ),
                        if (s.warrantyNote.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                                color: cs.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(6)),
                            child: Text('🛡 گارانتی: ${s.warrantyNote}',
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.cyanAccent)),
                          ),
                        ],
                        const Divider(height: 16),
                        ...s.labors.map((l) => Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('• ${l.title}', style: const TextStyle(fontSize: 12)),
                                Text(formatToman(l.cost),
                                    style: TextStyle(
                                        fontSize: 12, color: cs.onSurfaceVariant)),
                              ],
                            )),
                        ...s.parts.map((p) => Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('• قطعه: ${p.name}',
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.amberAccent)),
                                Text(formatToman(p.price),
                                    style: TextStyle(
                                        fontSize: 12, color: cs.onSurfaceVariant)),
                              ],
                            )),
                        const Divider(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('جمع کل نهایی:',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 13)),
                            Text(formatToman(s.grandTotal),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Colors.greenAccent)),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('پرداخت شده (${s.paymentMethod}):',
                                style: TextStyle(
                                    fontSize: 12, color: cs.onSurfaceVariant)),
                            Text(formatToman(s.paidAmount),
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.cyanAccent)),
                          ],
                        ),
                        if (s.remainingDebt > 0)
                          Container(
                            margin: const EdgeInsets.only(top: 6),
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                                color: Colors.red[900]?.withOpacity(0.35),
                                borderRadius: BorderRadius.circular(6)),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('مانده بدهی (نسیه):',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        fontSize: 12)),
                                Text(formatToman(s.remainingDebt),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.redAccent,
                                        fontSize: 13)),
                              ],
                            ),
                          ),
                        const SizedBox(height: 10),
                        Wrap(spacing: 8, children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal[800]),
                            icon: const Icon(Icons.sms, size: 14, color: Colors.white),
                            label: const Text('پیامک تحویل',
                                style: TextStyle(color: Colors.white, fontSize: 11)),
                            onPressed: () => _sendSmsNotification(s),
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.purple[800]),
                            icon: const Icon(Icons.receipt, size: 14, color: Colors.white),
                            label: const Text('فیش حرارتی',
                                style: TextStyle(color: Colors.white, fontSize: 11)),
                            onPressed: () => _printPdfInvoice(s, isThermal: true),
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: cs.primary),
                            icon: const Icon(Icons.print, size: 14, color: Colors.white),
                            label: const Text('فاکتور A4',
                                style: TextStyle(color: Colors.white, fontSize: 11)),
                            onPressed: () => _printPdfInvoice(s, isThermal: false),
                          ),
                        ]),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: cs.primary,
        icon: const Icon(Icons.note_add, color: Colors.white),
        label: const Text('ثبت فاکتور جدید',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () => _openServiceDialog(),
      ),
    );
  }

  void _confirmDeleteService(ServiceRecord s) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف فاکتور'),
        content: const Text('آیا از حذف این فاکتور مطمئن هستید؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              try {
                final trackedCounts = <String, int>{};
                for (final part in s.parts) {
                  if (part.fromInventory) {
                    trackedCounts[part.name] = (trackedCounts[part.name] ?? 0) + 1;
                  }
                }
                if (trackedCounts.isNotEmpty) {
                  final templates = await TemplatesRepository.loadParts();
                  for (final entry in trackedCounts.entries) {
                    final index = templates.indexWhere((t) => t.name == entry.key);
                    if (index >= 0) {
                      templates[index].quantity += entry.value;
                    }
                  }
                  await TemplatesRepository.saveParts(templates);
                }
                if (!mounted) return;
                setState(() => widget.car.services.removeWhere((item) => item.id == s.id));
                widget.onChanged();
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('حذف فاکتور انجام نشد: $e')),
                  );
                }
              }
            },
            child: const Text('حذف'),
          )
        ],
      ),
    );
  }


    Future<void> _sendSmsNotification(ServiceRecord s) async {
    final cleanPhone = NumberHelper.cleanNumbers(widget.customer.phone);
    if (cleanPhone.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('شماره همراه مشتری ثبت نشده است!')));
      return;
    }

    final b = StringBuffer();
    b.writeln('مشتری گرامی ${widget.customer.name}');
    b.writeln('خودروی ${widget.car.model} (${widget.car.fullPlate}).');
    if (s.labors.isNotEmpty) {
      b.writeln('🔧 خدمات انجام شده:');
      for (final l in s.labors) {
        b.writeln('• ${l.title}: ${formatToman(l.cost)}');
      }
    }
    if (s.parts.isNotEmpty) {
      if (s.labors.isNotEmpty) b.writeln('');
      b.writeln('🔩 قطعات و لوازم:');
      for (final p in s.parts) {
        b.writeln('• ${p.name}: ${formatToman(p.price)}');
      }
    }
    b.writeln('💰 جمع کل: ${formatToman(s.grandTotal)}');
    if (s.discount > 0) b.writeln('🎁 تخفیف: ${formatToman(s.discount)}');
    b.writeln('💳 پرداختی: ${formatToman(s.paidAmount)}');
    if (s.remainingDebt > 0) {
      b.writeln('⚠️ مانده حساب (بدهی): ${formatToman(s.remainingDebt)}');
    }
    if (s.warrantyNote.isNotEmpty) b.writeln('🛡 : ${s.warrantyNote}');
    b.writeln('⚡ ۰۹۱۸۹۱۶۲۹۳۹ کلینیک برق خودرو مهندس');

    // 👈 تغییر اصلی اینجاست: استفاده از SmsHelper به جای _launchSms
    final ok = await SmsHelper.sendSms(
      phoneNumber: cleanPhone,
      message: b.toString(),
    );
    
    // 👈 پیام خطا هم متناسب با ارسال پس‌زمینه تغییر کرد
    if (mounted) {
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('پیامک تحویل خودرو با موفقیت ارسال شد.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('خطا در ارسال پیامک. لطفاً مجوز ارسال پیامک را بررسی کنید.'),
              backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _printPdfInvoice(ServiceRecord service, {required bool isThermal}) async {
    try {
      final regularData = await rootBundle.load('assets/fonts/Vazirmatn-Regular.ttf');
      final boldData = await rootBundle.load('assets/fonts/Vazirmatn-Bold.ttf');
      final farsiFont = pw.Font.ttf(regularData);
      final farsiFontBold = pw.Font.ttf(boldData);

      final pdf = pw.Document(
        theme: pw.ThemeData.withFont(base: farsiFont, bold: farsiFontBold),
      );
      final pageFormat = isThermal ? PdfPageFormat.roll80 : PdfPageFormat.a4;

      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          textDirection: pw.TextDirection.rtl,
          build: (_) {
            return pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                mainAxisSize: pw.MainAxisSize.min,
                children: [
                  pw.Center(
                    child: pw.Text(
                      'کلینیک برق خودرو مهندس',
                      style: pw.TextStyle(
                          fontSize: isThermal ? 13 : 18,
                          fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                  pw.Divider(),
                  pw.Text(
                      'مشتری: ${widget.customer.name}  |  تلفن: ${widget.customer.phone}',
                      style: pw.TextStyle(fontSize: isThermal ? 8 : 10)),
                  pw.Text('خودرو: ${widget.car.model}  |  پلاک: ${widget.car.fullPlate}',
                      style: pw.TextStyle(fontSize: isThermal ? 8 : 10)),
                  pw.Text('تاریخ: ${service.date}',
                      style: pw.TextStyle(fontSize: isThermal ? 8 : 10)),
                  pw.Divider(),
                  ...service.labors.map((l) => pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(l.title,
                              style: pw.TextStyle(fontSize: isThermal ? 8 : 10)),
                          pw.Text(formatToman(l.cost),
                              style: pw.TextStyle(fontSize: isThermal ? 8 : 10)),
                        ],
                      )),
                  if (service.parts.isNotEmpty) ...[
                    pw.Divider(),
                    ...service.parts.map((p) => pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('قطعه: ${p.name}',
                                style: pw.TextStyle(fontSize: isThermal ? 8 : 10)),
                            pw.Text(formatToman(p.price),
                                style: pw.TextStyle(fontSize: isThermal ? 8 : 10)),
                          ],
                        )),
                  ],
                  pw.Divider(),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('مبلغ نهایی:',
                          style: pw.TextStyle(
                              fontSize: isThermal ? 9 : 11,
                              fontWeight: pw.FontWeight.bold)),
                      pw.Text(formatToman(service.grandTotal),
                          style: pw.TextStyle(
                              fontSize: isThermal ? 9 : 11,
                              fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (_) async => pdf.save(),
        name: 'فاکتور_${widget.customer.name}_${service.date}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('خطا در صدور PDF: $e')));
      }
    }
  }

  void _openServiceDialog({ServiceRecord? serviceToEdit}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ServiceEditDialog(
        serviceToEdit: serviceToEdit,
        onSave: (record) {
          setState(() {
            if (serviceToEdit == null) {
              widget.car.services.insert(0, record);
            } else {
              serviceToEdit.date = record.date;
              serviceToEdit.km = record.km;
              serviceToEdit.warrantyNote = record.warrantyNote;
              serviceToEdit.paymentMethod = record.paymentMethod;
              serviceToEdit.discount = record.discount;
              serviceToEdit.paidAmount = record.paidAmount;
              serviceToEdit.labors = record.labors;
              serviceToEdit.parts = record.parts;
            }
          });
          widget.onChanged();
        },
      ),
    );
  }
}

// ======================== دیالوگ فاکتور ========================
class _ServiceEditDialog extends StatefulWidget {
  final ServiceRecord? serviceToEdit;
  final Function(ServiceRecord) onSave;
  const _ServiceEditDialog({this.serviceToEdit, required this.onSave});
  @override
  State<_ServiceEditDialog> createState() => _ServiceEditDialogState();
}

class _ServiceEditDialogState extends State<_ServiceEditDialog> {
  late final TextEditingController dateCtrl;
  late final TextEditingController kmCtrl;
  late final TextEditingController warrantyCtrl;
  late final TextEditingController discountCtrl;
  late final TextEditingController paidCtrl;
  String paymentMethod = 'کارت‌خوان (POS)';
  late final List<LaborItem> laborsList;
  late final List<PartItem> partsList;

  List<ServiceTemplate> _serviceTemplates = [];
  List<PartTemplate> _partTemplates = [];
  bool _templatesLoaded = false;

  @override
  void initState() {
    super.initState();
    final s = widget.serviceToEdit;
    dateCtrl = TextEditingController(text: s?.date ?? JalaliHelper.nowShamsi());
    kmCtrl = TextEditingController(text: s?.km ?? '');
    warrantyCtrl = TextEditingController(text: s?.warrantyNote ?? '');
    discountCtrl =
        TextEditingController(text: s != null && s.discount > 0 ? s.discount.toString() : '');
    paidCtrl = TextEditingController(text: s != null ? s.paidAmount.toString() : '');
    paymentMethod = s?.paymentMethod ?? 'کارت‌خوان (POS)';
    laborsList = s != null
        ? s.labors.map((l) => LaborItem(title: l.title, cost: l.cost)).toList()
        : [];
    partsList = s != null
        ? s.parts.map((p) => PartItem(name: p.name, price: p.price, fromInventory: p.fromInventory, unitCost: p.unitCost)).toList()
        : [];

    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    final services = await TemplatesRepository.loadServices();
    final parts = await TemplatesRepository.loadParts();
    if (mounted) {
      setState(() {
        _serviceTemplates = services;
        _partTemplates = parts;
        _templatesLoaded = true;
      });
    }
  }

  @override
  void dispose() {
    dateCtrl.dispose();
    kmCtrl.dispose();
    warrantyCtrl.dispose();
    discountCtrl.dispose();
    paidCtrl.dispose();
    super.dispose();
  }

  bool get _isDirty {
    final s = widget.serviceToEdit;
    if (s == null) {
      if (dateCtrl.text.trim() != JalaliHelper.nowShamsi()) return true;
      if (kmCtrl.text.trim().isNotEmpty) return true;
      if (warrantyCtrl.text.trim().isNotEmpty) return true;
      if (discountCtrl.text.trim().isNotEmpty &&
          NumberHelper.safeParseInt(discountCtrl.text) != 0) {
        return true;
      }
      if (paidCtrl.text.trim().isNotEmpty &&
          NumberHelper.safeParseInt(paidCtrl.text) != 0) {
        return true;
      }
      if (paymentMethod != 'کارت‌خوان (POS)') return true;
      if (laborsList.isNotEmpty) return true;
      if (partsList.isNotEmpty) return true;
      return false;
    }
    if (dateCtrl.text.trim() != s.date) return true;
    if (kmCtrl.text.trim() != s.km) return true;
    if (warrantyCtrl.text.trim() != s.warrantyNote) return true;
    if (NumberHelper.safeParseInt(discountCtrl.text) != s.discount) return true;
    if (NumberHelper.safeParseInt(paidCtrl.text) != s.paidAmount) return true;
    if (paymentMethod != s.paymentMethod) return true;
    if (laborsList.length != s.labors.length) return true;
    for (int i = 0; i < laborsList.length; i++) {
      if (laborsList[i].title != s.labors[i].title ||
          laborsList[i].cost != s.labors[i].cost) {
        return true;
      }
    }
    if (partsList.length != s.parts.length) return true;
    for (int i = 0; i < partsList.length; i++) {
      if (partsList[i].name != s.parts[i].name ||
          partsList[i].price != s.parts[i].price ||
          partsList[i].fromInventory != s.parts[i].fromInventory) {
        return true;
      }
    }
    return false;
  }

  Future<bool> _confirmExitWithoutSave() async {
    if (!_isDirty) return true;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.warning_amber, color: Colors.amber),
          SizedBox(width: 8),
          Text('خروج بدون ذخیره؟'),
        ]),
        content: const Text(
            'تغییرات شما ذخیره نشده است. آیا می‌خواهید بدون ذخیره خارج شوید؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ادامه ویرایش'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('خروج بدون ذخیره'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<bool> _applyInventoryChanges() async {
    final templates = _partTemplates;
    final oldCounts = <String, int>{};
    final newCounts = <String, int>{};

    for (final part in widget.serviceToEdit?.parts ?? <PartItem>[]) {
      if (part.fromInventory) {
        oldCounts[part.name] = (oldCounts[part.name] ?? 0) + 1;
      }
    }
    for (final part in partsList) {
      if (part.fromInventory) {
        newCounts[part.name] = (newCounts[part.name] ?? 0) + 1;
      }
    }

    final names = <String>{...oldCounts.keys, ...newCounts.keys};
    for (final name in names) {
      final templateIndex = templates.indexWhere((t) => t.name == name);
      if (templateIndex < 0 && (newCounts[name] ?? 0) > (oldCounts[name] ?? 0)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('قطعه «$name» در فهرست انبار پیدا نشد.')),
          );
        }
        return false;
      }
      if (templateIndex >= 0) {
        final template = templates[templateIndex];
        final delta = (oldCounts[name] ?? 0) - (newCounts[name] ?? 0);
        final resultingQuantity = template.quantity + delta;
        if (resultingQuantity < 0) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('موجودی قطعه «$name» کافی نیست. موجودی فعلی: ${template.quantity}')),
            );
          }
          return false;
        }
      }
    }

    for (final name in names) {
      final templateIndex = templates.indexWhere((t) => t.name == name);
      if (templateIndex >= 0) {
        templates[templateIndex].quantity +=
            (oldCounts[name] ?? 0) - (newCounts[name] ?? 0);
      }
    }
    await TemplatesRepository.saveParts(templates);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    int subTotal = laborsList.fold(0, (s, i) => s + i.cost) +
        partsList.fold(0, (s, i) => s + i.price);
    int discount = NumberHelper.safeParseInt(discountCtrl.text);
    int grandTotal = (subTotal - discount) > 0 ? (subTotal - discount) : 0;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmExitWithoutSave()) {
          if (mounted) Navigator.pop(context);
        }
      },
      child: AlertDialog(
        title: Text(widget.serviceToEdit == null ? 'ثبت فاکتور جدید' : 'ویرایش فاکتور'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                      child: TextField(
                          controller: dateCtrl,
                          decoration: const InputDecoration(labelText: 'تاریخ فاکتور'))),
                  const SizedBox(width: 8),
                  Expanded(
                      child: TextField(
                          controller: kmCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[0-9۰-۹٠-٩]'))
                          ],
                          decoration: const InputDecoration(labelText: 'کیلومتر ماشین'))),
                ]),
                TextField(
                    controller: warrantyCtrl,
                    decoration: const InputDecoration(labelText: 'یادداشت/گارانتی قطعه')),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('🔧 خدمات پیش‌فرض (کلیک برای افزودن):',
                        style: TextStyle(fontSize: 11, color: Colors.cyanAccent)),
                    IconButton(
                      icon: const Icon(Icons.tune, size: 16, color: Colors.amberAccent),
                      tooltip: 'مدیریت قیمت‌ها',
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const TemplatesManagerScreen()),
                        );
                        await _loadTemplates();
                      },
                    ),
                  ],
                ),
                if (!_templatesLoaded)
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                else if (_serviceTemplates.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text('هیچ خدمت پیش‌فرضی تعریف نشده است.',
                        style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                  )
                else
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _serviceTemplates.map((t) {
                        return Padding(
                          padding: const EdgeInsets.only(left: 6.0),
                          child: ActionChip(
                            backgroundColor: cs.surfaceContainerHighest,
                            side: BorderSide(color: cs.outline),
                            avatar: const Icon(Icons.add, size: 14,
                                color: Colors.cyanAccent),
                            label: Text('${t.title}',
                                style: const TextStyle(fontSize: 11)),
                            onPressed: () {
                              setState(() {
                                laborsList.add(
                                    LaborItem(title: t.title, cost: t.cost));
                              });
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                const SizedBox(height: 10),
                _buildItemBox(
                  cs: cs,
                  title: '🔧 لیست خدمات:',
                  titleColor: Colors.cyanAccent,
                  addLabel: 'دستی',
                  addIconColor: cs.primary,
                  items: laborsList
                      .asMap()
                      .entries
                      .map((e) => _buildListItemRow(
                            cs: cs,
                            label: '• ${e.value.title}: ${formatToman(e.value.cost)}',
                            onRemove: () =>
                                setState(() => laborsList.removeAt(e.key)),
                          ))
                      .toList(),
                  onAddManual: () => _openAddItemDialog(isLabor: true),
                ),
                const SizedBox(height: 8),
                                if (_partTemplates.isNotEmpty) ...[
                  const Text('🔩 قطعات پیش‌فرض (کلیک برای افزودن):',
                      style: TextStyle(fontSize: 11, color: Colors.amberAccent)),
                  const SizedBox(height: 4),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _partTemplates.map((t) {
                        return Padding(
                          padding: const EdgeInsets.only(left: 6.0),
                          child: ActionChip(
                            backgroundColor: cs.surfaceContainerHighest,
                            side: BorderSide(color: cs.outline),
                            avatar: const Icon(Icons.add, size: 14, color: Colors.amberAccent),
                            // 👈 نمایش تعداد موجودی در کنار نام قطعه
                            label: Text('${t.name} (${t.quantity})', style: const TextStyle(fontSize: 11)),
                            onPressed: () async {
                              // 👈 بررسی موجودی
                              if (t.quantity <= 0) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('موجودی قطعه "${t.name}" به پایان رسیده است!'),
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                                return;
                              }
                              
                              // موجودی فقط هنگام ذخیره قطعی فاکتور تغییر می‌کند.
                              setState(() {
                                partsList.add(PartItem(
                                  name: t.name,
                                  price: t.price,
                                  fromInventory: true,
                                  unitCost: t.purchasePrice,
                                ));
                              });
                              
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                  _buildItemBox(
                  cs: cs,
                  title: '🔩 لیست قطعات:',
                  titleColor: Colors.amberAccent,
                  addLabel: 'دستی',
                  addIconColor: Colors.amber[800]!,
                  items: partsList
                      .asMap()
                      .entries
                      .map((e) => _buildListItemRow(
                            cs: cs,
                            label: '• ${e.value.name}: ${formatToman(e.value.price)}',
                            onRemove: () {
                              // 👈 پیدا کردن قطعه در انبار و برگرداندن موجودی
                              final partToRemove = e.value;
                              final templateIndex = _partTemplates.indexWhere(
                                  (t) => t.name == partToRemove.name);
                              
                              if (templateIndex != -1) {
                                _partTemplates[templateIndex].quantity += 1;
                              }
                              
                              setState(() {
                                partsList.removeAt(e.key);
                              });
                            },
                          ))
                      .toList(),
                  onAddManual: () => _openAddItemDialog(isLabor: false),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: discountCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9۰-۹٠-٩]'))
                  ],
                  decoration: const InputDecoration(labelText: 'تخفیف (تومان)'),
                  onChanged: (_) => setState(() {}),
                ),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: paidCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9۰-۹٠-٩]'))
                      ],
                      decoration: const InputDecoration(labelText: 'مبلغ دریافتی'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: paymentMethod,
                    dropdownColor: cs.surfaceContainerHighest,
                    items: ['کارت‌خوان (POS)', 'نقد', 'کارت‌به‌کارت']
                        .map((v) => DropdownMenuItem(
                            value: v,
                            child: Text(v, style: const TextStyle(fontSize: 12))))
                        .toList(),
                    onChanged: (v) => setState(() => paymentMethod = v!),
                  ),
                ]),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('جمع نهایی قابل پرداخت:',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(formatToman(grandTotal),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.greenAccent,
                              fontSize: 14)),
                    ],
                  ),
                )
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              if (await _confirmExitWithoutSave()) {
                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text('انصراف'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (laborsList.isEmpty && partsList.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('حداقل یک خدمت یا قطعه ثبت کنید.')));
                return;
              }
              if (!_templatesLoaded) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('لطفاً چند لحظه صبر کنید تا اطلاعات انبار بارگذاری شود.')),
                );
                return;
              }
              if (discount < 0 || discount > subTotal) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('تخفیف نمی‌تواند منفی یا بیشتر از مبلغ کل خدمات و قطعات باشد.'),
                    backgroundColor: Colors.redAccent,
                  ),
                );
                return;
              }
              final enteredPaid = NumberHelper.safeParseInt(paidCtrl.text);
              if (enteredPaid < 0 || enteredPaid > grandTotal) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('خطا: مبلغ دریافتی نمی‌تواند بیشتر از جمع کل قابل پرداخت باشد!'),
          backgroundColor: Colors.redAccent,
          duration: Duration(seconds: 3),
        ),
      );
      return; // جلوگیری از ذخیره شدن فاکتور
              }
              final record = ServiceRecord(
                id: widget.serviceToEdit?.id ??
                    DateTime.now().microsecondsSinceEpoch.toString(),
                date: dateCtrl.text.isNotEmpty
                    ? dateCtrl.text.trim()
                    : JalaliHelper.nowShamsi(),
                km: kmCtrl.text.trim(),
                warrantyNote: warrantyCtrl.text.trim(),
                paymentMethod: paymentMethod,
                discount: discount,
                paidAmount: enteredPaid,
                labors: List.from(laborsList),
                parts: List.from(partsList),
                paymentEntries: widget.serviceToEdit?.paymentEntries ?? [],
              );
              final inventoryUpdated = await _applyInventoryChanges();
              if (!inventoryUpdated) return;
              widget.onSave(record);
              if (mounted) Navigator.pop(context);
            },
            child: const Text('ذخیره فاکتور'),
          )
        ],
      ),
    );
  }

  Widget _buildItemBox({
    required ColorScheme cs,
    required String title,
    required Color titleColor,
    required String addLabel,
    required Color addIconColor,
    required List<Widget> items,
    required VoidCallback onAddManual,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
          color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(10)),
      child: Column(children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title,
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: titleColor, fontSize: 13)),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: addIconColor),
              icon: const Icon(Icons.add, size: 14),
              label: Text(addLabel, style: const TextStyle(fontSize: 10)),
              onPressed: onAddManual,
            ),
          ],
        ),
        ...items,
      ]),
    );
  }

  Widget _buildListItemRow({
    required ColorScheme cs,
    required String label,
    required VoidCallback onRemove,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
            child: Text(label, style: const TextStyle(fontSize: 12))),
        IconButton(
          icon: const Icon(Icons.close, size: 16, color: Colors.redAccent),
          onPressed: onRemove,
        )
      ],
    );
  }

  void _openAddItemDialog({required bool isLabor}) {
    final titleCtrl = TextEditingController();
    final costCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isLabor ? 'افزودن خدمت و اجرت' : 'افزودن قطعه مصرفی'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: titleCtrl,
                decoration: InputDecoration(
                    labelText: isLabor ? 'شرح کار' : 'نام قطعه')),
            TextField(
                controller: costCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9۰-۹٠-٩]'))
                ],
                decoration: const InputDecoration(labelText: 'مبلغ (تومان)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
          ElevatedButton(
            onPressed: () {
              if (titleCtrl.text.trim().isNotEmpty) {
                final price = NumberHelper.safeParseInt(costCtrl.text);
                setState(() {
                  if (isLabor) {
                    laborsList.add(LaborItem(title: titleCtrl.text.trim(), cost: price));
                  } else {
                    partsList.add(PartItem(name: titleCtrl.text.trim(), price: price, fromInventory: false));
                  }
                });
                Navigator.pop(ctx);
              }
            },
            child: const Text('افزودن'),
          )
        ],
      ),
    ).whenComplete(() {
      titleCtrl.dispose();
      costCtrl.dispose();
    });
  }
}

// ======================== حساب دفتری ========================
class DebtorsScreen extends StatelessWidget {
  final List<Customer> customers;
  final Future<void> Function() onDataChanged;
  const DebtorsScreen({super.key, required this.customers, required this.onDataChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final debtors = customers.where((c) => c.totalDebt > 0).toList();
    final int totalShopDebt = debtors.fold(0, (sum, c) => sum + c.totalDebt);

    return Scaffold(
      appBar: AppBar(title: const Text('📋 حساب دفتری و لیست نسیه‌ها')),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red[900]?.withOpacity(0.25),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.redAccent),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('کل طلب شما از مشتریان:',
                        style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(formatToman(totalShopDebt),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.redAccent)),
                  ],
                ),
                Text('${debtors.length} نفر بدهکار',
                    style: const TextStyle(
                        color: Colors.amberAccent, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Expanded(
            child: debtors.isEmpty
                ? Center(
                    child: Text('هیچ بدهی و نسیه ثبت‌شده‌ای ندارید! 🎉',
                        style: TextStyle(color: cs.onSurfaceVariant)))
                : ListView.builder(
                    itemCount: debtors.length,
                    itemBuilder: (_, i) {
                      final c = debtors[i];
                      final openInvoices = <Map<String, dynamic>>[];
                      for (final car in c.cars) {
                        for (final invoice in car.services) {
                          if (invoice.remainingDebt > 0) {
                            openInvoices.add({'car': car, 'invoice': invoice});
                          }
                        }
                      }
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        clipBehavior: Clip.antiAlias,
                        child: ExpansionTile(
                          leading: const CircleAvatar(backgroundColor: Colors.redAccent,
                            child: Icon(Icons.person, color: Colors.white)),
                          title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('📞 ${c.phone}  •  مانده: ${formatToman(c.totalDebt)}',
                            style: const TextStyle(color: Colors.redAccent)),
                          children: [
                            ...openInvoices.map((entry) {
                              final car = entry['car'] as Car;
                              final invoice = entry['invoice'] as ServiceRecord;
                              return ListTile(
                                dense: true,
                                title: Text('${car.model} • فاکتور ${invoice.date}'),
                                subtitle: Text('مانده این فاکتور: ${formatToman(invoice.remainingDebt)}'),
                                trailing: FilledButton.tonalIcon(
                                  icon: const Icon(Icons.add_card, size: 18),
                                  label: const Text('ثبت دریافت'),
                                  onPressed: () => _recordPayment(context, c, invoice),
                                ),
                              );
                            }),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                              child: Align(alignment: Alignment.centerLeft,
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.sms), label: const Text('ارسال یادآوری بدهی'),
                                  onPressed: () => _sendDebtReminderSms(c, context),
                                )),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _recordPayment(BuildContext context, Customer customer, ServiceRecord invoice) async {
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    String method = 'نقدی';
    final amount = await showDialog<int>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(builder: (context, setDialogState) => AlertDialog(
        title: const Text('ثبت دریافت از مشتری'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Align(alignment: Alignment.centerRight,
            child: Text('مانده فاکتور: ${formatToman(invoice.remainingDebt)}',
              style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))),
          const SizedBox(height: 12),
          TextField(controller: amountController, keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'مبلغ دریافتی (تومان)', prefixIcon: Icon(Icons.payments))),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(value: method, decoration: const InputDecoration(labelText: 'روش دریافت'),
            items: const ['نقدی', 'کارت‌خوان (POS)', 'کارت‌به‌کارت'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
            onChanged: (v) => setDialogState(() => method = v ?? 'نقدی')),
          const SizedBox(height: 8),
          TextField(controller: noteController, decoration: const InputDecoration(labelText: 'توضیحات (اختیاری)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('انصراف')),
          FilledButton(onPressed: () {
            final parsed = int.tryParse(NumberHelper.cleanNumbers(amountController.text));
            if (parsed == null || parsed <= 0 || parsed > invoice.remainingDebt) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('مبلغ باید بیشتر از صفر و حداکثر برابر مانده فاکتور باشد.')));
              return;
            }
            Navigator.pop(dialogContext, parsed);
          }, child: const Text('ثبت دریافت')),
        ],
      )),
    );
    if (amount == null) return;
    invoice.paidAmount += amount;
    invoice.paymentEntries.add(PaymentEntry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      date: JalaliHelper.nowShamsi(), amount: amount, method: method, note: noteController.text.trim(),
    ));
    await onDataChanged();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('دریافت ${formatToman(amount)} برای ${customer.name} ثبت شد.'),
        backgroundColor: Colors.green,
      ));
    }
  }

  Future<void> _sendDebtReminderSms(Customer c, BuildContext context) async {
    final cleanPhone = NumberHelper.cleanNumbers(c.phone);
    if (cleanPhone.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('شماره همراه مشتری ثبت نشده است!')));
      return;
    }
    final msg = 'مشتری گرامی ${c.name}\n'
        'با سلام، احتراماً مانده حساب شما در کلینیک برق خودرو مهندس مبلغ ${formatToman(c.totalDebt)} می‌باشد.\n'
        'با تشکر - برق خودرو مهندس';

    final ok = await SmsHelper.sendSms(
      phoneNumber: cleanPhone,
      message: msg,);
    
    if (context.mounted) {
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('پیامک یادآوری بدهی با موفقیت ارسال شد.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('خطا در ارسال پیامک. لطفاً مجوز ارسال پیامک را بررسی کنید.'),
              backgroundColor: Colors.redAccent),
        );
      }
    }
   }
  }


// ======================== باشگاه مشتریان ========================
class BulkSmsScreen extends StatefulWidget {
  final List<Customer> customers;
  const BulkSmsScreen({super.key, required this.customers});
  @override
  State<BulkSmsScreen> createState() => _BulkSmsScreenState();
}

class _BulkSmsScreenState extends State<BulkSmsScreen> {
  final TextEditingController _msgCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _msgCtrl.text =
        'مشتری گرامی کلینیک برق خودرو مهندس،\nخدمات تخصصی برق، باتری، دینام و استارت خودرو با ضمانت.\nتلفن: [شماره تماس]';
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  List<String> _getValidPhones() {
    final Set<String> phones = {};
    for (final c in widget.customers) {
      final p = NumberHelper.cleanNumbers(c.phone);
      if (p.isNotEmpty && p.length >= 10) phones.add(p);
    }
    return phones.toList();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final phones = _getValidPhones();

    return Scaffold(
      appBar: AppBar(title: const Text('📢 باشگاه مشتریان و پیامک گروهی')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: cs.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: cs.primary)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${phones.length} شماره تماس ثبت شده',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Colors.greenAccent)),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.teal[800]),
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('کپی شماره‌ها', style: TextStyle(fontSize: 12)),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: phones.join(', ')));
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('شماره‌ها کپی شدند.')));
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _msgCtrl,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'متن پیامک گروهی'),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: cs.primary, minimumSize: const Size.fromHeight(48)),
              icon: const Icon(Icons.send, color: Colors.white),
              label: const Text('ارسال پیامک دسته‌جمعی',
                  style: TextStyle(color: Colors.white)),
               onPressed: () async {
                if (phones.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('هیچ شماره‌ای برای ارسال وجود ندارد!')));
                  return;
                }
                
                // 👈 تغییر اصلی: برداشتن محدودیت ۲۰ نفر
                final batch = phones.toList(); 
                final msgText = _msgCtrl.text;

                // نمایش پیام در حال ارسال
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('در حال ارسال پیامک به ${batch.length} شماره... لطفاً صبر کنید.'),
                    duration: const Duration(seconds: 3),
                  ),
                );

                int successCount = 0;
                // ارسال پیامک به همه شماره‌ها یکی‌یکی
                for (final phone in batch) {
                  final ok = await SmsHelper.sendSms(
                    phoneNumber: phone,
                    message: msgText,
                  );
                  if (ok) successCount++;
                  
                  // 👈 یک وقفه نیم‌ثانیه‌ای برای جلوگیری از مسدود شدن توسط اندروید
                  await Future.delayed(const Duration(milliseconds: 500)); 
                }

                // نمایش نتیجه نهایی
                if (context.mounted) {
                  Color snackColor;
                  String msg;
                  
                  if (successCount == batch.length) {
                    snackColor = Colors.green;
                    msg = '✅ پیامک برای هر ${batch.length} شماره با موفقیت ارسال شد.';
                  } else if (successCount > 0) {
                    snackColor = Colors.orange;
                    msg = '⚠️ پیامک برای $successCount شماره از ${batch.length} شماره ارسال شد. (برخی خطا داشتند)';
                  } else {
                    snackColor = Colors.redAccent;
                    msg = '❌ خطا در ارسال پیامک! لطفاً مجوز برنامه یا اعتبار سیم‌کارت را بررسی کنید.';
                  }

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold)),
                      backgroundColor: snackColor,
                      duration: const Duration(seconds: 5),
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.info_outline, color: cs.primary, size: 18),
                      const SizedBox(width: 6),
                      const Text('راهنما',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ]),
                    const SizedBox(height: 8),
                    Text(
                      '• پیامک‌ها به صورت خودکار در پس‌زمینه و بدون نیاز به باز کردن اپلیکیشن پیامک ارسال می‌شوند.\n'
                      '• این سیستم محدودیتی برای تعداد شماره‌ها ندارد و پیامک به تمام مخاطبین لیست ارسال می‌شود.\n'
                      '• توجه: سیستم‌عامل اندروید برای جلوگیری از هرزنامه، ممکن است در ارسال‌های خیلی زیاد (مثلاً بیش از ۳۰ پیامک در نیم ساعت) محدودیت موقت اعمال کند.',
                      style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant, height: 1.6),
                    ),
                    
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ======================== داشبورد دخل و گزارش ========================
class DailyReportScreen extends StatefulWidget {
  final List<Customer> customers;
  const DailyReportScreen({super.key, required this.customers});
  @override
  State<DailyReportScreen> createState() => _DailyReportScreenState();
}

class _DailyReportScreenState extends State<DailyReportScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late String selectedDay;
  late String selectedMonth;
  List<WorkshopExpense> _reportExpenses = [];
  bool _expensesLoaded = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    selectedDay = JalaliHelper.nowShamsi();
    selectedMonth = JalaliHelper.currentMonthShamsi();
    _loadReportExpenses();
  }

  Future<void> _loadReportExpenses() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('workshop_expenses_v1');
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as List;
        _reportExpenses = decoded
            .map((e) => WorkshopExpense.fromMap(Map<String, dynamic>.from(e)))
            .toList();
      }
    } catch (e) {
      debugPrint('Report expenses load error: $e');
    }
    if (mounted) setState(() => _expensesLoaded = true);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📊 دخل و گزارش مالی کارگاه'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.cyanAccent,
          labelColor: Colors.cyanAccent,
          tabs: const [
            Tab(text: 'گزارش روزانه'),
            Tab(text: 'گزارش ماهانه'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildReportView(isMonthly: false),
          _buildReportView(isMonthly: true),
        ],
      ),
    );
  }

  bool _isValidDate(String s, {required bool monthly}) {
    final regex =
        monthly ? RegExp(r'^\d{4}/\d{1,2}$') : RegExp(r'^\d{4}/\d{1,2}/\d{1,2}$');
    if (!regex.hasMatch(s.trim())) return false;
    try {
      final parts = s.split('/');
      final m = int.parse(parts[1]);
      return m >= 1 && m <= 12;
    } catch (_) {
      return false;
    }
  }

  Widget _financialRow(String label, int amount, Color color, {bool emphasize = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontWeight: emphasize ? FontWeight.bold : FontWeight.normal)),
        Text(formatToman(amount), style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: emphasize ? 16 : 13)),
      ],
    );
  }

  Widget _buildReportView({required bool isMonthly}) {
    final cs = Theme.of(context).colorScheme;
    final target = isMonthly ? selectedMonth : selectedDay;

    List<Map<String, dynamic>> servicesList = [];
    int totalLabor = 0;
    int totalParts = 0;
    int totalPartsCost = 0;
    int unknownPartCosts = 0;
    int totalDiscount = 0;
    int totalIncome = 0;
    int totalPaid = 0;
    int totalDebtCreated = 0;
    int totalPos = 0;
    int totalCash = 0;
    int totalExpenses = 0;
    int stockPurchases = 0;
    final matchedExpenses = _reportExpenses.where((e) =>
        isMonthly ? e.date.startsWith(target) : e.date == target).toList();
    for (final expense in matchedExpenses) {
      if (expense.category == 'خرید قطعات') {
        stockPurchases += expense.amount;
      } else {
        totalExpenses += expense.amount;
      }
    }
    for (final cust in widget.customers) {
      for (final car in cust.cars) {
        for (final s in car.services) {
          final isMatch = isMonthly ? s.date.startsWith(target) : (s.date == target);
          if (!isMatch) continue;

          totalLabor += s.laborTotal;
          totalParts += s.partsTotal;
          for (final part in s.parts) {
            if (part.fromInventory) {
              if (part.unitCost > 0) {
                totalPartsCost += part.unitCost;
              } else {
                unknownPartCosts++;
              }
            }
          }
          totalDiscount += s.discount;
          totalIncome += s.grandTotal;
          totalPaid += s.paidAmount;
          totalDebtCreated += s.remainingDebt;

          final isPos = s.paymentMethod.contains('POS') ||
              s.paymentMethod.contains('کارت‌خوان');
          if (isPos) {
            totalPos += s.paidAmount;
          } else {
            totalCash += s.paidAmount;
          }

          servicesList.add({
            'customer': cust.name,
            'car': car.model,
            'service': s,
          });
        }
      }
    }

    // خرید قطعات در زمان ورود به انبار، هزینه نقدی است؛ هنگام فروش، بهای تمام‌شده
    // از روی unitCost ذخیره‌شده در فاکتور از سود عملیاتی کسر می‌شود تا دوباره‌شماری نشود.
    final netCashFlow = totalPaid - totalExpenses - stockPurchases;
    final estimatedProfit = totalLabor + totalParts - totalDiscount - totalPartsCost - totalExpenses;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isMonthly ? 'ماه: $target' : 'تاریخ: $target',
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.amberAccent),
              ),
              IconButton(
                icon: const Icon(Icons.edit_calendar, color: Colors.cyanAccent),
                tooltip: 'تغییر بازه',
                onPressed: () =>
                    _openDateEditor(isMonthly: isMonthly, current: target),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            color: cs.primary.withOpacity(0.15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: cs.primary),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text('💰 سود عملیاتی برآوردی',
                      style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant)),
                  const SizedBox(height: 6),
                  Text(
                    formatToman(estimatedProfit),
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: estimatedProfit >= 0 ? Colors.greenAccent : Colors.redAccent),
                  ),
                  const SizedBox(height: 5),
                  Text(unknownPartCosts > 0
                    ? '$unknownPartCosts قطعه انباری در فاکتورهای این بازه بهای خرید ثبت‌شده ندارند؛ سود نمایش‌داده‌شده کامل نیست.'
                    : 'سود بر اساس فروش خدمات و قطعات، بهای خرید ثبت‌شده قطعات و هزینه‌های عملیاتی محاسبه شده است.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
                  const Divider(height: 22),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(children: [
                        Text('فروش قطعات',
                            style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                        Text(formatToman(totalParts),
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                      ]),
                      Column(children: [
                        Text('کل دخل ناخالص',
                            style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                        Text(formatToman(totalLabor + totalParts),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, color: Colors.amberAccent)),
                      ]),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text('خلاصه جریان نقدی', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          _financialRow('وجه دریافت‌شده', totalPaid, Colors.green),
                          const SizedBox(height: 6),
                          _financialRow('هزینه‌های عملیاتی', totalExpenses, Colors.orange),
                          const SizedBox(height: 6),
                          _financialRow('خرید موجودی قطعات', stockPurchases, Colors.amber),
                          const SizedBox(height: 6),
                          _financialRow('بهای تمام‌شده قطعات فروخته‌شده', totalPartsCost, Colors.deepOrange),
                          const Divider(height: 18),
                          _financialRow('خالص جریان نقدی', netCashFlow,
                              netCashFlow >= 0 ? Colors.green : Colors.redAccent,
                              emphasize: true),
                          if (!_expensesLoaded)
                            const Padding(
                              padding: EdgeInsets.only(top: 6),
                              child: LinearProgressIndicator(minHeight: 2),
                            ),
                          const SizedBox(height: 6),
                          Text(
                            'خالص جریان نقدی = دریافتی منهای هزینه‌های عملیاتی و خرید موجودی در همین بازه است. سود عملیاتی با بهای تمام‌شده قطعات فروخته‌شده محاسبه می‌شود.',
                            style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (totalDiscount > 0) ...[
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.local_offer,
                            size: 14, color: Colors.orangeAccent),
                        const SizedBox(width: 4),
                        Text('مجموع تخفیف داده‌شده: ${formatToman(totalDiscount)}',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.orangeAccent)),
                      ],
                    ),
                  ],
                  const Divider(height: 22),
                  _financialRow('بهای تمام‌شده قطعات فروخته‌شده', totalPartsCost, Colors.deepOrange),
                  const SizedBox(height: 6),
                  _financialRow('هزینه‌های عملیاتی', totalExpenses, Colors.orange),
                  const Divider(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('فروش خالص (بعد از تخفیف):',
                          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                      Text(formatToman(totalIncome),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Colors.greenAccent)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _metricTile(context,
                          icon: Icons.credit_card,
                          label: 'پوز',
                          value: formatToman(totalPos),
                          color: Colors.cyanAccent),
                      Container(
                          height: 30, width: 1, color: cs.outline.withOpacity(0.4)),
                      _metricTile(context,
                          icon: Icons.payments,
                          label: 'نقد / کارت‌به‌کارت',
                          value: formatToman(totalCash),
                          color: Colors.amberAccent),
                    ],
                  ),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('💳 مجموع دریافتی:',
                          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                      Text(formatToman(totalPaid),
                          style:
                              const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ],
                  ),
                  if (totalDebtCreated > 0) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('⚠️ نسیه ایجادشده در این بازه:',
                            style: TextStyle(fontSize: 12, color: Colors.redAccent)),
                        Text(formatToman(totalDebtCreated),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Colors.redAccent)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: Text('فاکتورهای ثبت‌شده (${servicesList.length}):',
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 8),
          if (servicesList.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Center(
                  child: Text(
                    'در این بازه هیچ فاکتوری ثبت نشده است.',
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                  ),
                ),
              ),
            )
          else
            ...servicesList.map((item) {
              final s = item['service'] as ServiceRecord;
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  title: Text('${item['car']} - ${item['customer']}',
                      style:
                          const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: Text(
                    '${s.summaryTitle}\n'
                    'اجرت: ${formatToman(s.laborTotal)}  |  پرداختی: ${formatToman(s.paidAmount)}'
                    '${s.discount > 0 ? "  |  تخفیف: ${formatToman(s.discount)}" : ""}',
                    style: const TextStyle(fontSize: 11),
                  ),
                  isThreeLine: true,
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(formatToman(s.grandTotal),
                          style: const TextStyle(
                              color: Colors.greenAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                      if (s.remainingDebt > 0)
                        Text('بدهی: ${formatToman(s.remainingDebt)}',
                            style: const TextStyle(
                                color: Colors.redAccent, fontSize: 10)),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _metricTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
      ],
    );
  }

  void _openDateEditor({required bool isMonthly, required String current}) {
    final ctrl = TextEditingController(text: current);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isMonthly
            ? 'تغییر ماه (مثلاً 1405/08)'
            : 'تغییر تاریخ (مثلاً 1405/08/18)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctrl,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9۰-۹٠-٩/]')),
              ],
              decoration: const InputDecoration(
                hintText: '1405/08/18',
                labelText: 'تاریخ شمسی',
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'قالب تاریخ: سال/ماه/روز (با اعداد انگلیسی یا فارسی)',
              style: TextStyle(fontSize: 11),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
          ElevatedButton(
            onPressed: () {
              final val = NumberHelper.cleanNumbers(ctrl.text);
              if (!_isValidDate(val, monthly: isMonthly)) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text('قالب تاریخ نامعتبر است!'),
                    backgroundColor: Colors.redAccent,
                  ),
                );
                return;
              }
              setState(() {
                if (isMonthly) {
                  selectedMonth = val;
                } else {
                  selectedDay = val;
                }
              });
              Navigator.pop(ctx);
            },
            child: const Text('اعمال'),
          ),
        ],
      ),
    ).whenComplete(() => ctrl.dispose());
  }
}
