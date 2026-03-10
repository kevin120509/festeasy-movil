import 'dart:io';

void main() {
  final file = File('lib/app/view/client_home_page.dart');
  var content = file.readAsStringSync();
  
  // 1) Remove Empty State in favorites
  final emptyStateStart = content.indexOf('if (_nearbyProviders.isEmpty) {');
  final emptyStateEnd = content.indexOf('return Column(', emptyStateStart);
  
  if (emptyStateStart != -1 && emptyStateEnd != -1) {
    content = content.substring(0, emptyStateStart) +
              'if (_nearbyProviders.isEmpty) { return const SizedBox.shrink(); }\n\n    ' +
              content.substring(emptyStateEnd);
  }

  // 2) Completely remove _buildSearchBar block and call
  final callStart = content.indexOf('_buildSearchBar(),');
  if (callStart != -1) {
     final previousSizedBox = content.lastIndexOf('const SizedBox(height: 16),', callStart);
     if (previousSizedBox != -1 && previousSizedBox > callStart - 50) {
        content = content.replaceRange(previousSizedBox, callStart + 18, '');
     } else {
        content = content.replaceRange(callStart, callStart + 18, '');
     }
  }

  final defStart = content.indexOf('Widget _buildSearchBar() {');
  if (defStart != -1) {
     var cur = defStart;
     var brackets = 0;
     var foundOpen = false;
     for (; cur < content.length; cur++) {
        if (content[cur] == '{') {
           brackets++;
           foundOpen = true;
        } else if (content[cur] == '}') {
           brackets--;
        }
        if (foundOpen && brackets == 0) {
           break;
        }
     }
     if (cur < content.length) {
        content = content.replaceRange(defStart, cur + 1, '');
     }
  }

  file.writeAsStringSync(content);
  print('Done!');
}
