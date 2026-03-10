import 'dart:io';

void main() {
  final file = File('lib/app/view/client_home_page.dart');
  var content = file.readAsStringSync();
  
  final regex = RegExp(
    r'([ \t]*)const SizedBox\(height: 4\),\s*const Row\(\s*children: \[\s*Icon\(Icons\.location_on, color: Color\(0xFFE01D25\), size: 16\),\s*SizedBox\(width: 4\),\s*Flexible\(\s*child: Text\(\s*.*?Entregando en:.*?\s*style: TextStyle\(fontSize: 13, color: Colors\.grey\),\s*overflow: TextOverflow\.ellipsis,\s*\),\s*\),\s*\],\s*\),',
    dotAll: true,
  );
  
  if (regex.hasMatch(content)) {
    content = content.replaceAll(regex, '');
    file.writeAsStringSync(content);
    print('Texto de entregando en eliminado!');
  } else {
    print('No se encontró el bloque');
  }
}
