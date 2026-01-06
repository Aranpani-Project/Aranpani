// lib/screens/create_project_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart'; // IMPORTED FOR XFile
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../utils/colors.dart';
import '../widgets/image_picker_widget.dart';
import '../services/cloudinary_service.dart';
import 'package:geolocator/geolocator.dart';

class CreateProjectScreen extends StatefulWidget {
  const CreateProjectScreen({super.key});

  @override
  State<CreateProjectScreen> createState() => _CreateProjectScreenState();
}

class _CreateProjectScreenState extends State<CreateProjectScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  final TextEditingController _placeController = TextEditingController();
  final TextEditingController _nearbyTownController = TextEditingController();
  final TextEditingController _talukController = TextEditingController();
  final TextEditingController _districtController = TextEditingController();
  final TextEditingController _mapLocationController = TextEditingController();
  final TextEditingController _contactNameController = TextEditingController();
  final TextEditingController _contactPhoneController = TextEditingController();
  final TextEditingController _estimatedAmountController =
      TextEditingController();
  final TextEditingController _customDimensionController =
      TextEditingController();
  final TextEditingController _featureAmountController =
      TextEditingController();

  DateTime? _selectedDate;

  String? _selectedFeature;
  String? _type;
  String? _dimension;

  final List<Map<String, dynamic>> _predefinedDimensions = [
    {'name': '2 feet', 'amount': 50000},
    {'name': '3 feet', 'amount': 75000},
    {'name': '4 feet', 'amount': 100000},
  ];

  List<String> _selectedImages = [];
  bool _isLoading = false;

  bool _validateCurrentPage() {
    switch (_currentPage) {
      case 0:
        return _placeController.text.isNotEmpty &&
            _nearbyTownController.text.isNotEmpty &&
            _talukController.text.isNotEmpty &&
            _districtController.text.isNotEmpty &&
            _mapLocationController.text.isNotEmpty &&
            _selectedDate != null;
      case 1:
        return _selectedFeature != null;
      case 2:
        return _contactNameController.text.isNotEmpty &&
            _contactPhoneController.text.isNotEmpty &&
            _estimatedAmountController.text.isNotEmpty;
      default:
        return false;
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF5D4037), // Bronze
            onPrimary: Colors.white,
            surface: Color(0xFFFFFDF5), // Ivory
          ),
        ),
        child: child!,
      ),
    );

    if (picked != null) setState(() => _selectedDate = picked);
  }

  String _toDMS(double value, bool isLat) {
    final absValue = value.abs();
    final degrees = absValue.floor();
    final minutesFull = (absValue - degrees) * 60;
    final minutes = minutesFull.floor();
    final seconds = (minutesFull - minutes) * 60;
    final direction =
        isLat ? (value >= 0 ? 'N' : 'S') : (value >= 0 ? 'E' : 'W');
    return '${degrees}°'
        '${minutes.toString().padLeft(2, '0')}\''
        '${seconds.toStringAsFixed(1).padLeft(4, '0')}\"'
        '$direction';
  }

  Future<void> _detectAndFillLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enable location services'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permission denied'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Location permissions permanently denied. Please enable from Settings.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    List<Position> samples = [];
    for (int i = 0; i < 3; i++) {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
      );
      samples.add(pos);
      await Future.delayed(const Duration(milliseconds: 500));
    }

    double avgLat =
        samples.map((e) => e.latitude).reduce((a, b) => a + b) / samples.length;
    double avgLng = samples.map((e) => e.longitude).reduce((a, b) => a + b) /
        samples.length;

    String latDMS = _toDMS(avgLat, true);
    String lngDMS = _toDMS(avgLng, false);

    setState(() {
      _mapLocationController.text = "$latDMS $lngDMS";
    });
  }

  Future<void> _createProject() async {
    if (!_validateCurrentPage()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all required fields'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser!;
      final projectId = const Uuid().v4();

      List<String> uploadedImageUrls = [];

      // --- FIXED UPLOAD LOGIC ---
      for (final imgPath in _selectedImages) {
        // Create an XFile from the path string
        final xFile = XFile(imgPath);

        final url = await CloudinaryService.uploadImage(
          imageFile: xFile, // Pass XFile
          userId: user.uid,
          projectId: projectId,
        );

        // Check for null before adding
        if (url != null) {
          uploadedImageUrls.add(url);
        }
      }
      // --------------------------

      await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .set({
        'projectNumber': DateTime.now().millisecondsSinceEpoch.toString(),
        'projectId': projectId,
        'userId': user.uid,
        'place': _placeController.text.trim(),
        'nearbyTown': _nearbyTownController.text.trim(),
        'taluk': _talukController.text.trim(),
        'district': _districtController.text.trim(),
        'mapLocation': _mapLocationController.text.trim(),
        'feature': _selectedFeature ?? '',
        'featureType': _type ?? '',
        'featureDimension': _dimension ?? '',
        'featureAmount': _featureAmountController.text.trim(),
        'contactName': _contactNameController.text.trim(),
        'contactPhone': _contactPhoneController.text.trim(),
        'estimatedAmount': _estimatedAmountController.text.trim(),
        'imageUrls': uploadedImageUrls,
        'dateCreated': FieldValue.serverTimestamp(),
        'progress': 0,
        'status': 'pending',
        'removedByUser': false,
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Plan proposed successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Color(0xFFB71C1C), // Sacred Red
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFDF5), // Ivory Background
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildProgressIndicator(),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: [
                  _buildLocationPage(),
                  _buildFeaturePage(),
                  _buildContactPage(),
                ],
              ),
            ),
            _buildNavigationButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Text(
        'Propose a Plan',
        style: GoogleFonts.cinzel(
          fontSize: 26,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF3E2723), // Dark Coffee
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: [
          _step(0, 'Location'),
          _line(0),
          _step(1, 'Feature'),
          _line(1),
          _step(2, 'Details'),
        ],
      ),
    );
  }

  Widget _step(int step, String label) {
    final active = _currentPage >= step;
    return Column(
      children: [
        CircleAvatar(
          backgroundColor: active ? const Color(0xFF5D4037) : const Color(0xFFF5E6CA),
          child: Text(
            '${step + 1}',
            style: TextStyle(color: active ? Colors.white : const Color(0xFF8D6E63)),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
            color: active ? const Color(0xFF3E2723) : const Color(0xFF8D6E63),
          ),
        ),
      ],
    );
  }

  Widget _line(int step) {
    final active = _currentPage > step;
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 20),
        color: active ? const Color(0xFF5D4037) : const Color(0xFFF5E6CA),
      ),
    );
  }

  Widget _buildLocationPage() {
    return _buildFormContainer(
      child: Column(
        children: [
          _title('Location Details', 'Enter the location information'),
          const SizedBox(height: 16),
          _textField(_placeController, 'Place', Icons.location_on_outlined),
          const SizedBox(height: 16),
          _textField(_nearbyTownController, 'Nearby Town', Icons.location_city),
          const SizedBox(height: 16),
          _textField(_talukController, 'Taluk', Icons.map_outlined),
          const SizedBox(height: 16),
          _textField(_districtController, 'District', Icons.domain_outlined),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _mapLocationController,
                  style: const TextStyle(color: Color(0xFF3E2723)),
                  decoration: InputDecoration(
                    labelText: 'Map Location (auto-detected)',
                    hintText: 'Tap GPS icon',
                    hintStyle: const TextStyle(color: Color(0xFF8D6E63)),
                    labelStyle: const TextStyle(color: Color(0xFF8D6E63)),
                    prefixIcon:
                        const Icon(Icons.pin_drop, color: Color(0xFF5D4037)),
                    filled: true,
                    fillColor: Colors.white,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFF5E6CA)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF5D4037)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.my_location, color: Color(0xFF5D4037)),
                onPressed: _detectAndFillLocation,
                tooltip: 'Use current location',
              ),
            ],
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: () => _selectDate(context),
            child: _dateField(),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturePage() {
    return _buildFormContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title('Select Feature', 'Choose what you want to propose'),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _featureButton('Lingam', Icons.account_balance)),
              const SizedBox(width: 12),
              Expanded(child: _featureButton('Avudai', Icons.architecture)),
            ],
          ),
          const SizedBox(height: 12),
          _featureButton('Nandhi', Icons.pets),
          if (_selectedFeature != null) _buildFeatureDetails(_selectedFeature!),
        ],
      ),
    );
  }

  Widget _buildFeatureDetails(String featureName) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 30),
        Text(
          '${featureName[0].toUpperCase()}${featureName.substring(1)} Details',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF3E2723),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Type',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF8D6E63),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _buildRadioOption('Old', 'old')),
            const SizedBox(width: 12),
            Expanded(child: _buildRadioOption('New', 'new')),
          ],
        ),
        if (_type == 'new') ...[
          const SizedBox(height: 24),
          Text(
            'Dimensions',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF8D6E63),
            ),
          ),
          const SizedBox(height: 8),
          ..._predefinedDimensions.map((dim) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildDimensionOption(
                    dim['name'], '₹${dim['amount']}', dim['name']),
              )),
          _buildDimensionOption('Others', 'Custom', 'custom'),
          if (_dimension == 'custom') ...[
            const SizedBox(height: 16),
            _textField(_customDimensionController,
                'Custom Dimension (e.g. 2.5 ft)', Icons.straighten),
            const SizedBox(height: 16),
            _textField(_featureAmountController, 'Amount Needed (₹)',
                Icons.currency_rupee,
                keyboard: TextInputType.number),
          ],
        ],
      ],
    );
  }

  Widget _featureButton(String title, IconData icon) {
    final selected = _selectedFeature == title.toLowerCase();
    return InkWell(
      onTap: () => setState(() {
        _selectedFeature = title.toLowerCase();
        _type = null;
        _dimension = null;
        _customDimensionController.clear();
        _featureAmountController.clear();
      }),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF5E6CA) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? const Color(0xFF5D4037) : const Color(0xFFF5E6CA),
            width: 2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                color: selected ? const Color(0xFF5D4037) : const Color(0xFF8D6E63)),
            const SizedBox(width: 8),
            Text(
              title,
              style: GoogleFonts.poppins(
                color: selected ? const Color(0xFF3E2723) : const Color(0xFF8D6E63),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRadioOption(String title, String value) {
    final isSelected = _type == value;

    return InkWell(
      onTap: () => setState(() {
        _type = value;
        _dimension = null;
      }),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF5E6CA) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF5D4037) : const Color(0xFFF5E6CA),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: isSelected ? const Color(0xFF5D4037) : const Color(0xFF8D6E63),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: isSelected ? const Color(0xFF3E2723) : const Color(0xFF8D6E63),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDimensionOption(String title, String subtitle, String value) {
    final isSelected = _dimension == value;

    return InkWell(
      onTap: () => setState(() {
        _dimension = value;
        if (value != 'custom') {
          final dim = _predefinedDimensions.firstWhere(
            (d) => d['name'] == value,
            orElse: () => {'amount': 0},
          );
          _featureAmountController.text = dim['amount'].toString();
          _estimatedAmountController.text = dim['amount'].toString();
        } else {
          _featureAmountController.clear();
          _estimatedAmountController.clear();
        }
      }),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF5E6CA) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF5D4037) : const Color(0xFFF5E6CA),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.check_circle : Icons.circle_outlined,
              color: isSelected ? const Color(0xFF5D4037) : const Color(0xFF8D6E63),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF3E2723),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF8D6E63),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactPage() {
    return _buildFormContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title('Contact & Details', 'Provide your details'),
          const SizedBox(height: 16),
          _textField(_contactNameController, 'Contact Name', Icons.person),
          const SizedBox(height: 16),
          _textField(_contactPhoneController, 'Phone Number', Icons.phone),
          const SizedBox(height: 16),
          ImagePickerWidget(
            maxImages: 5,
            onImagesSelected: (imgs) => _selectedImages = imgs,
          ),
          const SizedBox(height: 16),
          _textField(
            _estimatedAmountController,
            'Estimated Amount',
            Icons.account_balance_wallet,
            keyboard: TextInputType.number,
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Container(
      padding: const EdgeInsets.all(24),
      color: Colors.white,
      child: Row(
        children: [
          if (_currentPage > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: () => _pageController.previousPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF5D4037),
                  side: const BorderSide(color: Color(0xFF5D4037)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(
                  'Previous',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          if (_currentPage > 0) const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: _isLoading ? null : () {
                if (!_validateCurrentPage()) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please fill all required fields'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }
                if (_currentPage < 2) {
                  _pageController.nextPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                } else {
                  _createProject();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5D4037),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 0,
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Text(
                      _currentPage < 2 ? 'Next' : 'Submit Plan',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormContainer({required Widget child}) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFFF5E6CA).withOpacity(0.3),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFF5E6CA)),
        ),
        child: child,
      ),
    );
  }

  Widget _textField(TextEditingController c, String label, IconData icon,
      {TextInputType keyboard = TextInputType.text}) {
    return TextField(
      controller: c,
      keyboardType: keyboard,
      style: const TextStyle(color: Color(0xFF3E2723)),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF8D6E63)),
        prefixIcon: Icon(icon, color: const Color(0xFF5D4037)),
        filled: true,
        fillColor: Colors.white,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFF5E6CA)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF5D4037)),
        ),
      ),
    );
  }

  Widget _title(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.cinzel(
            fontSize: 22,
            color: const Color(0xFF3E2723),
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: GoogleFonts.poppins(
            color: const Color(0xFF8D6E63),
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _dateField() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF5E6CA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_today, color: Color(0xFF5D4037)),
          const SizedBox(width: 12),
          Text(
            _selectedDate == null
                ? 'Select Date of Visit'
                : DateFormat('dd MMM yyyy').format(_selectedDate!),
            style: GoogleFonts.poppins(color: const Color(0xFF3E2723), fontSize: 16),
          ),
        ],
      ),
    );
  }
}