import os
import re

def process_file(filepath):
    with open(filepath, 'r') as f:
        content = f.read()

    # Replacements
    # 1. Colors.white -> Theme.of(context).colorScheme.onSurface
    content = re.sub(r'Colors\.white', r'Theme.of(context).colorScheme.onSurface', content)
    # 2. AppColors.surfaceDarker -> Theme.of(context).scaffoldBackgroundColor
    content = re.sub(r'AppColors\.surfaceDarker', r'Theme.of(context).scaffoldBackgroundColor', content)
    # 3. AppColors.surface -> Theme.of(context).cardColor
    content = re.sub(r'AppColors\.surface', r'Theme.of(context).cardColor', content)
    # 4. AppColors.textPrimary -> Theme.of(context).colorScheme.onSurface
    content = re.sub(r'AppColors\.textPrimary', r'Theme.of(context).colorScheme.onSurface', content)
    # 5. const Color(0xFF0B1329) -> Theme.of(context).cardColor
    content = re.sub(r'(?:const\s+)?Color\(0xFF0B1329\)', r'Theme.of(context).cardColor', content)
    # 6. const Color(0xFF1E293B) -> Theme.of(context).cardColor
    content = re.sub(r'(?:const\s+)?Color\(0xFF1E293B\)', r'Theme.of(context).cardColor', content)

    # Now, the tricky part: remove 'const ' from lines that now have Theme.of(context)
    # This is a heuristic, but often works for simple cases.
    lines = content.split('\n')
    for i in range(len(lines)):
        if 'Theme.of(context)' in lines[i]:
            # If the line starts with const, remove it
            lines[i] = re.sub(r'\bconst\s+', '', lines[i])
            # We should also look back a few lines if 'const' was on a previous line for a widget
            # But regex can't easily parse Dart syntax trees.
            # Instead, we will rely on dart fix later.
            
    content = '\n'.join(lines)
    
    with open(filepath, 'w') as f:
        f.write(content)

def main():
    lib_dir = '/Users/mac/Desktop/SIKA/mobile/lib'
    for root, dirs, files in os.walk(lib_dir):
        for file in files:
            if file.endswith('.dart') and file != 'app_colors.dart' and file != 'app_theme.dart' and file != 'theme_provider.dart':
                filepath = os.path.join(root, file)
                process_file(filepath)
                
if __name__ == '__main__':
    main()
