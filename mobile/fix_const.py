import os
import re

def process_file(filepath):
    with open(filepath, 'r') as f:
        content = f.read()

    original = content

    # Fix onSurfaceXX
    def replace_onSurface(match):
        alpha = match.group(1)
        if len(alpha) == 2:
            return f"onSurface.withValues(alpha: 0.{alpha})"
        return match.group(0)

    content = re.sub(r'onSurface(\d+)', replace_onSurface, content)

    # Remove const before Theme.of(context) (some might have multi-line issues)
    # We can just remove const before common widgets that now have Theme inside them
    # Better: just remove ALL 'const ' that are on the same line as Theme.of(context)
    lines = content.split('\n')
    for i in range(len(lines)):
        if 'Theme.of(context)' in lines[i]:
            lines[i] = re.sub(r'\bconst\s+', '', lines[i])
            
        # check if it's the start of a widget that has Theme.of(context) below it
        # Actually it's easier to just use regex on the whole file
        
    content = '\n'.join(lines)
    
    # A bit dangerous but let's remove const from Padding, Container, Text, Icon, BoxDecoration, Divider, CircularProgressIndicator if they contain Theme.of(context) anywhere inside their parentheses
    # But doing this accurately in python is hard. Let's do a simple regex for const <Widget>(...Theme.of(context)...)
    content = re.sub(r'\bconst\s+([A-Z][a-zA-Z0-9_]*\s*\([^)]*Theme\.of\(context\))', r'\1', content, flags=re.DOTALL)
    
    # Also remove const from arrays if they contain Theme.of(context)
    content = re.sub(r'\bconst\s+(\[[^\]]*Theme\.of\(context\))', r'\1', content, flags=re.DOTALL)

    # Fix specific URI error in add_payment_method_modal
    if 'add_payment_method_modal.dart' in filepath:
        content = content.replace('../../../../../core', '../../../../core')

    if content != original:
        with open(filepath, 'w') as f:
            f.write(content)

def main():
    lib_dir = '/Users/mac/Desktop/SIKA/mobile/lib'
    for root, dirs, files in os.walk(lib_dir):
        for file in files:
            if file.endswith('.dart'):
                filepath = os.path.join(root, file)
                process_file(filepath)
                
if __name__ == '__main__':
    main()
