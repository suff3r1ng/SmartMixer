import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/device.dart';

class DeviceService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Get all devices for current user
  Future<List<Device>> getUserDevices() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    final response =
        await _supabase.from('devices').select().eq('assigned_user', user.id);

    return (response as List).map((device) => Device.fromMap(device)).toList();
  }

  // Get a specific device with its status
  Future<Device> getDeviceWithStatus(String deviceId) async {
    // Get device data
    final deviceResponse =
        await _supabase.from('devices').select().eq('id', deviceId).single();

    // Get device status
    final statusResponse = await _supabase
        .from('device_status')
        .select()
        .eq('device_id', deviceId)
        .order('updated_at', ascending: false)
        .limit(1)
        .maybeSingle();

    final device = Device.fromMap(deviceResponse);

    // If status exists, add it to the device
    if (statusResponse != null) {
      return device.copyWith(
        status: DeviceStatus.fromMap(statusResponse),
      );
    }

    return device;
  }

  // Toggle device active state
  Future<Device> toggleDeviceActive(String deviceId, bool isActive) async {
    final response = await _supabase
        .from('devices')
        .update({'is_active': isActive})
        .eq('id', deviceId)
        .select()
        .single();

    // Log the action
    await _logDeviceAction(
      deviceId: deviceId,
      action: isActive ? 'Device activated' : 'Device deactivated',
    );

    return Device.fromMap(response);
  }

  // Set device mode (auto/manual)
  Future<Device> setDeviceMode(String deviceId, String mode) async {
    final response = await _supabase
        .from('devices')
        .update({'mode': mode})
        .eq('id', deviceId)
        .select()
        .single();

    // Log the action
    await _logDeviceAction(
      deviceId: deviceId,
      action: 'Mode changed to $mode',
    );

    return Device.fromMap(response);
  }

  // Update device status
  Future<DeviceStatus> updateDeviceStatus(
      String deviceId, bool motorOn, bool glassPresent) async {
    final response = await _supabase
        .from('device_status')
        .insert({
          'device_id': deviceId,
          'motor_on': motorOn,
          'glass_present': glassPresent,
        })
        .select()
        .single();

    // Log the action
    await _logDeviceAction(
      deviceId: deviceId,
      action: motorOn ? 'Motor turned on' : 'Motor turned off',
    );

    return DeviceStatus.fromMap(response);
  }

  // Get device logs
  Future<List<DeviceLog>> getDeviceLogs(String deviceId) async {
    final response = await _supabase
        .from('logs')
        .select()
        .eq('device_id', deviceId)
        .order('timestamp', ascending: false);

    return (response as List).map((log) => DeviceLog.fromMap(log)).toList();
  }

  // Private method to log device actions
  Future<void> _logDeviceAction({
    required String deviceId,
    required String action,
  }) async {
    final user = _supabase.auth.currentUser;

    await _supabase.from('logs').insert({
      'device_id': deviceId,
      'action': action,
      'user_id': user?.id,
    });
  }
}
