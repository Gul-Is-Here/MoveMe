import 'package:flutter/material.dart';

class VehicleModel {
  const VehicleModel({
    this.id = '',
    required this.nickname,
    required this.makeModel,
    required this.plateNumber,
    required this.color,
    this.hasUnread = false,
    this.colorName = '',
    this.dateOfRegistration = '',
    this.engineNumber = '',
    this.chassisNumber = '',
    this.address = '',
    this.photoPaths = const [],
  });

  /// Firestore document id (`users/{uid}/vehicles/{id}`). Also the QR
  /// sticker's payload key (FR-03: `{scanBaseUrl}/scan/{id}`).
  final String id;
  final String nickname;
  final String makeModel;
  final String plateNumber;
  final Color color;
  final bool hasUnread;

  final String colorName;
  final String dateOfRegistration;
  final String engineNumber;
  final String chassisNumber;
  final String address;
  final List<String> photoPaths;

  /// The URL this vehicle's QR sticker encodes — the public Scan Contact
  /// Page (FR-04), which never shows this data locally, only via that page.
  ///
  /// `parktag.app` isn't a domain this app owns or has deployed to, so this
  /// points at the actual Firebase Hosting URL instead — swap [scanBaseUrl]
  /// once a real custom domain is attached to the Firebase Hosting site.
  String get qrScanUrl => '$scanBaseUrl/scan/$id';
}

/// Base URL the public Scan Contact Page is actually deployed to
/// (`firebase deploy --only hosting`, project `moveme-da262`).
const scanBaseUrl = 'https://moveme-da262.web.app';
