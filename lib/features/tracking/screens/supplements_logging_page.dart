// lib/features/tracking/screens/supplement_logging_page.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:user_onboarding/data/models/user_profile.dart';
import 'package:user_onboarding/data/services/data_manager.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:user_onboarding/data/repositories/supplement_repository.dart';
import 'package:user_onboarding/features/tracking/screens/supplement_history_page.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:math';

class SupplementLoggingPage extends StatefulWidget {
  final UserProfile userProfile;

  const SupplementLoggingPage({
    Key? key,
    required this.userProfile,
  }) : super(key: key);

  @override
  State<SupplementLoggingPage> createState() => _SupplementLoggingPageState();
}

class _SupplementLoggingPageState extends State<SupplementLoggingPage> {
  final DataManager _dataManager = DataManager();
  final Random _random = Random();
  
  List<Map<String, dynamic>> _userSupplements = [];
  Map<String, bool> _todaysTaken = {};
  bool _isLoading = true;
  bool _hasSetupSupplements = false;
  late String _supplementPreferenceKey;
  late String _todaysStatusKey;
  String _todaysDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
  DateTime _selectedDate = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.week;
  bool _showCalendar = false;

  String get _formattedDate => DateFormat('yyyy-MM-dd').format(_selectedDate);

  String _generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString() + 
           _random.nextInt(9999).toString().padLeft(4, '0');
  }

  @override
  void initState() {
    super.initState();
    _supplementPreferenceKey = 'supplement_setup_${widget.userProfile.id}';
    _todaysStatusKey = 'supplement_status_${widget.userProfile.id}_$_todaysDate';
    _initializeSupplementTracking();
  }

  Future<void> _initializeSupplementTracking() async {
    await _checkFirstTimeSetup();
  }

  Future<void> _checkFirstTimeSetup() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Check multiple indicators
      final hasSetupFlag = prefs.getBool(_supplementPreferenceKey) ?? false;
      final isDisabled = prefs.getBool('${_supplementPreferenceKey}_disabled') ?? false;
      final supplementsJson = prefs.getString(_supplementPreferenceKey + '_list');
      final hasSupplementsList = supplementsJson != null && supplementsJson.isNotEmpty;
      
      print('🔍 DEBUG: Setup flag: $hasSetupFlag');
      print('🔍 DEBUG: Is disabled: $isDisabled');
      print('🔍 DEBUG: Has supplements list: $hasSupplementsList');
      
      // If user previously disabled supplement tracking, don't show setup
      if (isDisabled) {
        print('🚫 Supplement tracking is disabled by user choice');
        setState(() {
          _hasSetupSupplements = false;
          _userSupplements = [];
          _isLoading = false;
        });
        return;
      }
      
      // Consider setup complete if flag is true OR supplements list exists
      final isSetupComplete = hasSetupFlag || hasSupplementsList;
      
      if (isSetupComplete) {
        print('🔍 Local setup found, loading existing supplements');
        await _loadUserSupplements();
        await _loadTodaysStatus();
        setState(() => _isLoading = false);
        return;
      }
      
      // ✅ NEW: Check database before showing setup dialog
      print('🔍 No local setup found, checking database...');
      try {
        final dbPreferences = await SupplementRepository.getSupplementPreferences(widget.userProfile.id!);
        
        if (dbPreferences.isNotEmpty) {
          print('✅ Found ${dbPreferences.length} supplements in database, syncing to local storage...');
          
          // Convert database format to local format
          final supplements = dbPreferences.map((pref) {
            return {
              'id': pref['id'] ?? _generateId(),
              'name': pref['supplement_name'],
              'dosage': pref['dosage'],
              'frequency': pref['frequency'] ?? 'Daily',
              'preferred_time': pref['preferred_time'] ?? '9:00 AM',
              'notes': pref['notes'] ?? '',
              // Add local UI fields with defaults
              'color': _getSupplementColor(pref['supplement_name']).value,
              'icon': _getSupplementIcon(pref['supplement_name']).codePoint,
              'created_at': pref['created_at'] ?? DateTime.now().toIso8601String(),
            };
          }).toList();
          
          // Save to local storage
          await prefs.setString(_supplementPreferenceKey + '_list', jsonEncode(supplements));
          await prefs.setBool(_supplementPreferenceKey, true);
          
          setState(() {
            _userSupplements = supplements;
            _hasSetupSupplements = true;
            _isLoading = false;
          });
          
          // Load today's status
          await _loadTodaysStatus();
          
          print('💾 Successfully synced ${supplements.length} supplements from database');
          return;
        }
      } catch (dbError) {
        print('⚠️ Database check failed: $dbError');
        // ✅ ADD THIS: Set loading to false even on error
        setState(() => _isLoading = false);
      }
      
      // If we get here, no setup found anywhere - show dialog
      print('🔍 No setup found anywhere, showing first time setup dialog');
      setState(() => _isLoading = false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showFirstTimeSetupDialog();
      });
      
    } catch (e) {
      print('❌ Error checking first time setup: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showFirstTimeSetupDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(Icons.medication, color: Colors.teal, size: 28),
              const SizedBox(width: 12),
              const Text(
                'Supplement Tracking',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Would you like to track your daily supplements?',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.teal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.teal, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'Benefits:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text('• Daily supplement reminders'),
                    const Text('• Track what you missed'),
                    const Text('• View historical adherence'),
                    const Text('• No time pressure - take anytime'),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await _disableSupplementTracking();
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
              child: const Text(
                'No Thanks',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _showSupplementSetupWizard();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Set Up Tracking'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _disableSupplementTracking() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_supplementPreferenceKey, false);
      await prefs.setBool('${_supplementPreferenceKey}_disabled', true);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Supplement tracking disabled.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      print('Error disabling supplement tracking: $e');
    }
  }

  Future<void> _showSupplementSetupWizard() async {
    final List<String> commonSupplements = [
      'Multivitamin',
      'Vitamin D',
      'Vitamin C',
      'Omega-3',
      'Magnesium',
      'Calcium',
      'Iron',
      'B-Complex',
      'Zinc',
      'Probiotics',
      'Protein Powder',
      'Creatine',
      'Biotin',
      'CoQ10',
      'Turmeric',
    ];

    final List<String> selectedSupplements = [];

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text(
                'Select Your Supplements',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: Column(
                  children: [
                    const Text(
                      'Select supplements you take regularly:',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ListView(
                        children: commonSupplements.map((supplement) {
                          final isSelected = selectedSupplements.contains(supplement);
                          return CheckboxListTile(
                            title: Text(supplement),
                            value: isSelected,
                            onChanged: (bool? value) {
                              setDialogState(() {
                                if (value == true) {
                                  selectedSupplements.add(supplement);
                                } else {
                                  selectedSupplements.remove(supplement);
                                }
                              });
                            },
                            activeColor: Colors.teal,
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _showFirstTimeSetupDialog();
                  },
                  child: const Text('Back'),
                ),
                ElevatedButton(
                  onPressed: selectedSupplements.isNotEmpty
                      ? () async {
                          Navigator.of(context).pop();
                          await _setupInitialSupplements(selectedSupplements);
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Continue'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _setupInitialSupplements(List<String> selectedSupplements) async {
    try {
      print('🔧 DEBUG: Setting up ${selectedSupplements.length} supplements');
      
      final prefs = await SharedPreferences.getInstance();
      
      final supplements = selectedSupplements.map((name) {
        return {
          'id': _generateId(),
          'name': name,
          'dosage': _getDefaultDosage(name),
          'frequency': 'Daily',
          'preferred_time': '9:00 AM',
          'notes': '',
          // UI fields
          'color': _getSupplementColor(name).value,
          'icon': _getSupplementIcon(name).codePoint,
          'created_at': DateTime.now().toIso8601String(),
        };
      }).toList();

      // Save user's supplement list locally
      await prefs.setString(_supplementPreferenceKey + '_list', jsonEncode(supplements));
      
      // CRITICAL: Save the setup flag
      await prefs.setBool(_supplementPreferenceKey, true);
      
      print('🔧 DEBUG: Saved setup flag to: $_supplementPreferenceKey');
      print('🔧 DEBUG: Saved supplements list to: ${_supplementPreferenceKey}_list');
      
      // Verify the save worked
      final verifySetup = prefs.getBool(_supplementPreferenceKey);
      final verifyList = prefs.getString(_supplementPreferenceKey + '_list');
      print('🔧 DEBUG: Verification - setup flag: $verifySetup');
      print('🔧 DEBUG: Verification - list exists: ${verifyList != null}');

      // Save preferences to database (background)
      try {
        final supplementsForBackend = supplements.map((supplement) {
          return {
            'name': supplement['name'],
            'dosage': supplement['dosage'],
            'frequency': supplement['frequency'],
            'preferred_time': supplement['preferred_time'],
            'notes': supplement['notes'],
          };
        }).toList();

        await SupplementRepository.saveSupplementPreferences(
          widget.userProfile.id!,
          supplementsForBackend,
        );
        print('✅ Saved supplement preferences to database');
      } catch (e) {
        print('❌ Failed to save preferences to database: $e');
        // Continue anyway - local storage works
      }

      // Initialize today's status from database
      final dbStatus = await SupplementRepository.getTodaysSupplementStatus(widget.userProfile.id!);
      final todaysStatus = <String, bool>{};
      for (var supplement in supplements) {
        final name = supplement['name'] as String;
        todaysStatus[name] = dbStatus[name] ?? false;
      }
      
      await prefs.setString(_todaysStatusKey, jsonEncode(todaysStatus));

      setState(() {
        _userSupplements = supplements;
        _todaysTaken = todaysStatus;
        _hasSetupSupplements = true;
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${supplements.length} supplements added and saved!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('❌ Error setting up supplements: $e');
      setState(() => _isLoading = false);
    }
  }

  // Helper method for background database save
  Future<void> _saveSupplementsToDatabase(List<Map<String, dynamic>> supplements) async {
    try {
      final supplementsForBackend = supplements.map((supplement) {
        return {
          'name': supplement['name'],
          'dosage': supplement['dosage'],
          'frequency': supplement['frequency'],
          'preferred_time': supplement['preferred_time'],
          'notes': supplement['notes'],
        };
      }).toList();

      await SupplementRepository.saveSupplementPreferences(
        widget.userProfile.id!,
        supplementsForBackend,
      );
    } catch (e) {
      print('❌ Database save failed: $e');
      rethrow;
    }
  }

  Future<void> _loadSupplementsForDate(DateTime date) async {
    if (widget.userProfile.id == null) return;
    
    setState(() {
      _selectedDate = date;
      _todaysDate = DateFormat('yyyy-MM-dd').format(date);
      _todaysStatusKey = 'supplement_status_${widget.userProfile.id}_$_todaysDate';
      _isLoading = true;
    });
    
    try {
      await _loadTodaysStatus();
      
      setState(() => _isLoading = false);
    } catch (e) {
      print('Error loading supplements for date: $e');
      
      setState(() => _isLoading = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.warning, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Failed to load supplement data: ${e.toString()}'),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _loadSupplementsForDate(date),
            ),
          ),
        );
      }
    }
  }

  Future<void> _loadUserSupplements() async {
    try {
      print('📋 Loading user supplements for user ID: ${widget.userProfile.id}');
      
      final dbPreferences = await SupplementRepository.getSupplementPreferences(widget.userProfile.id!);
      print('📋 Received ${dbPreferences.length} preferences from repository');
        
      if (dbPreferences.isNotEmpty) {
        print('✅ Loaded ${dbPreferences.length} supplements from database');
        
        final supplements = dbPreferences.map((pref) {
          return {
            'id': pref['id'] ?? _generateId(),
            'name': pref['supplement_name'],
            'dosage': pref['dosage'],
            'frequency': pref['frequency'] ?? 'Daily',
            'preferred_time': pref['preferred_time'] ?? '9:00 AM',
            'notes': pref['notes'] ?? '',
            'color': _getSupplementColor(pref['supplement_name']).value,
            'icon': _getSupplementIcon(pref['supplement_name']).codePoint,
            'created_at': pref['created_at'] ?? DateTime.now().toIso8601String(),
          };
        }).toList();
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_supplementPreferenceKey + '_list', jsonEncode(supplements));
        await prefs.setBool(_supplementPreferenceKey, true);
        
        setState(() {
          _userSupplements = supplements;
          _hasSetupSupplements = true;
          _isLoading = false;
        });
        
        print('💾 Synced ${supplements.length} supplements to local storage');
        return;
      }
      
      print('📱 No database preferences found, checking local storage...');
      
      final prefs = await SharedPreferences.getInstance();
      final supplementsJson = prefs.getString(_supplementPreferenceKey + '_list');
      
      if (supplementsJson != null) {
        final List<dynamic> supplementsList = jsonDecode(supplementsJson);
        setState(() {
          _userSupplements = supplementsList.cast<Map<String, dynamic>>();
          _hasSetupSupplements = true;
          _isLoading = false; 
        });
        print('📱 Loaded ${_userSupplements.length} supplements from local storage');
      } else {
        print('📝 No supplements found anywhere');
        setState(() {
          _hasSetupSupplements = false;
          _userSupplements = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error in _loadUserSupplements: $e');
      
      try {
        final prefs = await SharedPreferences.getInstance();
        final supplementsJson = prefs.getString(_supplementPreferenceKey + '_list');
        
        if (supplementsJson != null) {
          final List<dynamic> supplementsList = jsonDecode(supplementsJson);
          setState(() {
            _userSupplements = supplementsList.cast<Map<String, dynamic>>();
            _hasSetupSupplements = true;
            _isLoading = false;  
          });
          print('📱 Fallback: Loaded ${_userSupplements.length} supplements from local storage');
        } else {
          setState(() => _isLoading = false); 
        }
      } catch (localError) {
        print('❌ Failed to load from local storage too: $localError');
        setState(() => _isLoading = false); 
      }
    }
  }

  Future<void> _loadTodaysStatus() async {
    if (widget.userProfile.id == null) return;
    
    try {
      // Try to get status from API
      final statusFromApi = await SupplementRepository.getSupplementStatusByDate(
        widget.userProfile.id!,
        _selectedDate,
      );
      
      if (statusFromApi.isNotEmpty) {
        setState(() {
          _todaysTaken = Map<String, bool>.from(statusFromApi);
        });
        
        // Save to local storage
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_todaysStatusKey, json.encode(_todaysTaken));
        return;
      }
      
      // Fallback to local storage
      final prefs = await SharedPreferences.getInstance();
      final statusJson = prefs.getString(_todaysStatusKey);
      
      if (statusJson != null) {
        setState(() {
          _todaysTaken = Map<String, bool>.from(json.decode(statusJson));
        });
      } else {
        // Initialize empty status for all supplements
        setState(() {
          _todaysTaken = {
            for (var supplement in _userSupplements)
              supplement['name'] as String: false
          };
        });
      }
    } catch (e) {
      print('Error loading today\'s supplement status: $e');
      
      // Initialize empty status on error
      setState(() {
        _todaysTaken = {
          for (var supplement in _userSupplements)
            supplement['name'] as String: false
        };
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load supplement status: ${e.toString()}'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  String _getDefaultDosage(String supplementName) {
    switch (supplementName.toLowerCase()) {
      case 'vitamin d': return '1000 IU';
      case 'vitamin c': return '500 mg';
      case 'omega-3': return '1000 mg';
      case 'magnesium': return '400 mg';
      case 'calcium': return '500 mg';
      case 'iron': return '18 mg';
      case 'zinc': return '15 mg';
      case 'protein powder': return '30g';
      case 'creatine': return '5g';
      case 'probiotics': return '15b cfu';
      case 'biotin': return '2500 mcg';
      case 'coq10': return '100 mg';
      case 'turmeric': return '500 mg';
      default: return '1 capsule';
    }
  }

  Color _getSupplementColor(String supplementName) {
    switch (supplementName.toLowerCase()) {
      case 'vitamin d': return Colors.orange;
      case 'vitamin c': return Colors.yellow.shade700;
      case 'omega-3': return Colors.blue;
      case 'magnesium': return Colors.purple;
      case 'calcium': return Colors.grey;
      case 'iron': return Colors.red.shade700;
      case 'zinc': return Colors.indigo;
      case 'protein powder': return Colors.brown;
      case 'creatine': return Colors.green.shade700;
      case 'probiotics': return Colors.pink;
      case 'biotin': return Colors.amber;
      case 'coq10': return Colors.deepOrange;
      case 'turmeric': return Colors.yellow.shade800;
      default: return Colors.teal;
    }
  }

  IconData _getSupplementIcon(String supplementName) {
    switch (supplementName.toLowerCase()) {
      case 'vitamin d': return Icons.wb_sunny;
      case 'omega-3': return Icons.water;
      case 'protein powder': return Icons.fitness_center;
      case 'magnesium': return Icons.nightlight_round;
      case 'probiotics': return Icons.health_and_safety;
      case 'iron': return Icons.bloodtype;
      case 'calcium': return Icons.local_hospital;
      default: return Icons.medication;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Supplements'),
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (!_hasSetupSupplements && _userSupplements.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Supplements'),
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: _showReEnableSupplementDialog,
            ),
          ],
        ),
        body: _buildDisabledState(),
      );
    }

    final takenCount = _todaysTaken.values.where((taken) => taken).length;
    final totalCount = _userSupplements.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(_showCalendar 
          ? 'Select Date' 
          : 'Supplements - ${DateFormat('MMM d').format(_selectedDate)}'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_showCalendar ? Icons.close : Icons.calendar_month),
            onPressed: () {
              setState(() {
                _showCalendar = !_showCalendar;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SupplementHistoryPage(
                    userProfile: widget.userProfile,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddSupplementDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // Calendar (collapsible)
          if (_showCalendar) _buildCalendar(),
          
          // Date indicator if not today
          if (!DateUtils.isSameDay(_selectedDate, DateTime.now()))
            _buildDateIndicator(),
          
          Expanded(
            child: _userSupplements.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                    onRefresh: () => _loadSupplementsForDate(_selectedDate),
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _buildTodaysSummary(takenCount, totalCount),
                        const SizedBox(height: 20),
                        _buildSupplementsList(),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisabledState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.block, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'Supplement Tracking Disabled',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You chose not to track supplements',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showReEnableSupplementDialog,
            icon: const Icon(Icons.refresh),
            label: const Text('Enable Supplement Tracking'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

   Widget _buildCalendar() {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: TableCalendar(
        firstDay: DateTime.now().subtract(const Duration(days: 365)),
        lastDay: DateTime.now(),
        focusedDay: _selectedDate,
        calendarFormat: _calendarFormat,
        selectedDayPredicate: (day) => isSameDay(_selectedDate, day),
        onDaySelected: (selectedDay, focusedDay) {
          setState(() {
            _showCalendar = false;
          });
          _loadSupplementsForDate(selectedDay);
        },
        onFormatChanged: (format) {
          setState(() {
            _calendarFormat = format;
          });
        },
        calendarStyle: CalendarStyle(
          todayDecoration: BoxDecoration(
            color: Colors.teal.withOpacity(0.3),
            shape: BoxShape.circle,
          ),
          selectedDecoration: const BoxDecoration(
            color: Colors.teal,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
  
  Widget _buildDateIndicator() {
    if (DateUtils.isSameDay(_selectedDate, DateTime.now())) {
      return const SizedBox.shrink();
    }
    
    return Container(
      color: Colors.teal.withValues(alpha: 0.12),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.teal, size: 20),
          const SizedBox(width: 8),
          Text(
            'Viewing supplements for ${DateFormat('EEEE, MMM d').format(_selectedDate)}',
            style: const TextStyle(color: Colors.teal),
          ),
        ],
      ),
    );
  }

  Future<void> _showReEnableSupplementDialog() async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(Icons.medication, color: Colors.teal, size: 28),
              const SizedBox(width: 12),
              const Text(
                'Enable Supplement Tracking?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: const Text(
            'Would you like to start tracking your daily supplements?',
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Not Now',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _reEnableSupplementTracking();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Enable Tracking'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _reEnableSupplementTracking() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Clear the disabled flag
      await prefs.remove('${_supplementPreferenceKey}_disabled');
      
      // Reset setup flag to allow fresh setup
      await prefs.setBool(_supplementPreferenceKey, false);
      
      // Clear any old supplement data
      await prefs.remove(_supplementPreferenceKey + '_list');
      
      print('🔧 Re-enabled supplement tracking');
      
      // Show the setup wizard
      _showFirstTimeSetupDialog();
      
    } catch (e) {
      print('❌ Error re-enabling supplement tracking: $e');
    }
  }


  // Widget _buildDatabaseStatus() {
  //   return FutureBuilder<String>(
  //     future: DatabaseService.getConnectionStatus(),
  //     builder: (context, snapshot) {
  //       final status = snapshot.data ?? 'Checking...';
  //       final isConnected = status == 'Connected';
        
  //       return Container(
  //         margin: const EdgeInsets.all(8),
  //         padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
  //         decoration: BoxDecoration(
  //           color: isConnected ? Colors.green.shade100 : Colors.orange.shade100,
  //           borderRadius: BorderRadius.circular(12),
  //           border: Border.all(
  //             color: isConnected ? Colors.green : Colors.orange,
  //             width: 1,
  //           ),
  //         ),
  //         child: Row(
  //           mainAxisSize: MainAxisSize.min,
  //           children: [
  //             Icon(
  //               isConnected ? Icons.cloud_done : Icons.cloud_off,
  //               size: 16,
  //               color: isConnected ? Colors.green : Colors.orange,
  //             ),
  //             const SizedBox(width: 4),
  //             Text(
  //               'DB: $status',
  //               style: TextStyle(
  //                 fontSize: 12,
  //                 color: isConnected ? Colors.green.shade700 : Colors.orange.shade700,
  //               ),
  //             ),
  //           ],
  //         ),
  //       );
  //     },
  //   );
  // }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.medication, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'No Supplements Added',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add supplements to start tracking',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showAddSupplementDialog,
            icon: const Icon(Icons.add),
            label: const Text('Add Supplement'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodaysSummary(int taken, int total) {
    final progress = total > 0 ? taken / total : 0.0;
    final dateStr = DateFormat('EEEE, MMM d').format(_selectedDate);
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.teal.shade400, Colors.teal.shade600],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Today\'s Supplements',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    dateStr,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              Text(
                '$taken / $total',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Theme.of(context).colorScheme.surface.withOpacity(0.3),
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            minHeight: 8,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildSummaryStat('Completed', '$taken'),
              _buildSummaryStat('Remaining', '${total - taken}'),
              _buildSummaryStat('Progress', '${(progress * 100).toStringAsFixed(0)}%'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildSupplementsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Your Supplements',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        ..._userSupplements.map((supplement) => _buildSupplementCard(supplement)),
      ],
    );
  }

  Widget _buildSupplementCard(Map<String, dynamic> supplement) {
    final supplementName = supplement['name'] as String;
    final taken = _todaysTaken[supplementName] ?? false;
    final color = Color(supplement['color'] as int);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: taken ? color.withOpacity(0.3) : Colors.grey[300]!,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 0,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _getIconFromCode(supplement['icon'] as int),
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  supplementName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  supplement['dosage'] as String,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                if ((supplement['notes'] as String).isNotEmpty)
                  Text(
                    supplement['notes'] as String,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _toggleSupplement(supplementName),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: taken ? color : Colors.grey[300],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                taken ? Icons.check : Icons.add,
                color: taken ? Colors.white : Colors.grey[600],
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quick Actions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SupplementHistoryPage(
                            userProfile: widget.userProfile,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.history),
                    label: const Text('View History'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _markAllTaken,
                    icon: const Icon(Icons.done_all),
                    label: const Text('Mark All'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleSupplement(String supplementName) async {
    if (widget.userProfile.id == null) return;
    
    final currentStatus = _todaysTaken[supplementName] ?? false;
    final newStatus = !currentStatus;
    
    // Optimistically update UI
    setState(() {
      _todaysTaken[supplementName] = newStatus;
    });
    
    try {
      // Find supplement details
      final supplement = _userSupplements.firstWhere(
        (s) => s['name'] == supplementName,
        orElse: () => {},
      );
      
      // Save to API/database
      await SupplementRepository.logSupplementIntake(
        userId: widget.userProfile.id!,
        date: _todaysDate,
        supplementName: supplementName,
        taken: newStatus,
        dosage: supplement['dosage'],
        timeTaken: newStatus ? DateTime.now().toIso8601String() : null,
      );
      
      // Save to local storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_todaysStatusKey, json.encode(_todaysTaken));
      
      // Show success feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  newStatus ? Icons.check_circle : Icons.cancel,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  newStatus 
                    ? '$supplementName marked as taken ✓' 
                    : '$supplementName unmarked',
                ),
              ],
            ),
            backgroundColor: newStatus ? Colors.green : Colors.orange,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error toggling supplement: $e');
      
      // Revert optimistic update on error
      setState(() {
        _todaysTaken[supplementName] = currentStatus;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Failed to update supplement: ${e.toString()}'),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _toggleSupplement(supplementName),
            ),
          ),
        );
      }
    }
  }

  Future<void> _saveTodaysStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_todaysStatusKey, jsonEncode(_todaysTaken));
    } catch (e) {
      print('Error saving today\'s status: $e');
    }
  }

  Future<void> _saveToDatabase(String supplementName, bool taken) async {
    try {
      // Find the supplement details
      final supplement = _userSupplements.firstWhere(
        (s) => s['name'] == supplementName,
        orElse: () => <String, dynamic>{},
      );

      if (supplement.isNotEmpty) {
        // Use SupplementRepository which handles API vs Direct DB automatically
        await SupplementRepository.logSupplementIntake(
          userId: widget.userProfile.id,
          date: _todaysDate, // This is already a String in the format 'yyyy-MM-dd'
          supplementName: supplementName,
          taken: taken,
          dosage: supplement['dosage'],
          timeTaken: taken ? DateTime.now().toIso8601String() : null,
        );
        
        print('✅ Saved to database via repository: $supplementName = $taken');
      }
    } catch (e) {
      print('Error saving to database: $e');
      // Don't show error to user - local storage still works
    }
  }

  void _markAllTaken() async {
    setState(() {
      for (var supplement in _userSupplements) {
        _todaysTaken[supplement['name']] = true;
      }
    });
    
    await _saveTodaysStatus();
    
    // Save individual keys for report screen
    final prefs = await SharedPreferences.getInstance();
    final dateStr = _todaysDate; // Use _todaysDate which is already formatted
    
    // Save all to database and SharedPreferences
    for (var supplement in _userSupplements) {
      final supplementName = supplement['name'];
      
      // Save to database
      await _saveToDatabase(supplementName, true);
      
      // Save individual key for compatibility
      final supplementKey = 'supplement_${supplementName}_$dateStr';
      await prefs.setBool(supplementKey, true);
    }
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All supplements marked as taken!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 1),
        ),
      );
    }
}

  void _showAddSupplementDialog() {
    final nameController = TextEditingController();
    final dosageController = TextEditingController();
    final notesController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Supplement'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Supplement Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: dosageController,
              decoration: const InputDecoration(
                labelText: 'Dosage (e.g., 500mg, 1 tablet)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty && dosageController.text.isNotEmpty) {
                _addNewSupplement(
                  nameController.text,
                  dosageController.text,
                  notesController.text,
                );
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _addNewSupplement(String name, String dosage, String notes) async {
    final newSupplement = {
      'id': _generateId(),
      'name': name,
      'dosage': dosage,
      'frequency': 'Daily',
      'preferred_time': '9:00 AM',
      'notes': notes,
      'color': Colors.teal.value,
      'icon': Icons.medication.codePoint,
      'created_at': DateTime.now().toIso8601String(),
    };

    setState(() {
      _userSupplements.add(newSupplement);
      _todaysTaken[name] = false;
    });

    // Save updated supplement list locally
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_supplementPreferenceKey + '_list', jsonEncode(_userSupplements));
    await _saveTodaysStatus();

    // Save to database
    try {
      final supplementForBackend = {
        'name': newSupplement['name'],
        'dosage': newSupplement['dosage'],
        'frequency': newSupplement['frequency'],
        'preferred_time': newSupplement['preferred_time'],
        'notes': newSupplement['notes'],
      };

      await SupplementRepository.saveSupplementPreferences(
        widget.userProfile.id!,
        [supplementForBackend], 
      );
    } catch (e) {
      print('❌ Failed to save new supplement to database: $e');
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Supplement added successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  IconData _getIconFromCode(int codePoint) {
    // Create a map of common icon codes to actual IconData constants
    switch (codePoint) {
      case 0xe5d0: return Icons.wb_sunny;  // vitamin d
      case 0xe63a: return Icons.water;      // omega-3
      case 0xe25c: return Icons.fitness_center; // protein powder
      case 0xe3a6: return Icons.nightlight_round; // magnesium
      case 0xe32a: return Icons.health_and_safety; // probiotics
      case 0xe190: return Icons.bloodtype; // iron
      case 0xe3f3: return Icons.local_hospital; // calcium
      case 0xe3b8: return Icons.medication; // default
      default: return Icons.medication;
    }
  }

}