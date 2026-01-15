// lib/screens/create_project_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:geolocator/geolocator.dart';

import '../widgets/image_picker_widget.dart';
import '../services/cloudinary_service.dart';

class CreateProjectScreen extends StatefulWidget {
  const CreateProjectScreen({super.key});

  @override
  State<CreateProjectScreen> createState() => _CreateProjectScreenState();
}

class FeatureEntry {
  final String key;   // 'lingam', 'nandhi', 'avudai', 'shed'
  final String label; // 'Lingam', ...
  String condition;   // 'old' or 'new'
  String? dimension;  // '2 feet', '3 feet', 'custom', or null
  String? amount;     // string amount
  String? customSize; // when dimension == 'custom'

  FeatureEntry({
    required this.key,
    required this.label,
    this.condition = 'old',
    this.dimension,
    this.amount,
    this.customSize,
  });

  Map<String, dynamic> toMap() => {
        'key': key,
        'label': label,
        'condition': condition,
        'dimension': dimension,
        'amount': amount,
        'customSize': customSize,
      };
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

  DateTime? _selectedDate;

  /// All local image paths from picker
  List<String> _selectedImages = [];

  bool _isLoading = false;
  String _aadharNumber = "N/A";

  final List<Map<String, dynamic>> _predefinedDimensions = [
    {'name': '2 feet', 'amount': 50000},
    {'name': '3 feet', 'amount': 75000},
    {'name': '4 feet', 'amount': 100000},
  ];

  late List<FeatureEntry> _features;
  FeatureEntry? _selectedFeatureEntry; // the one whose options are expanded

  @override
  void initState() {
    super.initState();
    _fetchContractorData();
    _features = [
      FeatureEntry(key: 'lingam', label: 'Lingam'),
      FeatureEntry(key: 'nandhi', label: 'Nandhi'),
      FeatureEntry(key: 'avudai', label: 'Avudai'),
      FeatureEntry(key: 'shed', label: 'Shed'),
    ];
  }

  Future<void> _fetchContractorData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          setState(() {
            _contactNameController.text =
                (data['name'] ?? data['fullName'] ?? '').toString();

            String? fetchedPhone = data['phone']?.toString() ??
                data['phoneNumber']?.toString() ??
                data['mobile']?.toString();

            _contactPhoneController.text =
                fetchedPhone ?? user.phoneNumber ?? '';

            _aadharNumber =
                (data['aadhar'] ?? data['aadharNumber'] ?? 'N/A').toString();
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching user data: $e");
    }
  }

  bool _validateCurrentPage() {
    if (_currentPage == 0) {
      if (_placeController.text.trim().isEmpty) {
        return _showWarning('Place name is required');
      }
      if (_nearbyTownController.text.trim().isEmpty) {
        return _showWarning('Nearby town is required');
      }
      if (_talukController.text.trim().isEmpty) {
        return _showWarning('Taluk is required');
      }
      if (_districtController.text.trim().isEmpty) {
        return _showWarning('District is required');
      }
      if (_mapLocationController.text.trim().isEmpty) {
        return _showWarning('Please capture GPS coordinates');
      }
      if (_selectedDate == null) {
        return _showWarning('Please select a visit date');
      }
      return true;
    }

    if (_currentPage == 1) {
      final newOnes = _features.where((f) => f.condition == 'new').toList();
      if (newOnes.isEmpty) {
        return _showWarning('At least one feature must be marked as New.');
      }
      for (final f in newOnes) {
        if (f.dimension == null || f.dimension!.isEmpty) {
          return _showWarning('Select dimension for ${f.label}.');
        }
        if (f.dimension == 'custom' &&
            (f.customSize == null || f.customSize!.trim().isEmpty)) {
          return _showWarning('Enter custom size for ${f.label}.');
        }
        if (f.amount == null || f.amount!.trim().isEmpty) {
          return _showWarning('Enter required amount for ${f.label}.');
        }
      }
      return true;
    }

    if (_currentPage == 2) {
      if (_contactNameController.text.trim().isEmpty) {
        return _showWarning('Contractor name missing');
      }
      if (_contactPhoneController.text.trim().isEmpty) {
        return _showWarning('Phone number missing');
      }
      if (_estimatedAmountController.text.trim().isEmpty) {
        return _showWarning('Enter total cost');
      }
      if (_selectedImages.length < 5) {
        return _showWarning('Please upload at least 5 photos');
      }
      return true;
    }

    return false;
  }

  bool _showWarning(String msg) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFFB71C1C),
        behavior: SnackBarBehavior.floating,
      ),
    );
    return false;
  }

  Future<void> _detectAndFillLocation() async {
    setState(() => _isLoading = true);
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _mapLocationController.text =
            "${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}";
      });
    } catch (e) {
      _showWarning("Could not fetch location. Ensure GPS is on.");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _createProject() async {
    if (!_validateCurrentPage()) return;

    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final String rawId = const Uuid().v4();
      final String projectDisplayId =
          "PRJ-${rawId.substring(0, 8).toUpperCase()}";

      debugPrint('Creating project: $projectDisplayId');
      debugPrint('Selected images: ${_selectedImages.length}');
      for (final p in _selectedImages) {
        debugPrint('Image path: $p');
      }

      final List<String> uploadedImageUrls = [];

      for (final imgPath in _selectedImages) {
        try {
          if (imgPath.isEmpty) {
            debugPrint('Skipping empty image path');
            continue;
          }

          final url = await CloudinaryService.uploadImage(
            imageFile: XFile(imgPath),
            userId: user.uid,
            projectId: projectDisplayId,
          );

          if (url != null && url.isNotEmpty) {
            uploadedImageUrls.add(url);
            debugPrint('Uploaded URL: $url');
          } else {
            debugPrint('Cloudinary returned null/empty URL for $imgPath');
          }
        } catch (e) {
          debugPrint('Error uploading $imgPath: $e');
        }
      }

      if (uploadedImageUrls.length < 5) {
        _showWarning(
          'At least 5 photos must upload successfully. Please try again.',
        );
        setState(() => _isLoading = false);
        return;
      }

      final List<Map<String, dynamic>> featureMaps =
          _features.map((f) => f.toMap()).toList();

      await FirebaseFirestore.instance.collection('projects').doc(rawId).set({
        'projectId': projectDisplayId,
        'userId': user.uid,
        'aadharNumber': _aadharNumber,
        'place': _placeController.text.trim(),
        'nearbyTown': _nearbyTownController.text.trim(),
        'taluk': _talukController.text.trim(),
        'district': _districtController.text.trim(),
        'mapLocation': _mapLocationController.text.trim(),
        'visitDate': _selectedDate != null
            ? Timestamp.fromDate(_selectedDate!)
            : null,
        // store all features
        'features': featureMaps,
        'contactName': _contactNameController.text.trim(),
        'contactPhone': _contactPhoneController.text.trim(),
        'estimatedAmount': _estimatedAmountController.text.trim(),
        'imageUrls': uploadedImageUrls,
        'dateCreated': FieldValue.serverTimestamp(),
        'status': 'pending',
      });

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      _showWarning('Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFDF5),
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
      padding: const EdgeInsets.only(top: 20, bottom: 10),
      child: Text(
        'Propose a Plan',
        style: GoogleFonts.cinzel(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF3E2723),
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
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
          radius: 18,
          backgroundColor:
              active ? const Color(0xFF5D4037) : const Color(0xFFF5E6CA),
          child: Text(
            '${step + 1}',
            style: TextStyle(
              fontSize: 12,
              color: active ? Colors.white : const Color(0xFF8D6E63),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 10,
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _line(int step) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 20, left: 4, right: 4),
        color: _currentPage > step
            ? const Color(0xFF5D4037)
            : const Color(0xFFF5E6CA),
      ),
    );
  }

  Widget _plainTextField(
    TextEditingController c,
    String label, {
    TextInputType keyboard = TextInputType.text,
    bool readOnly = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        keyboardType: keyboard,
        readOnly: readOnly,
        decoration: InputDecoration(
          labelText: label,
          labelStyle:
              TextStyle(color: const Color(0xFF5D4037).withOpacity(0.7)),
          filled: true,
          fillColor: readOnly ? Colors.grey.shade100 : Colors.white,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFF5E6CA)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF5D4037)),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildFormContainer({required Widget child}) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF5E6CA).withOpacity(0.2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF5E6CA)),
        ),
        child: child,
      ),
    );
  }

  Widget _buildLocationPage() {
    return _buildFormContainer(
      child: Column(
        children: [
          _title('Location Info', 'Enter details of the site'),
          const SizedBox(height: 16),
          _plainTextField(_placeController, 'Place'),
          _plainTextField(_nearbyTownController, 'Nearby Town'),
          _plainTextField(_talukController, 'Taluk'),
          _plainTextField(_districtController, 'District'),
          Row(
            children: [
              Expanded(
                child: _plainTextField(
                  _mapLocationController,
                  'Map Location',
                  readOnly: true,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF5D4037),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: IconButton(
                  icon: const Icon(Icons.my_location, color: Colors.white),
                  onPressed: _detectAndFillLocation,
                ),
              ),
            ],
          ),
          InkWell(
            onTap: () => _selectDate(context),
            child: _dateField(),
          ),
        ],
      ),
    );
  }

  // --------- FEATURE PAGE WITH FOUR ENTRIES ---------
  Widget _buildFeaturePage() {
    return _buildFormContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title('Select Features', 'Set condition for each structure'),
          const SizedBox(height: 16),
          ..._features.map(_buildFeatureCard),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(FeatureEntry entry) {
    final bool expanded = _selectedFeatureEntry?.key == entry.key;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFF5E6CA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                entry.label,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF3E2723),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: entry.condition == 'old'
                      ? Colors.grey.shade200
                      : Colors.green.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  entry.condition == 'old' ? 'Old' : 'New',
                  style: TextStyle(
                    fontSize: 10,
                    color: entry.condition == 'old'
                        ? Colors.grey.shade800
                        : Colors.green.shade800,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildFeatureConditionButton(
                  label: 'Old / Existing',
                  isSelected: entry.condition == 'old',
                  onTap: () {
                    setState(() {
                      entry.condition = 'old';
                      entry.dimension = null;
                      entry.amount = null;
                      entry.customSize = null;
                      if (_selectedFeatureEntry?.key == entry.key) {
                        _selectedFeatureEntry = null;
                      }
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildFeatureConditionButton(
                  label: 'New Structure',
                  isSelected: entry.condition == 'new',
                  onTap: () {
                    setState(() {
                      entry.condition = 'new';
                      _selectedFeatureEntry = entry;
                    });
                  },
                ),
              ),
            ],
          ),
          if (entry.condition == 'new') ...[
            const SizedBox(height: 12),
            Text(
              'Select Dimensions',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            ..._predefinedDimensions.map((dim) {
              final String name = dim['name'];
              final int amount = dim['amount'];
              return _buildFeatureDimensionTile(
                entry: entry,
                value: name,
                title: name,
                subtitle: 'Estimate: ₹$amount',
                onSelected: () {
                  setState(() {
                    entry.dimension = name;
                    entry.customSize = null;
                    entry.amount = amount.toString();
                  });
                },
              );
            }),
            _buildFeatureDimensionTile(
              entry: entry,
              value: 'custom',
              title: 'Other',
              subtitle: 'Custom Size & Amount',
              onSelected: () {
                setState(() {
                  entry.dimension = 'custom';
                  entry.customSize ??= '';
                  entry.amount ??= '';
                });
              },
            ),
            if (entry.dimension == 'custom') ...[
              const SizedBox(height: 8),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Size (e.g. 5 ft)',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => entry.customSize = v,
              ),
              const SizedBox(height: 8),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Required Amount (Rs)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                onChanged: (v) => entry.amount = v,
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildFeatureConditionButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF5E6CA) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color:
                isSelected ? const Color(0xFF5D4037) : const Color(0xFFF5E6CA),
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off,
              size: 18,
              color: const Color(0xFF5D4037),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureDimensionTile({
    required FeatureEntry entry,
    required String value,
    required String title,
    required String subtitle,
    required VoidCallback onSelected,
  }) {
    final bool selected = entry.dimension == value;
    return InkWell(
      onTap: onSelected,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF5E6CA) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color:
                selected ? const Color(0xFF5D4037) : const Color(0xFFF5E6CA),
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.check_circle : Icons.circle_outlined,
              size: 20,
              color: const Color(0xFF5D4037),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  // --------------------------

  Widget _buildContactPage() {
    return _buildFormContainer(
      child: Column(
        children: [
          _title('Contact Details', 'Contractor Information'),
          const SizedBox(height: 16),
          _plainTextField(
            _contactNameController,
            'Contact Name',
            readOnly: true,
          ),
          _plainTextField(
            _contactPhoneController,
            'Phone Number',
            readOnly: true,
          ),
          _plainTextField(
            TextEditingController(text: _aadharNumber),
            'Aadhar Number',
            readOnly: true,
          ),
          _plainTextField(
            _estimatedAmountController,
            'Total Estimated Cost',
            keyboard: TextInputType.number,
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Site Photos',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '(At least 5 required)',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.red,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ImagePickerWidget(
            maxImages: 10,
            onImagesSelected: (imgs) {
              for (final p in imgs) {
                debugPrint('Picked path: $p');
              }
              setState(() => _selectedImages = imgs);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFF5E6CA))),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                if (_currentPage > 0) {
                  _pageController.previousPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                } else {
                  Navigator.pop(context);
                }
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF5D4037),
                side: const BorderSide(color: Color(0xFF5D4037)),
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
              child: const Text('Back'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: _isLoading
                  ? null
                  : () {
                      if (_validateCurrentPage()) {
                        if (_currentPage < 2) {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        } else {
                          _createProject();
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5D4037),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(_currentPage < 2 ? 'Continue' : 'Submit Proposal'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _title(String t, String s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t,
          style: GoogleFonts.cinzel(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF3E2723),
          ),
        ),
        Text(
          s,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: const Color(0xFF8D6E63),
          ),
        ),
      ],
    );
  }

  Widget _dateField() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFF5E6CA)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.calendar_month,
            color: Color(0xFF5D4037),
            size: 20,
          ),
          const SizedBox(width: 12),
          Text(
            _selectedDate == null
                ? 'Visit Date'
                : DateFormat('dd-MM-yyyy').format(_selectedDate!),
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }
}
