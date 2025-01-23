import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:mobile_nebula/services/utils.dart';
import '../../oss_licenses.dart';

String capitalize(String input) {
  return input[0].toUpperCase() + input.substring(1);
}

class LicensesScreen extends StatelessWidget {
  const LicensesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: Text("Licences"),
      ),
      body: ListView.builder(
        itemCount: allDependencies.length,
        itemBuilder: (_, index) {
          var dep = allDependencies[index];
          return Padding(
            padding: const EdgeInsets.all(8),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
              ),
              child: PlatformListTile(
                  onTap: () {
                    Utils.openPage(
                      context,
                      (_) => LicenceDetailPage(
                        title: capitalize(dep.name),
                        licence: dep.license!,
                      ),
                    );
                  },
                  title: Text(
                    capitalize(dep.name),
                  ),
                  subtitle: Text(dep.description),
                  trailing: Icon(context.platformIcons.forward, size: 18)),
            ),
          );
        },
      ),
    );
  }
}

//detail page for the licence
class LicenceDetailPage extends StatelessWidget {
  final String title, licence;
  const LicenceDetailPage({super.key, required this.title, required this.licence});

  @override
  Widget build(BuildContext context) {
    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: Text(title),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  Text(
                    licence,
                    style: const TextStyle(fontSize: 15),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
