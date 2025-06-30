import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart' hide Border;
import '../widgets/callai_logo.dart';

class ExcelUploadScreen extends StatefulWidget {
  final Function(List<Map<String, String>>) onContactsLoaded;
  final String? deviceId;
  
  const ExcelUploadScreen({
    Key? key,
    required this.onContactsLoaded,
    this.deviceId,
  }) : super(key: key);

  @override
  State<ExcelUploadScreen> createState() => _ExcelUploadScreenState();
}

class _ExcelUploadScreenState extends State<ExcelUploadScreen> {
  String? _selectedFilePath;
  List<Map<String, String>> _contactsPreview = [];
  bool _isLoading = false;
  String? _errorMessage;
  bool _showPreview = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue.shade900,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Upload Contacts',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 40),
            
            // Logo
            const Center(child: CallAILogo()),
            
            const SizedBox(height: 40),
            
            // Instructions
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.upload_file,
                    color: Colors.white,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Upload Your Contacts',
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Upload a CSV or Excel file with your contacts.\n\nRequired format:\n• First column: Name\n• Second column: Phone Number\n\nExample:\nName,Number\nJohn Doe,9876543210\nJane Smith,9876543211',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 30),
            
            // Upload Button
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _pickFile,
              icon: _isLoading 
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.upload_file),
              label: Text(
                _isLoading ? 'Processing...' : 'Choose File',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.blue.shade900,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Selected File Info
            if (_selectedFilePath != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'File Selected',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              color: Colors.green,
                            ),
                          ),
                          Text(
                            _selectedFilePath!.split('/').last,
                            style: GoogleFonts.poppins(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Preview Button
              if (_contactsPreview.isNotEmpty) ...[
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _showPreview = !_showPreview;
                    });
                  },
                  icon: Icon(_showPreview ? Icons.visibility_off : Icons.visibility),
                  label: Text(_showPreview ? 'Hide Preview' : 'Show Preview'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Use Contacts Button
                ElevatedButton.icon(
                  onPressed: () {
                    widget.onContactsLoaded(_contactsPreview);
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.check),
                  label: Text('Use ${_contactsPreview.length} Contacts'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ],
            
            // Error Message
            if (_errorMessage != null) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.red),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: GoogleFonts.poppins(
                          color: Colors.red,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            // Preview Section
            if (_showPreview && _contactsPreview.isNotEmpty) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Preview (${_contactsPreview.length} contacts)',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListView.builder(
                        itemCount: _contactsPreview.length,
                        itemBuilder: (context, index) {
                          final contact = _contactsPreview[index];
                          return ListTile(
                            dense: true,
                            title: Text(
                              contact['name'] ?? '',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: Text(
                              contact['phone'] ?? '',
                              style: GoogleFonts.poppins(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            leading: CircleAvatar(
                              backgroundColor: Colors.blue.shade700,
                              child: Text(
                                (contact['name'] ?? '')[0].toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _pickFile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _selectedFilePath = null;
      _contactsPreview = [];
      _showPreview = false;
    });

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xls', 'xlsx'],
      );

      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        final file = File(path);
        
        if (!await file.exists()) {
          throw Exception('Selected file does not exist.');
        }

        // Read contacts from file
        final contacts = await _readContactsFromFile(path);
        
        if (contacts.isEmpty) {
          throw Exception('No valid contacts found in the file.');
        }

        setState(() {
          _selectedFilePath = path;
          _contactsPreview = contacts;
          _isLoading = false;
        });

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully loaded ${contacts.length} contacts'),
            backgroundColor: Colors.green,
          ),
        );

      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _cleanPhoneNumber(String raw) {
    var cleaned = raw.trim();
    // If it's a number that got converted to a double string (e.g., "123.0"), fix it.
    if (cleaned.endsWith('.0')) {
      cleaned = cleaned.substring(0, cleaned.length - 2);
    }
    // Remove any other non-numeric characters.
    return cleaned.replaceAll(RegExp(r'[^\d]'), '');
  }

  Future<List<Map<String, String>>> _readContactsFromFile(String path) async {
    List<Map<String, String>> contacts = [];
    var file = File(path);
    
    print('[DEBUG] Reading contacts from file: $path');
    print('[DEBUG] File exists: ${await file.exists()}');
    print('[DEBUG] File size: ${await file.length()} bytes');

    if (path.endsWith('.csv')) {
      try {
        final content = await file.readAsString();
        print('[DEBUG] CSV content length: ${content.length} characters');
        print('[DEBUG] CSV content preview: ${content.substring(0, content.length > 300 ? 300 : content.length)}');
        
        final rows = const CsvToListConverter(shouldParseNumbers: false).convert(content);
        print('[DEBUG] Total rows in CSV: ${rows.length}');
        
        if (rows.isEmpty || rows[0].length < 2) {
          throw Exception('Invalid CSV format. File must have at least 2 columns.');
        }
        
        // Validate headers
        final headers = rows[0].map((e) => e.toString().trim().toLowerCase()).toList();
        if (headers.length < 2) {
          throw Exception('CSV must have at least 2 columns: Name and Phone Number.');
        }
        
        // Skip header row, start from the second row (index 1)
        for (var i = 1; i < rows.length; i++) {
          var row = rows[i];
          print('[DEBUG] Processing row $i: $row');
          
          // Skip comment lines (starting with #)
          if (row.isNotEmpty && row[0].toString().trim().startsWith('#')) {
            print('[DEBUG] Skipping comment row: $row');
            continue;
          }
          
          if (row.length >= 2) {
            final rawPhone = row[1].toString();
            final phone = _cleanPhoneNumber(rawPhone);
            final name = row[0].toString().trim();
            
            // Skip empty rows
            if (name.isEmpty || phone.isEmpty) {
              continue;
            }
            
            print('[DEBUG] CSV contact: name="$name" raw="$rawPhone" cleaned="$phone"');
            
            if (phone.length != 10) {
              print('[WARNING] Cleaned phone number is not 10 digits: "$phone" from row: $row');
            }
            
            contacts.add({'name': name, 'phone': phone});
          } else {
            print('[WARNING] Row $i has insufficient columns: $row');
          }
        }
      } catch (e) {
        print('[ERROR] Error reading CSV file: $e');
        throw Exception('Failed to read CSV file: $e');
      }
    } else if (path.endsWith('.xls') || path.endsWith('.xlsx')) {
      try {
        var bytes = await file.readAsBytes();
        print('[DEBUG] Excel file size: ${bytes.length} bytes');
        
        var excel = Excel.decodeBytes(bytes);
        var sheet = excel.tables[excel.tables.keys.first];
        if (sheet != null) {
          print('[DEBUG] Excel sheet rows: ${sheet.maxRows}');
          
          // Skip header row, start from the second row (index 1)
          for (var i = 1; i < sheet.maxRows; i++) {
            var row = sheet.row(i);
            print('[DEBUG] Processing Excel row $i: $row');
            
            if (row.length >= 2 && row[0]?.value != null && row[1]?.value != null) {
              final rawPhone = row[1]!.value.toString();
              final phone = _cleanPhoneNumber(rawPhone);
              final name = row[0]!.value.toString().trim();
              
              // Skip empty rows
              if (name.isEmpty || phone.isEmpty) {
                continue;
              }
              
              print('[DEBUG] Excel contact: name="$name" raw="$rawPhone" cleaned="$phone"');
              
              if (phone.length != 10) {
                print('[WARNING] Cleaned phone number is not 10 digits: "$phone" from row: $row');
              }
              
              contacts.add({
                'name': name,
                'phone': phone
              });
            } else {
              print('[WARNING] Excel row $i has insufficient data: $row');
            }
          }
        } else {
          throw Exception('No sheet found in Excel file');
        }
      } catch (e) {
        print('[ERROR] Error reading Excel file: $e');
        throw Exception('Failed to read Excel file: $e');
      }
    } else {
      throw Exception('Unsupported file format. Please use CSV, XLS, or XLSX files.');
    }
    
    print('[DEBUG] Total contacts loaded: ${contacts.length}');
    return contacts;
  }
} 