import 'package:cloud_firestore/cloud_firestore.dart';

class DonationModel {
  final String id;
  final String donorName;
  final double amount;
  final String govId;
  final DateTime date;

  DonationModel({
    required this.id,
    required this.donorName,
    required this.amount,
    required this.govId,
    required this.date,
  });

  factory DonationModel.fromMap(Map<String, dynamic> data) {
    return DonationModel(
      id: data['donationId'] ?? '',
      donorName: data['donorName'] ?? 'Unknown',
      amount: (data['amount'] ?? 0).toDouble(),
      govId: data['govId'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
    );
  }
}