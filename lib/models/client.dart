import 'package:mongo_dart/mongo_dart.dart';

class Client {
  final ObjectId? id;
  final String clientId;
  final String companyName;
  final String passwordDigest;
  final bool archived;
  final String contact;
  final String email;
  final Map<String, String> phoneNumbers;

  const Client({
    this.id,
    required this.clientId,
    required this.companyName,
    required this.passwordDigest,
    required this.archived,
    required this.contact,
    required this.email,
    required this.phoneNumbers,
  });

  factory Client.fromMap(Map<String, dynamic> map) => Client(
        id: map['_id'] as ObjectId?,
        clientId: (map['client_id'] as String?) ?? '',
        companyName: (map['company_name'] as String?) ?? '',
        passwordDigest: (map['password_digest'] as String?) ?? '',
        archived: (map['archived'] as bool?) ?? false,
        contact: (map['contact'] as String?) ?? '',
        email: (map['email'] as String?) ?? '',
        phoneNumbers: Map<String, String>.from(
          (map['phone_numbers'] as Map?) ?? const {},
        ),
      );

  Map<String, dynamic> toMap() => {
        if (id != null) '_id': id,
        'client_id': clientId,
        'company_name': companyName,
        'password_digest': passwordDigest,
        'archived': archived,
        'contact': contact,
        'email': email,
        'phone_numbers': phoneNumbers,
      };

  Client copyWith({
    String? clientId,
    String? companyName,
    String? passwordDigest,
    bool? archived,
    String? contact,
    String? email,
    Map<String, String>? phoneNumbers,
  }) =>
      Client(
        id: id,
        clientId: clientId ?? this.clientId,
        companyName: companyName ?? this.companyName,
        passwordDigest: passwordDigest ?? this.passwordDigest,
        archived: archived ?? this.archived,
        contact: contact ?? this.contact,
        email: email ?? this.email,
        phoneNumbers: phoneNumbers ?? this.phoneNumbers,
      );
}
