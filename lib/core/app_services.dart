import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import 'models.dart';

/// Owns AppSettingsData + AlertSettingsData in GetStorage and persists every
/// mutation (plan §7, Hive swapped for GetStorage per build brief).
class SettingsService extends GetxService {
  static const _kSettings = 'app_settings_v1';
  static const _kAlerts = 'alert_settings_v1';
  final _box = GetStorage();

  final settings = AppSettingsData().obs;
  final alerts = AlertSettingsData().obs;

  @override
  void onInit() {
    super.onInit();
    final s = _box.read(_kSettings);
    if (s is Map) {
      settings.value = AppSettingsData.fromJson(Map<String, dynamic>.from(s));
    }
    final a = _box.read(_kAlerts);
    if (a is Map) {
      alerts.value = AlertSettingsData.fromJson(Map<String, dynamic>.from(a));
    }
  }

  void saveSettings() => _box.write(_kSettings, settings.value.toJson());
  void saveAlerts() => _box.write(_kAlerts, alerts.value.toJson());

  void updateSettings(void Function(AppSettingsData s) fn) {
    fn(settings.value);
    settings.refresh();
    saveSettings();
  }

  void updateAlerts(void Function(AlertSettingsData a) fn) {
    fn(alerts.value);
    alerts.refresh();
    saveAlerts();
  }
}

/// Location: bundled offline city list + GPS/reverse-geocode helpers.
class LocationService extends GetxService {
  final cities = <CityEntry>[].obs;

  Future<void> loadCities() async {
    if (cities.isNotEmpty) return;
    final raw = await rootBundle.loadString('assets/data/cities.json');
    final list = json.decode(raw) as List;
    cities.assignAll(
        list.map((e) => CityEntry.fromJson(Map<String, dynamic>.from(e as Map))));
  }

  /// Returns the device's position, or null when permission/service denied.
  Future<Position?> currentPosition() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return null;
      }
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 12),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  /// Best-effort city/country naming for GPS coordinates (on-device geocoder).
  Future<({String city, String country, String code})?> reverseGeocode(
      double lat, double lng) async {
    try {
      final marks = await placemarkFromCoordinates(lat, lng);
      if (marks.isEmpty) return null;
      final m = marks.first;
      final city = (m.locality?.isNotEmpty ?? false)
          ? m.locality!
          : (m.subAdministrativeArea ?? m.administrativeArea ?? 'Current location');
      return (
        city: city,
        country: m.country ?? '',
        code: (m.isoCountryCode ?? '').toUpperCase(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Nearest bundled city (fallback naming + country defaults for GPS fixes).
  CityEntry? nearestCity(double lat, double lng) {
    CityEntry? best;
    var bestKm = double.infinity;
    for (final c in cities) {
      final d = Geolocator.distanceBetween(lat, lng, c.lat, c.lng) / 1000;
      if (d < bestKm) {
        bestKm = d;
        best = c;
      }
    }
    return best;
  }
}
