import 'package:flutter/material.dart';

import '../../../network/api_client.dart';

/// Picks a patient before a staff booking.
Future<String?> showPatientPicker(
  BuildContext context,
  ApiClient apiClient,
) async {
  List<Map<String, dynamic>> patients;
  try {
    final response = await apiClient.get<Map<String, dynamic>>(
      '/api/patients',
      queryParameters: {'size': 100, 'sort': 'user.lastName,asc'},
    );
    patients = (response.data?['content'] as List<dynamic>? ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not load patients.')));
    }
    return null;
  }

  if (!context.mounted) return null;
  return showDialog<String>(
    context: context,
    builder: (context) {
      final searchController = TextEditingController();
      return StatefulBuilder(
        builder: (context, setDialogState) {
          final query = searchController.text.trim().toLowerCase();
          final filteredPatients = patients.where((patient) {
            final name =
                '${patient['firstName'] ?? ''} ${patient['lastName'] ?? ''}'
                    .toLowerCase();
            return query.isEmpty || name.contains(query);
          }).toList();
          return AlertDialog(
            title: const Text('Select patient'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: searchController,
                    autofocus: true,
                    onChanged: (_) => setDialogState(() {}),
                    decoration: const InputDecoration(
                      hintText: 'Search by patient name',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (filteredPatients.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('No patients found.'),
                    )
                  else
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: filteredPatients.length,
                        itemBuilder: (_, index) {
                          final patient = filteredPatients[index];
                          return ListTile(
                            leading: const Icon(Icons.person_outline),
                            title: Text(
                              '${patient['firstName'] ?? ''} ${patient['lastName'] ?? ''}',
                            ),
                            subtitle: Text(
                              patient['phone']?.toString() ??
                                  patient['email']?.toString() ??
                                  'No contact',
                            ),
                            onTap: () => Navigator.of(
                              context,
                            ).pop(patient['id']?.toString()),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
