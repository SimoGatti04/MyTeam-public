#!/usr/bin/env python3
"""
Script per correggere shellScript nel file project.pbxproj
Converte shellScript da array a stringhe per compatibilità con CocoaPods 1.16.2 e Xcode 26.1.1
"""
import re
import sys

def fix_shell_scripts(file_path):
    """Corregge tutti gli shellScript nel file project.pbxproj"""
    with open(file_path, 'r') as f:
        content = f.read()
    
    # Pattern per trovare shellScript = ( ... );
    # Cerchiamo blocchi che iniziano con shellScript = ( e finiscono con );
    pattern = r'(shellScript\s*=\s*)\(((?:\s*"[^"]*",?\s*)+)\);'
    
    def replace_script(match):
        prefix = match.group(1)
        script_lines = match.group(2)
        
        # Estrai tutte le righe tra virgolette
        lines = re.findall(r'"([^"]*)"', script_lines)
        # Rimuovi righe vuote
        lines = [l for l in lines if l.strip()]
        
        # Unisci con \n
        script = '\\n'.join(lines)
        # Escape le virgolette e backslash nella stringa risultante
        script = script.replace('\\', '\\\\').replace('"', '\\"')
        
        return f'{prefix}"{script}";'
    
    # Sostituisci tutti gli shellScript
    new_content = re.sub(pattern, replace_script, content, flags=re.MULTILINE)
    
    # Verifica se ci sono ancora shellScript come array
    if re.search(r'shellScript\s*=\s*\(', new_content):
        print("⚠️  Alcuni shellScript potrebbero non essere stati convertiti")
        return False
    
    with open(file_path, 'w') as f:
        f.write(new_content)
    
    print("✅ File project.pbxproj corretto con successo")
    return True

if __name__ == '__main__':
    file_path = 'macos/Runner.xcodeproj/project.pbxproj'
    if len(sys.argv) > 1:
        file_path = sys.argv[1]
    
    try:
        if fix_shell_scripts(file_path):
            sys.exit(0)
        else:
            sys.exit(1)
    except Exception as e:
        print(f"❌ Errore: {e}")
        sys.exit(1)

