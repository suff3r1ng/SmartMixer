import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/device.dart';
import '../models/user.dart';

class AdminService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Check if the current user has admin privileges
  Future<bool> isCurrentUserAdmin() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      final response = await _supabase
          .from('profiles')
          .select('is_admin')
          .eq('id', userId)
          .single();

      return response['is_admin'] ?? false;
    } catch (e) {
      print('Error checking admin status: $e');
      return false;
    }
  }

  Future<Map<String, int>> getSystemStats() async {
    try {
      final deviceCount = await _supabase.from('devices').select('*').count();

      final userCount = await _supabase.from('profiles').select('*').count();

      final activeDevices = await _supabase
          .from('devices')
          .select('*')
          .eq('is_active', true)
          .count();

      final manualModeDevices = await _supabase
          .from('devices')
          .select('*')
          .eq('mode', 'manual')
          .count();

      return {
        'total_devices': deviceCount.count,
        'total_users': userCount.count,
        'active_devices': activeDevices.count,
        'manual_mode_devices': manualModeDevices.count,
      };
    } catch (e) {
      print('Error fetching system stats: $e');
      return {
        'total_devices': 0,
        'total_users': 0,
        'active_devices': 0,
        'manual_mode_devices': 0,
      };
    }
  }

  Future<List<Device>> getAllDevices() async {
    try {
      final response = await _supabase
          .from('devices')
          .select('*, status:device_status(*)')
          .order('name');

      return (response as List)
          .map((device) => Device.fromMap(device))
          .toList();
    } catch (e) {
      print('Error fetching all devices: $e');
      return [];
    }
  }

  Future<List<AppUser>> getAllUsers() async {
    try {
      final response = await _supabase
          .from('profiles')
          .select(
              '*, auth_id:auth.users!auth_id(email, created_at, last_sign_in_at)')
          .order('created_at');

      return (response as List).map((userData) {
        final authData = userData['auth_id'] as List;
        final authUser = authData.isNotEmpty ? authData.first : null;

        return AppUser.fromMap({
          'id': userData['id'],
          'email': authUser != null ? authUser['email'] : 'No email',
          'first_name': userData['first_name'],
          'last_name': userData['last_name'],
          'is_admin': userData['is_admin'] ?? false,
          'created_at': authUser != null
              ? authUser['created_at']
              : userData['created_at'],
          'last_sign_in_at':
              authUser != null ? authUser['last_sign_in_at'] : null,
        });
      }).toList();
    } catch (e) {
      print('Error fetching all users: $e');
      return [];
    }
  }

  Future<List<DeviceLog>> getAllLogs() async {
    try {
      final response = await _supabase
          .from('device_logs')
          .select('*')
          .order('created_at', ascending: false)
          .limit(100);

      return (response as List).map((log) => DeviceLog.fromMap(log)).toList();
    } catch (e) {
      print('Error fetching logs: $e');
      return [];
    }
  }

  Future<bool> updateUserAdminStatus(String userId, bool isAdmin) async {
    try {
      await _supabase
          .from('profiles')
          .update({'is_admin': isAdmin}).eq('id', userId);

      return true;
    } catch (e) {
      print('Error updating user admin status: $e');
      return false;
    }
  }

  Future<bool> assignDeviceToUser(String deviceId, String userId) async {
    try {
      await _supabase
          .from('devices')
          .update({'user_id': userId}).eq('id', deviceId);

      // Log the assignment
      await _supabase.from('device_logs').insert({
        'device_id': deviceId,
        'user_id': _supabase.auth.currentUser?.id,
        'action': 'Device assigned to user',
      });

      return true;
    } catch (e) {
      print('Error assigning device to user: $e');
      return false;
    }
  }

  Future<Device?> createDevice({
    required String name,
    String? sensorId,
  }) async {
    try {
      final response = await _supabase
          .from('devices')
          .insert({
            'name': name,
            'sensor_id': sensorId,
            'is_active': false,
            'mode': 'auto',
          })
          .select()
          .single();

      // Log the creation
      await _supabase.from('device_logs').insert({
        'device_id': response['id'],
        'user_id': _supabase.auth.currentUser?.id,
        'action': 'Device created',
      });

      return Device.fromMap(response);
    } catch (e) {
      print('Error creating device: $e');
      return null;
    }
  }

  Future<bool> deleteDevice(String deviceId) async {
    try {
      // First, delete any device status records
      await _supabase.from('device_status').delete().eq('device_id', deviceId);

      // Then delete the device
      await _supabase.from('devices').delete().eq('id', deviceId);

      return true;
    } catch (e) {
      print('Error deleting device: $e');
      return false;
    }
  }
}
