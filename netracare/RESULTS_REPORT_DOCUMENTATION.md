# Results Report Page - Documentation

## Overview

The `ResultsReportPage` is a comprehensive Flutter page that displays eye health test results with an AI-powered analysis. This page was built based on a React component design and fully converted to Flutter with Material Design.

## Features

### 📊 **Overall Health Score**
- Circular progress indicator showing the overall health score (0-100)
- Summary cards showing tests completed and improvement percentage
- Beautiful gradient background with shadow effects

### 📑 **Four Tabs of Information**

#### 1. **Summary Tab**
- **Radar Chart**: Visual representation of all test scores
- **Test Result Cards**: 
  - Visual Acuity (20/25)
  - Eye Tracking (Normal)
  - Colour Vision (85%)
  - Pupil Reflex (Normal)
  - Fatigue Level (Mild)
- **AI Recommendations**: Personalized health recommendations

#### 2. **Detailed Results Tab**
- Visual Acuity breakdown (Right/Left eye)
- Eye Tracking analysis (Smooth pursuit, Saccadic movement)
- Colour Vision plate-by-plate results
- Pupil Reflex metrics (reaction time, constriction, dilation, symmetry)

#### 3. **History Tab**
- Complete test history with dates
- Individual test scores
- Chronological timeline of all tests

#### 4. **AI Report Tab**
- Comprehensive AI-generated report
- Detailed analysis of all tests
- Personalized recommendations
- Risk assessment
- Follow-up schedule
- **Send to Doctor**: Button to share report with healthcare provider

### 🎯 **Action Buttons**
- **Download PDF**: Generate and save a PDF report
- **Share with Doctor**: Share the report via system share dialog

## Installation

### 1. Dependencies

Add these to your `pubspec.yaml`:

```yaml
dependencies:
  fl_chart: ^0.69.2          # For charts (radar chart)
  pdf: ^3.11.1              # For PDF generation
  path_provider: ^2.1.4     # To get device directories
  share_plus: ^10.1.3       # For sharing functionality
```

### 2. Install Packages

```bash
flutter pub get
```

## Usage

### Basic Navigation

```dart
import 'package:netracare/pages/results_report_page.dart';

// Navigate to results page
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => const ResultsReportPage(),
  ),
);
```

### Integration Examples

#### From a Button
```dart
ElevatedButton(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ResultsReportPage()),
    );
  },
  child: const Text('View Results'),
)
```

#### From a Drawer Menu
```dart
ListTile(
  leading: const Icon(Icons.assessment),
  title: const Text('Results Report'),
  onTap: () {
    Navigator.pop(context); // Close drawer
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ResultsReportPage()),
    );
  },
)
```

#### After Test Completion
```dart
// In your test completion logic
void onTestComplete() {
  // Save test results to database/API
  
  // Navigate to results
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(builder: (context) => const ResultsReportPage()),
  );
}
```

## Customization

### Updating Test Data

Replace the mock data with real data from your API/database:

```dart
class ResultsReportPage extends StatefulWidget {
  final Map<String, dynamic>? testResults;
  
  const ResultsReportPage({super.key, this.testResults});
  
  @override
  State<ResultsReportPage> createState() => _ResultsReportPageState();
}

class _ResultsReportPageState extends State<ResultsReportPage> {
  late Map<String, dynamic> results;
  
  @override
  void initState() {
    super.initState();
    results = widget.testResults ?? _getDefaultMockData();
  }
  
  // Use results throughout the page
}
```

### Color Scheme

Current gradient colors can be customized:

```dart
// Main gradient (Overall Health Score card)
LinearGradient(
  colors: [Color(0xFF3B82F6), Color(0xFF9333EA)], // Blue to Purple
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
)

// Individual test card colors
Color(0xFF3B82F6)  // Visual Acuity - Blue
Color(0xFF10B981)  // Eye Tracking - Green
Color(0xFF9333EA)  // Colour Vision - Purple
Color(0xFFF97316)  // Fatigue - Orange
Color(0xFF6366F1)  // Pupil Reflex - Indigo
```

### PDF Generation

Customize the PDF content in `_downloadPDF()`:

```dart
Future<void> _downloadPDF() async {
  final pdf = pw.Document();
  
  // Add your custom content
  pdf.addPage(
    pw.Page(
      build: (pw.Context context) {
        return pw.Column(
          children: [
            // Your custom PDF layout
          ],
        );
      },
    ),
  );
  
  // Save and share
}
```

## API Integration

### Fetch Results from Backend

```dart
import 'package:http/http.dart' as http;
import 'dart:convert';

Future<Map<String, dynamic>> fetchTestResults(String userId) async {
  final response = await http.get(
    Uri.parse('https://your-api.com/api/results/$userId'),
    headers: {'Authorization': 'Bearer YOUR_TOKEN'},
  );
  
  if (response.statusCode == 200) {
    return json.decode(response.body);
  } else {
    throw Exception('Failed to load results');
  }
}

// Usage in ResultsReportPage
@override
void initState() {
  super.initState();
  _loadResults();
}

Future<void> _loadResults() async {
  try {
    final data = await fetchTestResults(currentUserId);
    setState(() {
      results = data;
    });
  } catch (e) {
    // Handle error
  }
}
```

### Send Report to Doctor

```dart
Future<void> _handleSendToDoctor() async {
  setState(() => _sendingReport = true);
  
  try {
    final response = await http.post(
      Uri.parse('https://your-api.com/api/send-report'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer YOUR_TOKEN',
      },
      body: json.encode({
        'userId': currentUserId,
        'doctorId': selectedDoctorId,
        'reportData': results,
      }),
    );
    
    if (response.statusCode == 200) {
      // Success
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Report successfully sent to your doctor!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  } catch (e) {
    // Handle error
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error: $e'),
        backgroundColor: Colors.red,
      ),
    );
  } finally {
    setState(() => _sendingReport = false);
  }
}
```

## Chart Customization

### Radar Chart

The radar chart uses `fl_chart` package. Customize it:

```dart
RadarChart(
  RadarChartData(
    radarBackgroundColor: Colors.transparent,
    // Customize titles
    getTitle: (index, angle) {
      final titles = ['Visual\nAcuity', 'Eye\nTracking', ...];
      return RadarChartTitle(
        text: titles[index],
        angle: angle,
      );
    },
    // Customize data
    dataSets: [
      RadarDataSet(
        fillColor: Color(0xFF3B82F6).withOpacity(0.3),
        borderColor: Color(0xFF3B82F6),
        borderWidth: 2,
        dataEntries: [
          RadarEntry(value: visualAcuityScore),
          RadarEntry(value: eyeTrackingScore),
          // ... more entries
        ],
      ),
    ],
    tickCount: 5,  // Number of grid lines
  ),
)
```

## File Structure

```
lib/
  pages/
    results_report_page.dart       # Main results report page
    results_demo.dart               # Demo/example usage
```

## Mock Data

The page currently uses mock data. Replace with actual data:

```dart
// Current mock data structure
final List<Map<String, dynamic>> _mockData = [
  {'date': 'Jan', 'score': 78.0},
  {'date': 'Feb', 'score': 82.0},
  // ...
];

// Replace with your data model
class TestResult {
  final String date;
  final double score;
  final Map<String, dynamic> details;
  
  TestResult({
    required this.date,
    required this.score,
    required this.details,
  });
  
  factory TestResult.fromJson(Map<String, dynamic> json) {
    return TestResult(
      date: json['date'],
      score: json['score'],
      details: json['details'],
    );
  }
}
```

## Troubleshooting

### Issue: Charts not displaying
**Solution**: Make sure `fl_chart` is properly installed:
```bash
flutter pub get
flutter clean
flutter pub get
```

### Issue: PDF not saving
**Solution**: Add permissions for Android/iOS:

**Android** (`android/app/src/main/AndroidManifest.xml`):
```xml
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"/>
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
```

**iOS** (`ios/Runner/Info.plist`):
```xml
<key>NSPhotoLibraryAddUsageDescription</key>
<string>We need access to save your health reports</string>
```

### Issue: Share not working
**Solution**: Ensure `share_plus` is configured for your platform. Check the [share_plus documentation](https://pub.dev/packages/share_plus).

## Performance Tips

1. **Lazy Loading**: Load heavy data (like AI report) only when the tab is active
2. **Caching**: Cache results to avoid repeated API calls
3. **Image Optimization**: If adding images to PDF, compress them first
4. **Chart Performance**: Limit data points in charts to avoid lag

## Future Enhancements

- [ ] Add animations for tab transitions
- [ ] Implement print functionality
- [ ] Add comparison with previous results
- [ ] Include photo attachments
- [ ] Export as CSV/Excel
- [ ] Email report directly
- [ ] Multi-language support
- [ ] Dark mode support
- [ ] Accessibility improvements (screen reader support)

## License

This component is part of the NetraCare application.

## Support

For issues or questions, please contact the development team or create an issue in the repository.
