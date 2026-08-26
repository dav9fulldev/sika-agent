import os

def fix_file(filepath):
    with open(filepath, 'r') as f:
        content = f.read()
        
    if 'human_confirmation_card.dart' in filepath:
        content = content.replace('Widget _buildDetailRow(String label, String value)', 'Widget _buildDetailRow(BuildContext context, String label, String value)')
        content = content.replace('_buildDetailRow(', '_buildDetailRow(context, ')
        
    if 'proactive_analysis_sheet.dart' in filepath:
        content = content.replace('Widget _buildDetailRow(String label, String value,', 'Widget _buildDetailRow(BuildContext context, String label, String value,')
        content = content.replace('_buildDetailRow(', '_buildDetailRow(context, ')
        
    if 'payment_methods_screen.dart' in filepath:
        content = content.replace('Widget _buildTypeSelector({required int index, required IconData icon, required String title})', 'Widget _buildTypeSelector({required BuildContext context, required int index, required IconData icon, required String title})')
        content = content.replace('_buildTypeSelector(', '_buildTypeSelector(context: context, ')
        
    if 'profile_screen.dart' in filepath:
        content = content.replace('Widget _buildMenuSection(String title, List<Widget> items)', 'Widget _buildMenuSection(BuildContext context, String title, List<Widget> items)')
        content = content.replace('_buildMenuSection(', '_buildMenuSection(context, ')
        
        content = content.replace('Widget _buildMenuTile({', 'Widget _buildMenuTile({required BuildContext context, ')
        content = content.replace('_buildMenuTile(', '_buildMenuTile(context: context, ')

    with open(filepath, 'w') as f:
        f.write(content)

def main():
    files_to_fix = [
        '/Users/mac/Desktop/SIKA/mobile/lib/features/ai_assistant/presentation/widgets/human_confirmation_card.dart',
        '/Users/mac/Desktop/SIKA/mobile/lib/features/ai_assistant/presentation/widgets/proactive_analysis_sheet.dart',
        '/Users/mac/Desktop/SIKA/mobile/lib/features/profile/presentation/pages/payment_methods_screen.dart',
        '/Users/mac/Desktop/SIKA/mobile/lib/features/profile/presentation/pages/profile_screen.dart'
    ]
    for f in files_to_fix:
        fix_file(f)

if __name__ == '__main__':
    main()
