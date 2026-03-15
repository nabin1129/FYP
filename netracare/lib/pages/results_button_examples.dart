import 'package:flutter/material.dart';

/// EXAMPLE: How to add "View Results" button to your Dashboard
///
/// Add this code to your dashboard page where you want the results button to appear

class DashboardResultsButtonExample extends StatelessWidget {
  const DashboardResultsButtonExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Your existing dashboard content here...
        const SizedBox(height: 20),

        // Add this Results Report button
        _buildResultsReportButton(context),

        // Rest of your dashboard content...
      ],
    );
  }

  /// Results Report Button Widget
  Widget _buildResultsReportButton(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3B82F6), Color(0xFF9333EA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.assessment,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Health Report',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'View detailed insights & AI analysis',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                // Navigate to results report page
                Navigator.pushNamed(context, '/results-report');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF3B82F6),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bar_chart, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'View Full Report',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ALTERNATIVE: Simple Card Style Button
class SimpleResultsButton extends StatelessWidget {
  const SimpleResultsButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, '/results-report'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.assessment,
                  color: Color(0xFF3B82F6),
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Results Report',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'View your health insights',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

/// ALTERNATIVE: Compact Icon Button
class CompactResultsIconButton extends StatelessWidget {
  const CompactResultsIconButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () => Navigator.pushNamed(context, '/results-report'),
      icon: const Icon(Icons.assessment),
      tooltip: 'View Results Report',
      iconSize: 28,
      color: const Color(0xFF3B82F6),
    );
  }
}

/// ALTERNATIVE: Floating Action Button
class ResultsFAB extends StatelessWidget {
  const ResultsFAB({super.key});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () => Navigator.pushNamed(context, '/results-report'),
      icon: const Icon(Icons.assessment),
      label: const Text('View Report'),
      backgroundColor: const Color(0xFF3B82F6),
    );
  }
}

/// ALTERNATIVE: List Tile (for Drawer/Menu)
class ResultsListTile extends StatelessWidget {
  const ResultsListTile({super.key});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.assessment, color: Color(0xFF3B82F6)),
      title: const Text(
        'Results Report',
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: const Text('View your health insights'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        Navigator.pop(context); // Close drawer if open
        Navigator.pushNamed(context, '/results-report');
      },
    );
  }
}

/// USAGE IN YOUR DASHBOARD:
/// 
/// In homePage() widget in dashboard_page.dart, add:
/// 
/// Column(
///   children: [
///     _upcomingCheckup(),
///     const SizedBox(height: 20),
///     
///     // Add this:
///     DashboardResultsButtonExample(),
///     // OR: SimpleResultsButton(),
///     // OR: CompactResultsIconButton(),
///     
///     const SizedBox(height: 20),
///     _eyeHealthStatus(),
///     // ... rest of your dashboard
///   ],
/// )
