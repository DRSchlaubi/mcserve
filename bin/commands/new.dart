import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:interact/interact.dart';

import '../distributions/distribution.dart';
import '../jdk/finder/jre_finder.dart';
import '../script/script_generator.dart';
import '../utils/aikar_flags.dart' as aikar;
import '../utils/confirm.dart';
import 'command.dart';

const String _mcEula = 'https://account.mojang.com/documents/minecraft_eula';

class NewCommand extends Command {
  final _fs = LocalFileSystem();

  @override
  String get prompt => 'Create a new server';

  @override
  String get name => 'new';

  @override
  Future<void> execute() async {
    var finder = JreFinder.forPlatform();
    var directory = await _askDirectory();
    var distribution = _askDistribution();
    var acceptEula = distribution.requiresEula
        ? confirm('Do you accept the MC Eula? ($_mcEula)', defaultValue: true)
        : false;

    var aikarFlags =
        confirm("Do you want to use Aikar's JVM flags?", defaultValue: true);

    var version = await _askVersion(distribution);

    var jres = await finder.findInstalledJres();

    var options = jres.map((element) {
      return 'Java ${element.version.languageVersion} (${element.version.update}) in ${element.path}';
    }).toList();

    var jreIndex = Select(
            prompt: 'Which java version do you want to use?', options: options)
        .interact();

    var jre = jres[jreIndex];

    print('Downloading Distribution');
    await distribution.downloadTo(version, directory.childFile('server.jar'));
    var scriptGen = ScriptGenerator.forPlatform();

    await scriptGen.writeStartScript(directory, 'server.jar', jre.path,
        [if (aikarFlags) ...aikar.aikarFlags]);

    if (acceptEula) {
      var eula = directory.childFile('eula.txt');
      await eula.writeAsString('eula=true');
    }
  }

  Future<Directory> _askDirectory() async {
    var ask = Input(prompt: 'Destination directory');

    var path = ask.interact();
    var directory = _fs.directory(path);
    if (!await directory.exists()) {
      if (!confirm(
          'Specified directory does not exist, do you want to create it?')) {
        return _askDirectory();
      }

      await directory.create();
    }

    if (!(await directory.list().isEmpty)) {
      if (!confirm(
          'The specified directory is not empty, do you want to proceed?')) {
        return _askDirectory();
      }
    }

    return directory;
  }

  Distribution _askDistribution() {
    var ask = Select(
        prompt: 'Chose Server Distribution',
        options: Distribution.all.map((e) => e.displayName).toList());

    var distributionIndex = ask.interact();
    return Distribution.all[distributionIndex];
  }

  Future<String> _askVersion(Distribution distribution) async {
    var versions = await distribution.retrieveVersions();
    var ask = Select(prompt: 'Chose Server Version', options: versions);
    var versionIndex = ask.interact();
    return versions[versionIndex];
  }
}
