import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logger/logger.dart';
import '../models/device.dart';
import '../models/user.dart';
import '../main.dart'; // Import main.dart to access the logger

class SystemLog {
  final String id;
  final String action;
  final String? deviceId;
  final String? userId;
  final DateTime timestamp;
  final String? details;

  SystemLog({
    required this.id,
    required this.action,
    this.deviceId,
    this.userId,
    required this.timestamp,
    this.details,
  });

  factory SystemLog.fromJson(Map<String, dynamic> json) {
    return SystemLog(
      id: json['id'],
      action: json['action'],
      deviceId: json['device_id'],
      userId: json['user_id'],
      timestamp: DateTime.parse(json['timestamp']),
      details: json['details'],
    );
  }
}

class AppState extends ChangeNotifier {
  final _supabase = Supabase.instance.client;
  RealtimeChannel? _userChannel;
  RealtimeChannel? _deviceChannel;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String _errorMessage = '';
  String get errorMessage => _errorMessage;

  // Current user
  AppUser? _currentUser;
  AppUser? get currentUser => _currentUser;

  // Admin status
  bool get isAdmin => _currentUser?.isAdmin ?? false;

  // User's devices
  List<Device> _userDevices = [];
  List<Device> get userDevices => _userDevices;
  List<Device> get devices => _userDevices;

  // Selected device (for detail view)
  Device? _selectedDevice;
  Device? get selectedDevice => _selectedDevice;

  // Device logs for selected device
  List<DeviceLog> _deviceLogs = [];
  List<DeviceLog> get deviceLogs => _deviceLogs;

  // All devices (admin only)
  List<Device> _allDevices = [];
  List<Device> get allDevices => _allDevices;

  // All users (admin only)
  List<AppUser> _users = [];
  List<AppUser> get users => _users;

  // All logs (admin only)
  List<SystemLog> _allLogs = [];
  List<SystemLog> get allLogs => _allLogs;

  // System statistics (admin only)
  Map<String, int> _systemStats = {};
  Map<String, int> get systemStats => _systemStats;

  // Initialize the app state
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Check if user is already authenticated
      final session = _supabase.auth.currentSession;
      if (session != null) {
        await _fetchUserProfile();
        await fetchUserDevices();
        _setupRealtimeSubscriptions();
      }
    } catch (e) {
      logger.e('Error initializing app state: $e');
      _errorMessage = 'Failed to initialize: ${e.toString()}';
      // Clear sensitive data on error
      _currentUser = null;
      _userDevices.clear();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Set up real-time subscriptions
  void _setupRealtimeSubscriptions() {
    final userId = _currentUser?.id;
    if (userId == null) return;

    // Subscribe to user profile changes
    _userChannel = _supabase
        .channel('user_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'profiles',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: userId,
          ),
          callback: (payload) {
            _handleUserProfileChange(payload);
          },
        )
        .subscribe();

    // Subscribe to device changes
    _deviceChannel = _supabase
        .channel('device_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'devices',
          callback: (payload) {
            _handleDeviceChange(payload);
          },
        )
        .subscribe();
  }

  // Handle user profile changes
  void _handleUserProfileChange(PostgresChangePayload payload) async {
    try {
      final eventType = payload.eventType;
      if (eventType == PostgresChangeEvent.update) {
        final newData = payload.newRecord;
        // Update current user with new data
        _currentUser = AppUser(
          id: newData['id'],
          email: newData['email'],
          fullName: newData['full_name'],
          isAdmin: newData['is_admin'] ?? false,
          createdAt: DateTime.parse(newData['created_at']),
          updatedAt: newData['updated_at'] != null
              ? DateTime.parse(newData['updated_at'])
              : null,
        );

        // If admin status changed, refresh appropriate data
        if (_currentUser?.isAdmin == true) {
          await fetchAllDevices();
          await fetchAllUsers();
        } else {
          await fetchUserDevices();
        }

        notifyListeners();
      }
    } catch (e) {
      logger.e('Error handling user profile change: $e');
    }
  }

  // Handle device changes
  void _handleDeviceChange(PostgresChangePayload payload) async {
    try {
      final eventType = payload.eventType;
      if (eventType == PostgresChangeEvent.insert ||
          eventType == PostgresChangeEvent.update ||
          eventType == PostgresChangeEvent.delete) {
        // Refresh devices based on user role
        if (_currentUser?.isAdmin == true) {
          await fetchAllDevices();
        } else {
          await fetchUserDevices();
        }
        notifyListeners();
      }
    } catch (e) {
      logger.e('Error handling device change: $e');
    }
  }

  // Clean up subscriptions
  @override
  void dispose() {
    _userChannel?.unsubscribe();
    _deviceChannel?.unsubscribe();
    super.dispose();
  }

  // Clear error message
  void clearError() {
    _errorMessage = '';
    notifyListeners();
  }

  // Check admin status
  Future<void> checkAdminStatus() async {
    Logger().i('Checking admin status...');

    // First ensure we have a current user
    if (_currentUser == null) {
      Logger()
          .w('No current user available. Attempting to fetch profile first...');
      await _fetchUserProfile();

      // If we still don't have a current user, we can't proceed
      if (_currentUser == null) {
        Logger().e('Failed to get user profile, cannot check admin status');
        return;
      }
    }

    try {
      Logger().i('Checking admin status for user: ${_currentUser?.id}');
      final data = await _supabase
          .from('profiles')
          .select('is_admin')
          .eq('id', _currentUser!.id)
          .single();

      Logger().i('Admin status from database: ${data['is_admin']}');
      Logger().i('Current admin status: ${_currentUser?.isAdmin}');

      if (_currentUser!.isAdmin != (data['is_admin'] ?? false)) {
        Logger().i('Updating admin status to: ${data['is_admin']}');
        // Update current user if admin status changed
        _currentUser =
            _currentUser!.copyWith(isAdmin: data['is_admin'] ?? false);
        notifyListeners();
      }
    } catch (e) {
      Logger().e('Error checking admin status: $e');
    }
  }

  // Fetch devices (alias for fetchUserDevices for compatibility with main.dart)
  Future<void> fetchDevices() async {
    await fetchUserDevices();
  }

  // Sign in with email and password
  Future<void> signIn(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      await _fetchUserProfile();
      await fetchUserDevices();
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Sign up with email and password
  Future<void> signUp(String email, String password, String fullName) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
      );

      if (response.user != null) {
        // Create profile for the new user
        await _supabase.from('profiles').insert({
          'id': response.user!.id,
          'email': email,
          'full_name': fullName,
          'is_admin': false,
        });

        await _fetchUserProfile();
      }
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _supabase.auth.signOut();
    _currentUser = null;
    _userDevices.clear();
    notifyListeners();
  }

  // Fetch current user's profile
  Future<void> _fetchUserProfile() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      logger.i('Fetching profile for user ID: $userId');
      if (userId == null) {
        logger.w('No current user ID found');
        _errorMessage = 'User session expired. Please log in again.';
        return;
      }

      final data =
          await _supabase.from('profiles').select().eq('id', userId).single();

      logger.i('Profile data retrieved: ${data.toString()}');
      logger.i('Admin status from DB: ${data['is_admin']}');

      _currentUser = AppUser(
        id: data['id'],
        email: data['email'],
        fullName: data['full_name'],
        isAdmin: data['is_admin'] ?? false,
        createdAt: DateTime.parse(data['created_at']),
        updatedAt: data['updated_at'] != null
            ? DateTime.parse(data['updated_at'])
            : null,
      );

      logger.i(
          'Current user created with admin status: ${_currentUser?.isAdmin}');
    } catch (e) {
      logger.e('Error fetching user profile: $e');
      _errorMessage = 'Failed to fetch user profile: ${e.toString()}';
      _currentUser = null;
    }
  }

  // Fetch devices associated with current user
  Future<void> fetchUserDevices() async {
    if (_currentUser == null) {
      _errorMessage = 'User not authenticated';
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      logger.i('Fetching devices for user: ${_currentUser!.id}');
      logger.i('Current user ID: ${_currentUser!.id}');

      final assignedDeviceIds = <String>{};

      // Devices directly assigned
      final directDevicesData = await _supabase
          .from('devices')
          .select()
          .eq('user_id', _currentUser!.id);
      for (var data in directDevicesData) {
        assignedDeviceIds.add(data['id']);
      }

      // Devices assigned via device_users
      final deviceUsersData = await _supabase
          .from('device_users')
          .select('device_id')
          .eq('user_id', _currentUser!.id);
      for (var item in deviceUsersData) {
        assignedDeviceIds.add(item['device_id']);
      }

      // Fetch all devices in one query
      if (assignedDeviceIds.isNotEmpty) {
        final devicesData = await _supabase
            .from('devices')
            .select()
            .filter('id', 'in', assignedDeviceIds.toList());
        _userDevices =
            devicesData.map<Device>((data) => Device.fromMap(data)).toList();
      } else {
        _userDevices = [];
      }

      Logger().i('Total devices fetched for user: ${_userDevices.length}');
      for (var device in _userDevices) {
        Logger().i('User device: ${device.id} - ${device.name}');
      }
    } catch (e) {
      logger.e('Error fetching user devices: $e');
      _errorMessage = 'Failed to fetch devices: ${e.toString()}';
      _userDevices.clear();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Update device settings
  Future<void> updateDeviceSettings(
    String deviceId, {
    String? name,
    bool? isActive,
    String? mode,
    int? speedPercentage,
    int? timerMinutes,
  }) async {
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (isActive != null) updates['is_active'] = isActive;
    if (mode != null) updates['mode'] = mode;
    if (speedPercentage != null) updates['speed_percentage'] = speedPercentage;
    if (timerMinutes != null) updates['timer_minutes'] = timerMinutes;

    if (updates.isEmpty) return;

    try {
      await _supabase.from('devices').update(updates).eq('id', deviceId);

      // Update local state
      if (_currentUser != null) {
        await fetchUserDevices();
      }

      // If admin, also update all devices list if it exists
      if (_currentUser?.isAdmin == true && _allDevices.isNotEmpty) {
        await fetchAllDevices();
      }

      // Log the action
      await _supabase.from('logs').insert({
        'device_id': deviceId,
        'action': 'Settings updated',
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      Logger().e('Error updating device settings: $e');
    }
  }

  // Toggle device active state
  Future<void> toggleDeviceActive(String deviceId, bool isActive) async {
    try {
      await _supabase
          .from('devices')
          .update({'is_active': isActive}).eq('id', deviceId);

      // Log the action using safe method
      await _safeLogInsert(
          deviceId: deviceId,
          userId: _supabase.auth.currentUser?.id,
          action: isActive ? 'Device activated' : 'Device deactivated');

      // Update local state
      await fetchDevices();

      // If this is the selected device, update it
      if (_selectedDevice?.id == deviceId) {
        await selectDevice(deviceId);
      }
    } catch (e) {
      Logger().e('Error toggling device active state: $e');
      _errorMessage = 'Failed to update device: ${e.toString()}';
      notifyListeners();
    }
  }

  // Set device mode (auto/manual)
  Future<void> setDeviceMode(String deviceId, String mode) async {
    try {
      await _supabase.from('devices').update({'mode': mode}).eq('id', deviceId);

      // Log the action with the safer method
      await _safeLogInsert(
          deviceId: deviceId,
          userId: _supabase.auth.currentUser?.id,
          action: 'Mode changed to $mode');

      // Update local state
      await fetchDevices();

      // If this is the selected device, update it
      if (_selectedDevice?.id == deviceId) {
        await selectDevice(deviceId);
      }
    } catch (e) {
      Logger().e('Error setting device mode: $e');
      _errorMessage = 'Failed to update device mode: ${e.toString()}';
      notifyListeners();
    }
  }

  // Update device status
  Future<void> updateDeviceStatus(String deviceId, bool motorOn) async {
    try {
      await _supabase.from('device_status').insert({
        'device_id': deviceId,
        'motor_on': motorOn,
      });

      // Log the action
      await _supabase.from('logs').insert({
        'device_id': deviceId,
        'user_id': _supabase.auth.currentUser?.id,
        'action': motorOn ? 'Motor turned on' : 'Motor turned off',
      });

      // Update local state
      if (_selectedDevice?.id == deviceId) {
        await selectDevice(deviceId);
      }
    } catch (e) {
      Logger().e('Error updating device status: $e');
      _errorMessage = 'Failed to update device status: ${e.toString()}';
      notifyListeners();
    }
  }

  // Select a device for detailed view
  Future<void> selectDevice(String deviceId) async {
    _isLoading = true;
    notifyListeners();

    try {
      // Get device details
      final deviceData =
          await _supabase.from('devices').select().eq('id', deviceId).single();

      // Get device status
      final statusData = await _supabase
          .from('device_status')
          .select()
          .eq('device_id', deviceId)
          .order('updated_at', ascending: false)
          .limit(1)
          .maybeSingle();

      // Create device object
      final device = Device.fromMap(deviceData);

      // Add status if available
      if (statusData != null) {
        _selectedDevice = device.copyWith(
          status: DeviceStatus.fromMap(statusData),
        );
      } else {
        _selectedDevice = device;
      }

      // Get device logs
      await fetchDeviceLogs(deviceId);
    } catch (e) {
      Logger().e('Error selecting device: $e');
      _errorMessage = 'Failed to load device details: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Fetch device logs
  Future<void> fetchDeviceLogs(String deviceId) async {
    try {
      final data = await _supabase
          .from('logs')
          .select()
          .eq('device_id', deviceId)
          .order('timestamp', ascending: false);

      _deviceLogs =
          data.map<DeviceLog>((log) => DeviceLog.fromMap(log)).toList();
    } catch (e) {
      Logger().e('Error fetching device logs: $e');
    }
  }

  // Refresh logs (for UI refreshing)
  Future<void> refreshLogs() async {
    if (_selectedDevice != null) {
      await fetchDeviceLogs(_selectedDevice!.id);
      notifyListeners();
    }
  }

  // ADMIN FUNCTIONS

  // Fetch system statistics for admin dashboard
  Future<void> fetchSystemStats() async {
    if (_currentUser?.isAdmin != true) return;

    try {
      final totalDevicesResult = await _supabase.rpc('count_devices');
      final activeDevicesResult = await _supabase.rpc('count_active_devices');
      final manualModeResult = await _supabase.rpc('count_manual_mode_devices');
      final totalUsersResult = await _supabase.rpc('count_users');

      _systemStats = {
        'total_devices': totalDevicesResult,
        'active_devices': activeDevicesResult,
        'manual_mode_devices': manualModeResult,
        'total_users': totalUsersResult,
      };
      notifyListeners();
    } catch (e) {
      Logger().e('Error fetching system stats: $e');
    }
  }

  // Fetch all users (admin only)
  Future<void> fetchAllUsers() async {
    if (_currentUser?.isAdmin != true) return;

    _isLoading = true;
    notifyListeners();

    try {
      final data = await _supabase.from('profiles').select();

      _users = data
          .map<AppUser>((user) => AppUser(
                id: user['id'],
                email: user['email'],
                fullName: user['full_name'],
                isAdmin: user['is_admin'] ?? false,
                createdAt: DateTime.parse(user['created_at']),
                updatedAt: DateTime.parse(user['updated_at']),
              ))
          .toList();
    } catch (e) {
      Logger().e('Error fetching all users: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Fetch all devices (admin only)
  Future<void> fetchAllDevices() async {
    if (_currentUser?.isAdmin != true) return;

    _isLoading = true;
    notifyListeners();

    try {
      // Get all devices with their assigned users
      final data =
          await _supabase.from('devices').select('*, device_users(user_id)');
      Logger().i('Admin: Fetched ${data.length} devices from database');

      _allDevices = data.map<Device>((device) {
        // The device data itself
        final deviceData = {...device};

        // Remove the device_users data to avoid parsing conflicts
        deviceData.remove('device_users');

        return Device.fromJson(deviceData);
      }).toList();
    } catch (e) {
      Logger().e('Error fetching all devices: $e');
      _errorMessage = 'Failed to load devices: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Fetch all system logs (admin only)
  Future<void> fetchAllLogs() async {
    if (_currentUser?.isAdmin != true) return;

    _isLoading = true;
    notifyListeners();

    try {
      final data = await _supabase
          .from('logs')
          .select()
          .order('timestamp', ascending: false);

      _allLogs = data.map<SystemLog>((log) => SystemLog.fromJson(log)).toList();
    } catch (e) {
      Logger().e('Error fetching system logs: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Clear all logs (admin only)
  Future<void> clearAllLogs() async {
    if (_currentUser?.isAdmin != true) return;

    _isLoading = true;
    notifyListeners();

    try {
      // Create a backup of logs before deletion if needed in future
      final now = DateTime.now();
      final backupName =
          'logs_backup_${now.year}${now.month}${now.day}_${now.hour}${now.minute}';

      // Store this action itself as a special log that won't be deleted
      await _supabase.from('admin_audit').insert({
        'user_id': _currentUser?.id,
        'action': 'Cleared all system logs',
        'timestamp': now.toIso8601String(),
        'backup_name': backupName
      });

      // Delete all logs from the logs table
      await _supabase.from('logs').delete().neq('id', '0');

      // Clear the logs in memory
      _allLogs = [];

      // Add a new entry indicating the logs were cleared
      final response = await _supabase
          .from('logs')
          .insert({
            'device_id': null,
            'user_id': _currentUser?.id,
            'action': 'System logs cleared',
            'details': 'All previous logs were deleted by administrator',
            'timestamp': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      // Add the new log to our list
      _allLogs = [SystemLog.fromJson(response)];

      notifyListeners();
    } catch (e) {
      Logger().e('Error clearing logs: $e');
      _errorMessage = 'Failed to clear logs: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Export logs as CSV file (admin only)
  Future<void> exportLogsAsCSV() async {
    if (_currentUser?.isAdmin != true) return;

    try {
      // In a real app, this would create and download a CSV file
      // using path_provider and csv packages

      // Log this action
      await _supabase.from('admin_audit').insert({
        'user_id': _currentUser?.id,
        'action': 'Exported logs as CSV',
        'timestamp': DateTime.now().toIso8601String(),
      });

      // Simulate file processing delay
      await Future.delayed(Duration(seconds: 1));

      // This is a stub implementation - in a real app you would:
      // 1. Create a CSV string from _allLogs
      // 2. Save to a file using path_provider
      // 3. Share the file

      Logger().i('CSV export completed');
    } catch (e) {
      Logger().e('Error exporting CSV: $e');
      _errorMessage = 'Failed to export logs: ${e.toString()}';
      notifyListeners();
    }
  }

  // Export logs as JSON file (admin only)
  Future<void> exportLogsAsJSON() async {
    if (_currentUser?.isAdmin != true) return;

    try {
      // In a real app, this would create and download a JSON file
      // using path_provider package

      // Log this action
      await _supabase.from('admin_audit').insert({
        'user_id': _currentUser?.id,
        'action': 'Exported logs as JSON',
        'timestamp': DateTime.now().toIso8601String(),
      });

      // Simulate file processing delay
      await Future.delayed(Duration(seconds: 1));

      // This is a stub implementation - in a real app you would:
      // 1. Convert _allLogs to a JSON string
      // 2. Save to a file using path_provider
      // 3. Share the file

      Logger().i('JSON export completed');
    } catch (e) {
      Logger().e('Error exporting JSON: $e');
      _errorMessage = 'Failed to export logs: ${e.toString()}';
      notifyListeners();
    }
  }

  // Add a specific log entry (admin or system)
  Future<void> addLogEntry({
    required String deviceId,
    required String action,
    String? userId,
    String? details,
  }) async {
    try {
      // Use safe log insert method instead of direct insert
      await _safeLogInsert(
          action: action,
          deviceId: deviceId,
          userId: userId ?? _currentUser?.id,
          details: details);

      // If we have logs loaded in memory and we're an admin, update the in-memory list
      if (_currentUser?.isAdmin == true && _allLogs.isNotEmpty) {
        await fetchAllLogs();
      }

      // If this is for the currently selected device, update device logs too
      if (_selectedDevice != null && _selectedDevice!.id == deviceId) {
        await fetchDeviceLogs(deviceId);
      }
    } catch (e) {
      Logger().e('Error adding log entry: $e');
    }
  }

  // Get filtered logs for a specific device, date range, or log type
  Future<List<SystemLog>> getFilteredLogs({
    String? deviceId,
    String? userId,
    String? actionType,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (_currentUser?.isAdmin != true) return [];

    try {
      var query = _supabase.from('logs').select();

      // Apply filters
      if (deviceId != null) {
        query = query.eq('device_id', deviceId);
      }

      if (userId != null) {
        query = query.eq('user_id', userId);
      }

      if (actionType != null) {
        query = query.ilike('action', '%$actionType%');
      }

      if (startDate != null) {
        query = query.gte('timestamp', startDate.toIso8601String());
      }

      if (endDate != null) {
        query = query.lte('timestamp', endDate.toIso8601String());
      }

      // Sort by timestamp descending
      final data = await query.order('timestamp', ascending: false);

      return data.map<SystemLog>((log) => SystemLog.fromJson(log)).toList();
    } catch (e) {
      Logger().e('Error getting filtered logs: $e');
      return [];
    }
  }

  // Create new device (admin only)
  Future<void> createDevice({
    required String name,
    String? sensorId,
    String? userId, // Optional user to assign the device to
    String mode = 'auto',
    int speedPercentage = 50,
    int timerMinutes = 0,
    int nodeRole = 1, // Default to Coordinator (1)
  }) async {
    if (_currentUser?.isAdmin != true) return;

    try {
      // Insert the device and get back the created record
      final response = await _supabase
          .from('devices')
          .insert({
            'name': name,
            'sensor_id': sensorId,
            'is_active': false,
            'mode': mode,
            'speed_percentage': speedPercentage,
            'timer_minutes': timerMinutes,
            'node_role': nodeRole,
            'user_id': null, // No direct user assignment during creation
          })
          .select()
          .single();

      final String deviceId = response['id'];

      // If a user ID was provided, assign the device to that user
      if (userId != null) {
        await _supabase.from('device_users').insert({
          'device_id': deviceId,
          'user_id': userId,
          'assigned_at': DateTime.now().toIso8601String(),
        });
      }

      // Log the device creation with the actual device ID
      await _supabase.from('logs').insert({
        'device_id': deviceId,
        'user_id': _currentUser?.id,
        'action': 'New device created: $name',
      });

      await fetchAllDevices();

      // If the created device should appear for the current user, refresh user devices too
      if (userId == _currentUser?.id) {
        await fetchUserDevices();
      }
    } catch (e) {
      Logger().e('Error creating device: $e');
      _errorMessage = 'Failed to create device: ${e.toString()}';
      notifyListeners();
    }
  }

  // Delete device (admin only)
  Future<void> deleteDevice(String deviceId) async {
    if (_currentUser?.isAdmin != true) return;

    try {
      await _supabase.from('devices').delete().eq('id', deviceId);

      await fetchAllDevices();
    } catch (e) {
      Logger().e('Error deleting device: $e');
    }
  }

  // Update existing device (admin only)
  Future<void> updateDevice({
    required String deviceId,
    required String name,
    String? sensorId,
    String? mode,
    int? speedPercentage,
    int? timerMinutes,
    bool? isActive,
    int? nodeRole,
  }) async {
    if (_currentUser?.isAdmin != true) return;

    try {
      final Map<String, dynamic> updates = {
        'name': name,
        'sensor_id': sensorId,
      };

      if (mode != null) updates['mode'] = mode;
      if (speedPercentage != null) {
        updates['speed_percentage'] = speedPercentage;
      }
      if (timerMinutes != null) updates['timer_minutes'] = timerMinutes;
      if (isActive != null) updates['is_active'] = isActive;
      if (nodeRole != null) updates['node_role'] = nodeRole;

      await _supabase.from('devices').update(updates).eq('id', deviceId);

      await fetchAllDevices();
    } catch (e) {
      Logger().e('Error updating device: $e');
    }
  }

  // Assign device to user (admin only)
  Future<void> assignDeviceToUser(String deviceId, String userId) async {
    if (_currentUser?.isAdmin != true) return;

    try {
      // First check if there's already a device_users record
      final existing = await _supabase
          .from('device_users')
          .select()
          .eq('device_id', deviceId)
          .eq('user_id', userId)
          .maybeSingle();

      if (existing == null) {
        // Only insert if it doesn't exist yet
        await _supabase.from('device_users').insert({
          'device_id': deviceId,
          'user_id': userId,
          'assigned_at': DateTime.now().toIso8601String(),
        });
      }

      // Log the action
      await _supabase.from('logs').insert({
        'device_id': deviceId,
        'user_id': _currentUser?.id,
        'action': 'Device assigned to user',
      });

      await fetchAllDevices();
    } catch (e) {
      Logger().e('Error assigning device: $e');
    }
  }

  // Get users assigned to a device
  Future<List<String>> getUsersForDevice(String deviceId) async {
    // Removed admin-only restriction
    try {
      final data = await _supabase
          .from('device_users')
          .select('user_id')
          .eq('device_id', deviceId);

      return (data as List)
          .map<String>((item) => item['user_id'] as String)
          .toList();
    } catch (e) {
      Logger().e('Error getting users for device: $e');
      return [];
    }
  }

  // Remove device from user (admin only)
  Future<void> removeDeviceFromUser(String deviceId) async {
    if (_currentUser?.isAdmin != true) return;

    try {
      await _supabase.from('device_users').delete().eq('device_id', deviceId);

      await fetchAllDevices();
    } catch (e) {
      Logger().e('Error removing device assignment: $e');
    }
  }

  // Remove specific device-user assignment (admin only)
  Future<void> removeUserFromDevice(String deviceId, String userId) async {
    if (_currentUser?.isAdmin != true) return;

    try {
      await _supabase
          .from('device_users')
          .delete()
          .eq('device_id', deviceId)
          .eq('user_id', userId);

      // Log the action
      await _supabase.from('logs').insert({
        'device_id': deviceId,
        'user_id': _currentUser?.id,
        'action': 'User removed from device',
      });

      await fetchAllDevices();
    } catch (e) {
      Logger().e('Error removing user from device: $e');
    }
  }

  // Update user's admin status (admin only)
  Future<void> updateUserAdminStatus(String userId, bool isAdmin) async {
    if (_currentUser?.isAdmin != true) return;

    try {
      await _supabase.from('profiles').update({
        'is_admin': isAdmin,
      }).eq('id', userId);

      // Log the action
      await _supabase.from('logs').insert({
        'device_id': null,
        'user_id': _currentUser?.id,
        'action': 'User admin status changed',
      });

      // Update local state
      await fetchAllUsers();
    } catch (e) {
      Logger().e('Error updating user admin status: $e');
      _errorMessage = 'Failed to update user admin status: ${e.toString()}';
      notifyListeners();
    }
  }

  // Helper method to safely insert log entries with RLS handling
  Future<void> _safeLogInsert(
      {required String action,
      String? deviceId,
      String? userId,
      String? details}) async {
    try {
      final Map<String, dynamic> logEntry = {
        'action': action,
        'user_id': userId ?? _currentUser?.id,
        'timestamp': DateTime.now().toIso8601String(),
      };

      // Only add deviceId if provided (null might not be allowed by RLS)
      if (deviceId != null) {
        logEntry['device_id'] = deviceId;
      }

      // Only add details if provided and the column exists
      if (details != null) {
        logEntry['details'] = details;
      }

      await _supabase.from('logs').insert(logEntry);
    } catch (e) {
      // Don't throw or show UI errors for logging failures
      Logger().w('Failed to insert log entry: $e');
    }
  }
}
